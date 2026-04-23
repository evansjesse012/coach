import Foundation
import Supabase
import Functions

/// Builds a periodized TrainingPlan in the way a real coach would:
///
///   1. **Skeleton call** — phases only. Rich detail per phase (philosophy,
///      volume, intensity, key workouts, strength focus, progression rules).
///      No per-week focuses are generated — skeleton output size is fixed
///      regardless of plan length, so a 12-week plan and a 78-week plan
///      both generate structure in roughly the same time.
///   2. **Week 1 generation** — full daily detail for the current week
///      only. The athlete has something to train with today.
///   3. **Stubs** — every other week is stored with just its phase number
///      and an empty sessions array. `TrainingPlanGenerator.generateWeek`
///      fills them in later, leaning on the phase's stored context plus
///      recent adherence history.
///
/// Both model calls use SSE streaming via `callEdgeFunctionStreaming` — the
/// connection stays alive as long as chunks flow, so we don't hit the iOS
/// URLSession 60s cliff or Deno Deploy's wall-clock limit even for long
/// plans. Non-streaming callers (the agent loop, one-shot generators) are
/// unaffected — they still hit the edge function's non-streaming path.
@MainActor
enum TrainingPlanGenerator {
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
        updateProgress(dataService, "Designing your season structure…")
        let skeleton = try await generateSkeleton(
            event: event,
            profile: profile,
            constraintsBlock: constraintsBlock,
            startDate: startDate,
            totalWeeks: totalWeeks,
            trainingDaysPerWeek: trainingDaysPerWeek,
            dataService: dataService
        )

        // MARK: Stage 2 — current week full detail
        updateProgress(dataService, "Writing week 1 in detail…")
        let weekOne = try await generateWeekBatch(
            weekNums: [1],
            event: event,
            profile: profile,
            constraintsBlock: constraintsBlock,
            skeleton: skeleton,
            totalWeeks: totalWeeks,
            recentAdherenceContext: nil,
            dataService: dataService
        )

        // MARK: Stage 3 — stub remaining weeks
        updateProgress(dataService, "Finalizing your plan…")
        var weeklyPlans: [String: WeeklyPlan] = [:]
        for wp in weekOne {
            weeklyPlans[String(wp.weekNumber)] = wp
        }
        for wn in 2...max(2, totalWeeks) where wn <= totalWeeks {
            weeklyPlans[String(wn)] = WeeklyPlan(
                weekNumber: wn,
                phase: phaseForWeek(wn, in: skeleton.phases)?.number,
                focusOfWeek: nil, // filled in by generateWeek when the week is close
                sessions: []
            )
        }

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

        dataService?.activeToolProgress = nil
        return plan
    }

    // MARK: - Lazy: generate one week

    /// Generates full daily detail for a single week of an existing plan,
    /// reconstructing the skeleton from the stored plan's phases and pulling
    /// in recent adherence history so the coach can adapt — progress, back
    /// off, or swap sessions based on what actually happened in the
    /// preceding weeks. The caller splices the returned WeeklyPlan into
    /// `plan.weeklyPlans` and persists.
    static func generateWeek(
        weekNumber: Int,
        in plan: TrainingPlan,
        event: Event,
        athleteMemory: CoachingMemory,
        dataService: DataService? = nil
    ) async throws -> WeeklyPlan {
        guard weekNumber >= 1, weekNumber <= plan.totalWeeks else {
            throw NSError(
                domain: "TrainingPlanGenerator", code: 6,
                userInfo: [NSLocalizedDescriptionKey: "Week \(weekNumber) is outside the plan's \(plan.totalWeeks)-week range."]
            )
        }

        let skeleton = PlanSkeleton(phases: plan.phases)
        let profile = buildAthleteContext(memory: athleteMemory)
        let constraintsBlock = buildConstraintsBlock(
            trainingDaysPerWeek: plan.trainingDaysPerWeek,
            weeklyVolumeHours: nil,
            longRunDay: nil,
            strengthDays: nil,
            notes: nil
        )
        let adherence = buildRecentAdherenceContext(plan: plan, weekNumber: weekNumber)

        updateProgress(dataService, "Shaping week \(weekNumber) of \(plan.totalWeeks)…")
        let weeks = try await generateWeekBatch(
            weekNums: [weekNumber],
            event: event,
            profile: profile,
            constraintsBlock: constraintsBlock,
            skeleton: skeleton,
            totalWeeks: plan.totalWeeks,
            recentAdherenceContext: adherence,
            dataService: dataService
        )

        dataService?.activeToolProgress = nil
        guard let week = weeks.first else {
            throw NSError(
                domain: "TrainingPlanGenerator", code: 7,
                userInfo: [NSLocalizedDescriptionKey: "Model returned no week in the batch response."]
            )
        }
        return week
    }

    /// Summarizes up to the last 3 completed weeks so the prompt can tell
    /// the model how the athlete is actually doing. Empty when there's no
    /// history yet.
    private static func buildRecentAdherenceContext(plan: TrainingPlan, weekNumber: Int) -> String? {
        let lookback = 3
        let startWeek = max(1, weekNumber - lookback)
        guard startWeek < weekNumber else { return nil }

        var lines: [String] = []
        for w in startWeek..<weekNumber {
            guard let wp = plan.weeklyPlans[String(w)], !wp.sessions.isEmpty else { continue }
            let allSessions = wp.sessions.flatMap(\.sessions)
            guard !allSessions.isEmpty else { continue }
            let total = allSessions.count
            let done = allSessions.filter {
                switch $0.displayState {
                case .completed, .modified, .needsReview: return true
                default: return false
                }
            }.count
            let skipped = allSessions.filter { $0.displayState == .skipped }.map(\.label)
            let swapped = allSessions.filter { $0.displayState == .swapped }.map(\.label)
            var line = "- Week \(w): \(done)/\(total) sessions completed"
            if !skipped.isEmpty { line += "; skipped: \(skipped.joined(separator: ", "))" }
            if !swapped.isEmpty { line += "; swapped: \(swapped.joined(separator: ", "))" }
            let notes = allSessions.compactMap(\.completionNote).filter { !$0.isEmpty }
            if !notes.isEmpty {
                line += "; notes: " + notes.prefix(2).joined(separator: " | ")
            }
            lines.append(line)
        }

        guard !lines.isEmpty else { return nil }
        return """
        RECENT HISTORY (use this to adapt this week — progress if the athlete is \
        nailing sessions, pull back if they're missing key workouts or flagging fatigue):
        \(lines.joined(separator: "\n"))
        """
    }

    // MARK: - Skeleton data structures

    /// Minimal skeleton — phases only. Week → phase mapping is derived at
    /// call sites via `phaseForWeek(_:in:)` rather than stored redundantly.
    private struct PlanSkeleton {
        let phases: [TrainingPhase]
    }

    private struct SkeletonResponse: Codable {
        let phases: [TrainingPhase]
    }

    // MARK: - Phase-from-week helpers

    /// The phase that contains a given 1-based week number, assuming phases
    /// are laid out contiguously in `number` order starting at week 1.
    /// Returns nil if the week number is outside the phase range.
    private static func phaseForWeek(_ weekNumber: Int, in phases: [TrainingPhase]) -> TrainingPhase? {
        let sorted = phases.sorted { $0.number < $1.number }
        var cursor = 0
        for phase in sorted {
            let phaseStart = cursor + 1
            let phaseEnd = cursor + phase.weeks
            if weekNumber >= phaseStart && weekNumber <= phaseEnd {
                return phase
            }
            cursor = phaseEnd
        }
        return nil
    }

    /// 1-based position of the given plan-week within its phase.
    /// (e.g. week 15 of a 12-week base + 6-week build is week 3 of the
    /// build phase.)
    private static func weekPositionInPhase(_ weekNumber: Int, phases: [TrainingPhase]) -> Int {
        let sorted = phases.sorted { $0.number < $1.number }
        var cursor = 0
        for phase in sorted {
            let phaseStart = cursor + 1
            let phaseEnd = cursor + phase.weeks
            if weekNumber >= phaseStart && weekNumber <= phaseEnd {
                return weekNumber - phaseStart + 1
            }
            cursor = phaseEnd
        }
        return 1
    }

    // MARK: - Stage 1: Skeleton

    private static func generateSkeleton(
        event: Event,
        profile: String,
        constraintsBlock: String,
        startDate: String,
        totalWeeks: Int,
        trainingDaysPerWeek: Int?,
        dataService: DataService?
    ) async throws -> PlanSkeleton {
        let prompt = """
        You are an expert endurance coach designing the season-level structure of a training plan. This is the same judgment call you'd make sitting down with a new client — treat it that way. Use your experience, not a template.

        RACE: "\(event.name)"
        RACE DATE: \(event.date ?? "TBD")
        DISTANCE: \(event.distance ?? "unspecified")
        GOAL TIME: \(event.goal ?? "finish strong")
        LOCATION: \(event.location ?? "unspecified")

        PLAN LENGTH: \(totalWeeks) weeks
        PLAN START DATE: \(startDate)
        TRAINING DAYS PER WEEK: \(trainingDaysPerWeek ?? 6)

        \(profile)

        \(constraintsBlock)

        YOUR JOB
        Design the phase structure you'd use for this athlete and this race. You have full latitude on:
        - How many phases (typically 2–5, but use whatever the runway demands)
        - Phase names (Base / Build / Peak / Taper are common but use what fits)
        - How many weeks each phase runs — they MUST sum to exactly \(totalWeeks)
        - Physiological target per phase
        - Weekly intensity distribution for each phase (easy / tempo / threshold / VO2 max %)
        - Volume progression rules (week-over-week % change, deload cadence)
        - Key workouts that define each phase
        - Strength focus that complements each phase
        - Deload week positioning within the phase

        RUNWAY HANDLING
        - **Long runway (> 6 months / ~26 weeks):** Most of the plan should be base building and general prep — uniform weekly structures, gradual volume progression, mileposts along the way. Reserve the specific-prep / peak / taper work for the final 16–24 weeks before race day. Do NOT compress a long plan into "a short plan + a long taper" — that wastes the runway. A real coach spends the early months building the engine, even if nothing "race-specific" is happening yet.
        - **Medium runway (12–26 weeks):** Conventional periodization — Base → Build → Peak → Taper, roughly proportional to the time available.
        - **Short runway (< 12 weeks):** Skip or compress base. Prioritize race-specific adaptations, peak, and taper. Accept that fitness gains will be limited and shape expectations around that.

        ATHLETE-SPECIFIC DESIGN
        - If the athlete has active injuries, soften progressions and reflect modifications in the phase notes.
        - If there are equipment or facility constraints, work within them.
        - If a benchmark exists (FTP, threshold pace, recent race time), anchor volume and intensity targets to it.
        - If skip patterns or recovery notes exist, plan conservatively around them.

        OUTPUT FORMAT
        Return ONLY a JSON object — no markdown fences, no prose, no commentary, no additional fields. Match this shape exactly:

        {
          "phases": [
            {
              "number": 1,
              "name": "Base",
              "startDate": "YYYY-MM-DD",
              "endDate": "YYYY-MM-DD",
              "weeks": 12,
              "deloadWeek": 4,
              "philosophy": "2–3 sentences on what this phase builds and why it matters for THIS athlete and THIS race. Specific, not generic.",
              "weekly_volume_range": {"min": 5.0, "max": 8.0, "unit": "hours"},
              "sessions_per_week": 5,
              "intensity_distribution": {"easy": 82, "tempo": 12, "threshold": 6, "vo2_max": 0},
              "key_workouts": [
                {"name": "Long Run", "description": "Progressive Z2 long run, building 10% per week within the phase"},
                {"name": "Tempo", "description": "3x10min @ LT effort, one session per week"}
              ],
              "strength_focus": "Max strength — heavy compound lifts 2x/week, 3–5 rep range",
              "physiological_goals": ["Aerobic capacity", "Mitochondrial density", "Running economy"],
              "progression_rules": "+10% volume/week for 3 weeks, -25% deload on week 4. Long run progression: starts at X, ends at Y.",
              "race_specific_notes": "Anything tying this phase to the specific race — terrain, climate, pacing, nutrition strategy"
            }
          ]
        }

        REQUIREMENTS
        1. Every phase MUST include every field shown — no omissions, no nulls on required fields.
        2. Phase weeks MUST sum to exactly \(totalWeeks).
        3. startDate / endDate on each phase MUST be contiguous — phase 2 begins the day after phase 1 ends, etc. First phase begins \(startDate).
        4. Do NOT generate a weekFocuses array. Do NOT generate daily sessions. Only phases.
        5. Write philosophy, progression_rules, and race_specific_notes specifically for this athlete and race — avoid boilerplate like "build aerobic base". Reference the athlete's profile, recent benchmarks, or race-specific demands.
        """

        let text = try await streamingCallWithRetry(
            system: "You are an expert endurance coach. You return only valid JSON matching the exact shape requested — no prose, no markdown fences, no commentary.",
            prompt: prompt,
            maxTokens: 40_000,
            logTag: "plan-skeleton",
            dataService: dataService
        )

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

        // Sanity check — phase weeks must sum to totalWeeks. If the coach
        // came up short or over, log it but trust the phase structure.
        let sum = decoded.phases.reduce(0) { $0 + $1.weeks }
        if sum != totalWeeks {
            NSLog("[plan-skeleton] phase weeks sum to \(sum), expected \(totalWeeks) — trusting model")
        }

        return PlanSkeleton(phases: decoded.phases)
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
        totalWeeks: Int,
        recentAdherenceContext: String? = nil,
        dataService: DataService?
    ) async throws -> [WeeklyPlan] {
        // Compact context about just the phases these weeks touch — don't
        // dump every phase in the plan when we're only writing 1–2 weeks.
        let relevantPhaseNums = Set(weekNums.compactMap { phaseForWeek($0, in: skeleton.phases)?.number })
        let phaseContext = skeleton.phases
            .filter { relevantPhaseNums.contains($0.number) }
            .map { phase -> String in
                let dist = phase.intensityDistribution
                let distLine = dist.map {
                    "easy \($0.easy)% / tempo \($0.tempo)% / threshold \($0.threshold)% / VO2max \($0.vo2max)%"
                } ?? "—"
                let volume = phase.weeklyVolumeRange.map {
                    "\($0.min)–\($0.max) \($0.unit)/wk"
                } ?? "—"
                let keyWorkouts = (phase.keyWorkouts ?? [])
                    .map { "    • \($0.name): \($0.description)" }
                    .joined(separator: "\n")
                let goals = (phase.physiologicalGoals ?? []).joined(separator: ", ")
                return """
                Phase \(phase.number) — \(phase.name) (\(phase.weeks) weeks, deload week \(phase.deloadWeek ?? 0)):
                - Philosophy: \(phase.philosophy ?? "—")
                - Weekly volume: \(volume)
                - Sessions/week: \(phase.sessionsPerWeek ?? 0)
                - Intensity mix: \(distLine)
                - Key workouts:
                \(keyWorkouts)
                - Strength focus: \(phase.strengthFocus ?? "—")
                - Physiological targets: \(goals)
                - Progression: \(phase.progressionRules ?? "—")
                - Race-specific notes: \(phase.raceSpecificNotes ?? "—")
                """
            }
            .joined(separator: "\n\n")

        // Per-week briefs describing where each week sits inside its phase.
        let weekBriefs = weekNums.map { wn -> String in
            let phase = phaseForWeek(wn, in: skeleton.phases)
            let phaseNum = phase?.number ?? 1
            let phaseName = phase?.name ?? "phase"
            let phaseWeeks = phase?.weeks ?? 0
            let position = weekPositionInPhase(wn, phases: skeleton.phases)
            let isDeload = phase?.deloadWeek.map { $0 == position } ?? false
            let deloadTag = isDeload ? " · DELOAD WEEK — cut volume ~25-30%" : ""
            return "- Week \(wn) of \(totalWeeks): week \(position) of \(phaseWeeks) in \(phaseName) (phase \(phaseNum))\(deloadTag)"
        }.joined(separator: "\n")

        let firstWeek = weekNums.first ?? 1
        let adherenceBlock = recentAdherenceContext.map { "\n\n\($0)" } ?? ""

        let prompt = """
        You are an expert endurance coach writing the daily sessions for a specific week (or two) of a training plan. Use your judgment — you're not filling in a template, you're prescribing work for a real athlete based on where they are in the plan and how they're actually doing.

        RACE: "\(event.name)" on \(event.date ?? "TBD")
        GOAL: \(event.goal ?? "finish strong")

        \(profile)

        \(constraintsBlock)

        PHASE CONTEXT:
        \(phaseContext)\(adherenceBlock)

        WEEKS TO GENERATE:
        \(weekBriefs)

        YOUR JOB
        For each week listed, write 7 days of sessions (Monday through Sunday). Draw on the phase context for volume, intensity, and key workout placement. Progress the work week-over-week within the phase. Adapt to any adherence history above — if the athlete is missing key sessions, pull back; if they're nailing everything, progress. Be specific, not generic.

        OUTPUT FORMAT
        Return ONLY a JSON object — no markdown fences, no prose, no commentary. Match this shape exactly:

        {
          "weeks": [
            {
              "weekNumber": \(firstWeek),
              "phase": 1,
              "focusOfWeek": "ONE sentence naming the adaptation and position in the phase (e.g. 'Threshold build — second week of progression, key session is Thursday's 3x10min @ LT')",
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
                      "workout": "1–3 sentences of concrete instructions",
                      "notes": "2–4 sentence personalized coach note",
                      "fuel": {
                        "pre": "macro targets + timing + 2-3 food options",
                        "during": "water only, or specific carb/electrolyte plan for sessions > 60min",
                        "post": "protein + carb targets + 2-3 food options"
                      }
                    }
                  ]
                },
                {
                  "day": "tuesday",
                  "isRest": true,
                  "sessions": [],
                  "rest_note": "1–2 sentence personalized recovery advice"
                }
              ]
            }
          ]
        }

        REQUIREMENTS
        1. Generate ALL \(weekNums.count) week(s) listed, each with all 7 days in order: monday, tuesday, wednesday, thursday, friday, saturday, sunday.
        2. Rest days: `isRest: true`, empty `sessions` array, REQUIRED `rest_note` (1–2 personalized sentences).
        3. `effort_category` must be one of: easy, recovery, tempo, threshold, long_endurance, vo2max, strength, race, rest.
        4. `session.type` must be one of: run, bike, swim, strength, brick, hike, other.
        5. **Numeric fields MUST be JSON numbers, never quoted strings.** That applies to every one of `duration`, `estimated_duration_min`, `estimated_duration_max`, `distance_miles`, `weight`, `reps`, `sets`, `rest`. Write `"weight": 35` and `"duration": 45`, NEVER `"weight": "35"`, `"weight": "35 lb"`, or `"duration": "45m"`. If you want to note a unit, put it in the exercise or session `notes` field — the numeric field itself is just a number.
        6. Every non-rest session REQUIRES `purpose` (one sentence), `workout` (1–3 sentences), `notes` (2–4 sentence personalized coach note — never boilerplate), and `fuel` (pre/during/post).
        7. `pace_range`: compute from athlete benchmarks + zone when a benchmark exists. OMIT the field if no benchmark — don't guess.
        8. `priority`: "red" for 2–3 key workouts per week that cannot be skipped, "yellow" for flexible sessions.
        9. `warning`: OMIT unless the athlete has an active injury affecting THIS specific session. When present, name the modification ("Skip X if Y", "Substitute A for B").
        10. Every strength session REQUIRES an `exercises` array. Each exercise: name, exerciseType ("weighted"|"bodyweight"|"banded"|"timed"|"cardio-drill"), sets (number), reps (number, or duration (number) for timed), weight (number, in the athlete's weight unit), band (string — "light"|"medium"|"heavy"), rest (number of seconds), notes (form cue specific to this athlete). All numeric fields are JSON numbers; only `band` and `notes` are strings.
        11. Long runs progress week-over-week within the phase. Deload weeks drop volume ~25-30%.
        12. Use the phase context and week position above to pick the right intensity, volume, and key-workout placement. A tempo/threshold session in a build week should align with that phase's listed key workouts.
        """

        let logTag = "plan-week-batch-\(weekNums.first ?? 0)-\(weekNums.last ?? 0)"
        let text = try await streamingCallWithRetry(
            system: "You are an expert endurance coach. You return only valid JSON matching the exact shape requested — no prose, no markdown fences, no commentary. Every field is populated for every session.",
            prompt: prompt,
            maxTokens: 10_000,
            logTag: logTag,
            dataService: dataService
        )

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

    // MARK: - Streaming call wrapper

    /// Wraps `callEdgeFunctionStreaming` with one retry on transient failure.
    /// Streaming doesn't resume mid-flight, so a retry restarts the whole
    /// call — fine for our ~30-60s skeleton/week generations.
    private static func streamingCallWithRetry(
        system: String,
        prompt: String,
        maxTokens: Int,
        logTag: String,
        dataService: DataService?
    ) async throws -> String {
        let messages: [[String: Any]] = [
            ["role": "user", "content": prompt]
        ]

        do {
            return try await callEdgeFunctionStreaming(
                system: system,
                messages: messages,
                maxTokens: maxTokens
            )
        } catch {
            NSLog("[\(logTag)] first streaming attempt failed: \(error.localizedDescription) — retrying once")
            try? await Task.sleep(for: .seconds(2))
            return try await callEdgeFunctionStreaming(
                system: system,
                messages: messages,
                maxTokens: maxTokens
            )
        }
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

    /// Picks a start date: event.date - totalWeeks*7 if race date is set,
    /// otherwise today. Always snapped to the Monday of the resulting week
    /// so downstream week math (`planStart + (weekNum-1)*7 + dayIdx`) always
    /// lands on the expected weekday.
    private static func computeStartDate(for event: Event, totalWeeks: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let raw: Date = {
            if let raceDateStr = event.date, let raceDate = formatter.date(from: raceDateStr) {
                return Calendar.current.date(byAdding: .day, value: -(totalWeeks - 1) * 7, to: raceDate) ?? Date()
            }
            return Date()
        }()
        return formatter.string(from: mondayOf(raw))
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
