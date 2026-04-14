import Foundation
import Supabase
import Functions

/// Generates a full periodized TrainingPlan by calling the chat Edge Function
/// in multiple focused stages:
///
///   1. **Skeleton call** — phases + a one-line focus per week.
///   2. **Week batch calls** — daily session details for 2 weeks at a time.
///
/// This keeps every HTTP call under iOS's default 60s URLSession timeout and
/// Deno Deploy's per-request wall-clock limit, both of which were being blown
/// by the previous single 16k-token generation for complex (triathlon) plans.
/// Each stage reports progress through DataService.activeToolProgress so the
/// chat UI can show what's happening instead of just "Thinking…".
@MainActor
enum TrainingPlanGenerator {
    /// Number of weeks generated per week-batch call. 2 keeps each call's
    /// response well under 5k tokens (~45s of Anthropic generation time) even
    /// for detail-heavy triathlon weeks.
    private static let weeksPerBatch = 2

    static func generate(
        for event: Event,
        athleteMemory: CoachingMemory,
        totalWeeks: Int,
        trainingDaysPerWeek: Int?,
        weeklyVolumeHours: Double?,
        longRunDay: String?,
        strengthDays: [String]?,
        notes: String?,
        dataService: DataService? = nil
    ) async throws -> TrainingPlan {
        let profile = buildAthleteContext(memory: athleteMemory)
        let constraintsBlock = buildConstraintsBlock(
            trainingDaysPerWeek: trainingDaysPerWeek,
            weeklyVolumeHours: weeklyVolumeHours,
            longRunDay: longRunDay,
            strengthDays: strengthDays,
            notes: notes
        )
        let startDate = computeStartDate(for: event, totalWeeks: totalWeeks)

        // MARK: Stage 1 — skeleton
        updateProgress(dataService, "Building plan structure…")
        let skeleton = try await generateSkeleton(
            event: event,
            profile: profile,
            constraintsBlock: constraintsBlock,
            startDate: startDate,
            totalWeeks: totalWeeks,
            trainingDaysPerWeek: trainingDaysPerWeek
        )

        // MARK: Stage 2 — week batches
        var weeklyPlans: [String: WeeklyPlan] = [:]
        var cursor = 1
        while cursor <= totalWeeks {
            let batchEnd = min(cursor + weeksPerBatch - 1, totalWeeks)
            let label: String
            if cursor == batchEnd {
                label = "Generating week \(cursor) of \(totalWeeks)…"
            } else {
                label = "Generating weeks \(cursor)–\(batchEnd) of \(totalWeeks)…"
            }
            updateProgress(dataService, label)

            let batch = try await generateWeekBatch(
                weekNums: Array(cursor...batchEnd),
                event: event,
                profile: profile,
                constraintsBlock: constraintsBlock,
                skeleton: skeleton,
                totalWeeks: totalWeeks
            )
            for wp in batch {
                weeklyPlans[String(wp.weekNumber)] = wp
            }
            cursor = batchEnd + 1
        }

        updateProgress(dataService, "Finalizing your plan…")

        let plan = TrainingPlan(
            id: UUID().uuidString,
            goalId: event.id,
            raceName: event.name,
            raceDate: event.date,
            startDate: startDate,
            totalWeeks: totalWeeks,
            currentWeek: 1,
            currentPhase: 1,
            trainingDaysPerWeek: trainingDaysPerWeek,
            phases: skeleton.phases,
            weeklyPlans: weeklyPlans
        )

        // Clear the progress string so the next chat turn doesn't inherit it.
        dataService?.activeToolProgress = nil
        return plan
    }

    // MARK: - Stage 1: Skeleton

    private struct PlanSkeleton {
        let phases: [TrainingPhase]
        /// weekNumber → focusOfWeek
        let weekFocuses: [Int: String]
        /// weekNumber → phase number
        let weekPhases: [Int: Int]
    }

    private struct SkeletonResponse: Codable {
        let phases: [TrainingPhase]
        let weekFocuses: [WeekFocus]
        struct WeekFocus: Codable {
            let weekNumber: Int
            let phase: Int
            let focus: String
        }
    }

    private static func generateSkeleton(
        event: Event,
        profile: String,
        constraintsBlock: String,
        startDate: String,
        totalWeeks: Int,
        trainingDaysPerWeek: Int?
    ) async throws -> PlanSkeleton {
        let prompt = """
        You are designing the structural outline of a \(totalWeeks)-week training plan. Do NOT generate daily sessions yet — those come in later calls.

        RACE: "\(event.name)"
        RACE DATE: \(event.date ?? "TBD")
        LOCATION: \(event.location ?? "TBD")
        GOAL TIME: \(event.goal ?? "finish strong")
        TOTAL WEEKS: \(totalWeeks)
        START DATE: \(startDate)
        TRAINING DAYS PER WEEK: \(trainingDaysPerWeek ?? 6)

        \(profile)

        \(constraintsBlock)

        Return ONLY a JSON object matching this exact shape. No markdown fences, no prose.

        {
          "phases": [
            {
              "number": 1,
              "name": "Base",
              "startDate": "YYYY-MM-DD",
              "endDate": "YYYY-MM-DD",
              "weeks": 6,
              "deloadWeek": 4,
              "philosophy": "1-2 sentences on what this phase accomplishes",
              "weekly_volume_range": {"min": 6.0, "max": 8.0, "unit": "hours"},
              "sessions_per_week": 6,
              "intensity_distribution": {"easy": 80, "tempo": 15, "threshold": 5, "vo2_max": 0},
              "key_workouts": [
                {"name": "Long Run", "description": "Progressive Z2 long run"},
                {"name": "Tempo", "description": "3x10min @ tempo"}
              ],
              "strength_focus": "Max strength — heavy 3-5 rep work",
              "physiological_goals": ["Increase mitochondrial density", "Improve fat oxidation"],
              "progression_rules": "+10% volume per week for 3 weeks, 30% deload on week 4",
              "race_specific_notes": "Race-specific notes tied to the event"
            }
          ],
          "weekFocuses": [
            {"weekNumber": 1, "phase": 1, "focus": "Aerobic base building — first week of progression"},
            {"weekNumber": 2, "phase": 1, "focus": "..."}
          ]
        }

        RULES:
        1. Generate 2-4 phases that make sense for this race distance and timeline (e.g. Base / Build / Taper, or Base / Build / Peak / Taper).
        2. Each phase MUST include every field shown — philosophy, weekly_volume_range, sessions_per_week, intensity_distribution, key_workouts, strength_focus, physiological_goals, progression_rules, race_specific_notes.
        3. Intensity distributions: base ~80/15/5/0, build ~75/10/12/3, peak ~70/10/15/5, taper ~80/10/8/2.
        4. weekFocuses MUST cover every week from 1 to \(totalWeeks). No gaps.
        5. Each weekFocus's "phase" must match which phase that week belongs to.
        6. Each weekFocus's "focus" is ONE sentence naming the adaptation and position in the phase (e.g. "Build threshold — second week of progression, key session is Thursday's 3x10min @ LT").
        7. Deload weeks should call out the reduced volume explicitly in the focus string.
        """

        let body: [String: Any] = [
            "system": "You are an expert endurance coach. You return only valid JSON matching the exact shape requested, with no prose, no markdown fences, and no commentary.",
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 4000,
            "model": "claude-sonnet-4-6",
        ]

        let text = try await callChatWithRetry(body: body, logTag: "plan-skeleton")
        guard let json = extractJSON(from: text) else {
            throw NSError(
                domain: "TrainingPlanGenerator", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Couldn't find skeleton JSON. Preview: \(text.prefix(200))"]
            )
        }
        guard let data = json.data(using: .utf8) else {
            throw NSError(domain: "TrainingPlanGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "JSON encode failed"])
        }

        let decoded: SkeletonResponse
        do {
            decoded = try JSONDecoder().decode(SkeletonResponse.self, from: data)
        } catch {
            NSLog("[plan-skeleton] decode error: \(error)\njson preview: \(json.prefix(500))")
            throw error
        }

        var focuses: [Int: String] = [:]
        var weekPhases: [Int: Int] = [:]
        for wf in decoded.weekFocuses {
            focuses[wf.weekNumber] = wf.focus
            weekPhases[wf.weekNumber] = wf.phase
        }
        return PlanSkeleton(phases: decoded.phases, weekFocuses: focuses, weekPhases: weekPhases)
    }

    // MARK: - Stage 2: Week batch

    private struct WeekBatchResponse: Codable {
        let weeks: [WeeklyPlan]
    }

    private static func generateWeekBatch(
        weekNums: [Int],
        event: Event,
        profile: String,
        constraintsBlock: String,
        skeleton: PlanSkeleton,
        totalWeeks: Int
    ) async throws -> [WeeklyPlan] {
        // Compact context about just the phases these weeks touch, so the
        // model has the intensity/volume/focus cues without seeing every phase.
        let relevantPhaseNums = Set(weekNums.compactMap { skeleton.weekPhases[$0] })
        let phaseContext = skeleton.phases
            .filter { relevantPhaseNums.contains($0.number) }
            .map { phase -> String in
                let dist = phase.intensityDistribution
                let distLine = dist.map {
                    "easy \($0.easy)% / tempo \($0.tempo)% / threshold \($0.threshold)% / VO2max \($0.vo2max)%"
                } ?? "—"
                let keyNames = (phase.keyWorkouts ?? []).map(\.name).joined(separator: ", ")
                return """
                Phase \(phase.number) — \(phase.name):
                - Philosophy: \(phase.philosophy ?? "")
                - Intensity mix: \(distLine)
                - Key workouts: \(keyNames)
                - Strength focus: \(phase.strengthFocus ?? "")
                - Progression: \(phase.progressionRules ?? "")
                """
            }
            .joined(separator: "\n\n")

        let weekBriefs = weekNums.map { wn -> String in
            let phase = skeleton.weekPhases[wn] ?? 1
            let focus = skeleton.weekFocuses[wn] ?? ""
            return "- Week \(wn) (phase \(phase)): \(focus)"
        }.joined(separator: "\n")

        let firstWeek = weekNums.first ?? 1
        let prompt = """
        Generate the daily sessions for these weeks of a \(totalWeeks)-week plan.

        RACE: "\(event.name)" on \(event.date ?? "TBD"), goal: \(event.goal ?? "finish strong")

        \(profile)

        \(constraintsBlock)

        PHASE CONTEXT:
        \(phaseContext)

        WEEKS TO GENERATE:
        \(weekBriefs)

        Return ONLY a JSON object matching this exact shape. No markdown fences, no prose.

        {
          "weeks": [
            {
              "weekNumber": \(firstWeek),
              "phase": 1,
              "focusOfWeek": "use the focus from the brief above",
              "sessions": [
                {
                  "day": "monday",
                  "isRest": false,
                  "sessions": [
                    {
                      "type": "run",
                      "label": "5.0mi Easy Run",
                      "duration": 45,
                      "estimated_duration_min": 42,
                      "estimated_duration_max": 48,
                      "distance_miles": 5.0,
                      "effort_category": "easy",
                      "zone": "Z2",
                      "pace_range": "10:30-11:00/mi",
                      "priority": "yellow",
                      "purpose": "one sentence on the adaptation this session builds",
                      "workout": "1-3 sentences of concrete instructions",
                      "notes": "2-4 sentence personalized coach note",
                      "fuel": {
                        "pre": "macro targets + timing + 2-3 food options",
                        "during": "water only or specific carb/electrolyte plan for >60min",
                        "post": "protein + carb targets + 2-3 food options"
                      }
                    }
                  ]
                },
                {
                  "day": "tuesday",
                  "isRest": true,
                  "sessions": [],
                  "rest_note": "1-2 sentence personalized recovery advice"
                }
              ]
            }
          ]
        }

        RULES:
        1. Generate ALL \(weekNums.count) week(s) listed, each with all 7 days in order: monday, tuesday, wednesday, thursday, friday, saturday, sunday.
        2. Rest days use "isRest": true, empty sessions array, and REQUIRED "rest_note" (1-2 personalized sentences).
        3. effort_category must be one of: easy, recovery, tempo, threshold, long_endurance, vo2max, strength, race, rest.
        4. session.type must be one of: run, bike, swim, strength, brick, hike, other.
        5. distance_miles and duration are numbers, not strings.
        6. Every non-rest session REQUIRES purpose (one sentence), workout (1-3 sentences), notes (2-4 sentence personalized coach note — never boilerplate), and fuel (pre/during/post).
        7. pace_range: compute from athlete benchmarks + zone when a benchmark exists. OMIT if no benchmark.
        8. priority: "red" for 2-3 key workouts per week that cannot be skipped, "yellow" for flexible sessions.
        9. warning: OMIT unless the athlete has an active injury affecting THIS specific session. When present, name the modification ("Skip X if Y", "Substitute A for B").
        10. Every strength session REQUIRES an "exercises" array. Each exercise: name, exerciseType ("weighted"|"bodyweight"|"banded"|"timed"|"cardio-drill"), sets, reps (or duration for timed), weight/band, rest (seconds), notes (form cue specific to this athlete).
        11. Long runs progress week-over-week within a phase. Deload weeks drop volume ~30%.
        12. Use the phase context above to match intensity distribution and key workout placement. A tempo/threshold session in a build week should align with the phase's key workout list.
        """

        let body: [String: Any] = [
            "system": "You are an expert endurance coach. You return only valid JSON matching the exact shape requested, with no prose, no markdown fences, and no commentary. Every field must be populated for every session.",
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 6000,
            "model": "claude-sonnet-4-6",
        ]

        let logTag = "plan-week-batch-\(weekNums.first ?? 0)-\(weekNums.last ?? 0)"
        let text = try await callChatWithRetry(body: body, logTag: logTag)
        guard let json = extractJSON(from: text) else {
            throw NSError(
                domain: "TrainingPlanGenerator", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Couldn't find week-batch JSON. Preview: \(text.prefix(200))"]
            )
        }
        guard let data = json.data(using: .utf8) else {
            throw NSError(domain: "TrainingPlanGenerator", code: 4, userInfo: [NSLocalizedDescriptionKey: "JSON encode failed"])
        }

        do {
            let decoded = try JSONDecoder().decode(WeekBatchResponse.self, from: data)
            return decoded.weeks
        } catch {
            NSLog("[\(logTag)] decode error: \(error)\njson preview: \(json.prefix(500))")
            throw error
        }
    }

    // MARK: - Edge function call + retry

    /// One retry with a 2s delay before giving up. Transient 429/529s are
    /// already retried inside the edge function; this handles the rarer case
    /// where a response decodes malformed or the network blips on one batch.
    private static func callChatWithRetry(body: [String: Any], logTag: String) async throws -> String {
        do {
            return try await callChat(body: body, logTag: logTag)
        } catch {
            NSLog("[\(logTag)] first attempt failed: \(error.localizedDescription) — retrying once")
            try? await Task.sleep(for: .seconds(2))
            return try await callChat(body: body, logTag: logTag)
        }
    }

    private static func callChat(body: [String: Any], logTag: String) async throws -> String {
        let client = SupabaseService.shared.client
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let response: PlanChatResponse = try await client.functions.invoke(
            "chat",
            options: .init(body: bodyData)
        ) { data, response in
            guard 200..<300 ~= response.statusCode else {
                let preview = String(data: data, encoding: .utf8) ?? ""
                NSLog("[\(logTag)] HTTP \(response.statusCode): \(preview)")
                throw FunctionsError.httpError(code: response.statusCode, data: data)
            }
            return try JSONDecoder().decode(PlanChatResponse.self, from: data)
        }

        return response.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined(separator: "\n")
    }

    // MARK: - Progress

    private static func updateProgress(_ dataService: DataService?, _ message: String) {
        dataService?.activeToolProgress = message
    }

    // MARK: - Context builders

    private static func buildAthleteContext(memory: CoachingMemory) -> String {
        var lines: [String] = ["ATHLETE PROFILE:"]
        let p = memory.permanent
        if !p.equipment.isEmpty { lines.append("- Equipment: \(p.equipment.joined(separator: ", "))") }
        if !p.facilities.isEmpty { lines.append("- Facilities: \(p.facilities.joined(separator: ", "))") }
        if p.schedule.availableDays > 0 {
            lines.append("- Schedule: \(p.schedule.availableDays) days/wk available, prefers \(p.schedule.preferredTimes)")
        }
        if !p.schedule.constraints.isEmpty {
            lines.append("- Constraints: \(p.schedule.constraints.joined(separator: "; "))")
        }
        if !p.medicalHistory.isEmpty {
            lines.append("- Medical history: \(p.medicalHistory.joined(separator: "; "))")
        }
        if !p.dietaryConstraints.isEmpty {
            lines.append("- Dietary: \(p.dietaryConstraints.joined(separator: ", "))")
        }
        let activeInjuries = memory.injuries.filter { $0.status.lowercased() != "resolved" }
        if !activeInjuries.isEmpty {
            let summary = activeInjuries.map { "\($0.area) (\($0.status), \($0.severity))" }.joined(separator: "; ")
            lines.append("- Active injuries: \(summary)")
        }
        if !p.safetyRules.isEmpty {
            let rules = p.safetyRules.map { "\"\($0.rule)\" (\($0.reason))" }.joined(separator: "; ")
            lines.append("- Safety rules: \(rules)")
        }
        if !memory.benchmarks.isEmpty {
            let b = memory.benchmarks.map { "\($0.metric): \($0.value)" }.joined(separator: ", ")
            lines.append("- Recent benchmarks: \(b)")
        }
        if !memory.responseProfile.volumeVsIntensity.isEmpty {
            lines.append("- Response to training: \(memory.responseProfile.volumeVsIntensity); \(memory.responseProfile.recoveryRate)")
        }
        return lines.joined(separator: "\n")
    }

    private static func buildConstraintsBlock(
        trainingDaysPerWeek: Int?,
        weeklyVolumeHours: Double?,
        longRunDay: String?,
        strengthDays: [String]?,
        notes: String?
    ) -> String {
        var lines: [String] = ["PLAN CONSTRAINTS:"]
        if let d = trainingDaysPerWeek { lines.append("- Training days per week: \(d)") }
        if let v = weeklyVolumeHours { lines.append("- Target peak weekly volume: \(v) hours") }
        if let l = longRunDay { lines.append("- Long run day: \(l)") }
        if let s = strengthDays, !s.isEmpty { lines.append("- Strength days: \(s.joined(separator: ", "))") }
        if let n = notes, !n.isEmpty { lines.append("- Athlete notes: \(n)") }
        if lines.count == 1 { lines.append("- None specified — use your judgment.") }
        return lines.joined(separator: "\n")
    }

    /// Picks a start date: event.date - totalWeeks*7 if race date is set, otherwise today.
    private static func computeStartDate(for event: Event, totalWeeks: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let raceDateStr = event.date, let raceDate = formatter.date(from: raceDateStr) {
            let start = Calendar.current.date(byAdding: .day, value: -(totalWeeks - 1) * 7, to: raceDate) ?? Date()
            return formatter.string(from: start)
        }
        return formatter.string(from: Date())
    }

    /// Extract JSON object from model response text, stripping markdown fences.
    private static func extractJSON(from text: String) -> String? {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            if let firstNewline = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: firstNewline)...])
            }
            if let lastFence = s.range(of: "```", options: .backwards) {
                s = String(s[s.startIndex..<lastFence.lowerBound])
            }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let start = s.firstIndex(of: "{"),
              let end = s.lastIndex(of: "}"),
              start <= end else { return nil }
        return String(s[start...end])
    }
}

// MARK: - Minimal local chat response shape

private struct PlanChatResponse: Codable {
    let content: [Block]
    struct Block: Codable {
        let type: String
        let text: String?
    }
}
