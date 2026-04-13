import Foundation
import Supabase
import Functions

/// Generates a full periodized TrainingPlan by calling the chat Edge Function
/// with a structured prompt. Separate from the agent loop — this is a one-shot
/// deterministic call that returns JSON matching our TrainingPlan model shape.
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
        notes: String?
    ) async throws -> TrainingPlan {
        let client = SupabaseService.shared.client

        // Build the athlete profile block so the model can plan around constraints
        let profile = buildAthleteContext(memory: athleteMemory)

        let constraintsBlock = buildConstraintsBlock(
            trainingDaysPerWeek: trainingDaysPerWeek,
            weeklyVolumeHours: weeklyVolumeHours,
            longRunDay: longRunDay,
            strengthDays: strengthDays,
            notes: notes
        )

        let startDate = computeStartDate(for: event, totalWeeks: totalWeeks)

        let userPrompt = """
        You are an expert coach. Generate a complete periodized training plan for this athlete.

        RACE: "\(event.name)"
        RACE DATE: \(event.date ?? "TBD")
        LOCATION: \(event.location ?? "TBD")
        GOAL TIME: \(event.goal ?? "finish strong")
        TOTAL WEEKS: \(totalWeeks)
        START DATE: \(startDate)

        \(profile)

        \(constraintsBlock)

        Return ONLY a JSON object matching this exact shape. No markdown fences, no prose.

        {
          "id": "GENERATE_UUID",
          "goalId": "\(event.id)",
          "raceName": "\(event.name)",
          "raceDate": "\(event.date ?? "")",
          "startDate": "\(startDate)",
          "totalWeeks": \(totalWeeks),
          "currentWeek": 1,
          "currentPhase": 1,
          "trainingDaysPerWeek": \(trainingDaysPerWeek ?? 6),
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
              "physiological_goals": [
                "Increase mitochondrial density",
                "Improve fat oxidation"
              ],
              "progression_rules": "+10% volume per week for 3 weeks, 30% deload on week 4",
              "race_specific_notes": "Race-specific notes tied to the event"
            }
          ],
          "weeklyPlans": {
            "1": {
              "weekNumber": 1,
              "phase": 1,
              "focusOfWeek": "Aerobic base building — first week of progression",
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
                      "purpose": "Aerobic base",
                      "workout": "5mi steady at conversational pace",
                      "notes": "Keep HR under 145."
                    }
                  ]
                }
              ]
            }
          }
        }

        RULES FOR THE PLAN:
        1. Generate ALL \(totalWeeks) weekly plans keyed "1" through "\(totalWeeks)".
        2. Each weeklyPlan.sessions MUST be an array of exactly 7 day objects in order: monday, tuesday, wednesday, thursday, friday, saturday, sunday.
        3. Rest days use "isRest": true with an empty sessions array.
        4. Generate 2-4 phases that make sense for the race (e.g., Base / Build / Taper or Base / Build / Peak / Taper).
        5. Each phase must include ALL fields shown in the example — philosophy, weekly_volume_range, sessions_per_week, intensity_distribution, key_workouts, strength_focus, physiological_goals, progression_rules, race_specific_notes.
        6. effort_category must be one of: easy, recovery, tempo, threshold, long_endurance, vo2max, strength, race, rest.
        7. For the "id" field, use any random string — the app will replace it.
        8. session.type must be one of: run, bike, swim, strength, brick, hike, other.
        9. distance_miles and duration are both numbers, not strings.
        10. Populate every week, every day. No placeholders.
        11. Long runs progress week-over-week within a phase. Deload weeks cut volume ~30%.
        12. Match the intensity_distribution to the phase: base is ~80/15/5/0, build is ~75/10/12/3, taper is ~80/10/8/2.
        """

        let body: [String: Any] = [
            "system": "You are an expert endurance coach. When asked for a training plan, you return only valid JSON matching the exact shape requested, with no prose, no markdown fences, and no commentary before or after. Every field in every object must be populated.",
            "messages": [
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 16000,
            "model": "claude-sonnet-4-5-20250929",
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let response: PlanChatResponse = try await client.functions.invoke(
            "chat",
            options: .init(body: bodyData)
        ) { data, response in
            guard 200..<300 ~= response.statusCode else {
                let preview = String(data: data, encoding: .utf8) ?? ""
                NSLog("[plan-generator] HTTP \(response.statusCode): \(preview)")
                throw FunctionsError.httpError(code: response.statusCode, data: data)
            }
            return try JSONDecoder().decode(PlanChatResponse.self, from: data)
        }

        let text = response.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined(separator: "\n")

        guard let json = extractJSON(from: text) else {
            throw NSError(
                domain: "TrainingPlanGenerator", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Couldn't find JSON in model output. Preview: \(text.prefix(200))"]
            )
        }
        guard let jsonData = json.data(using: .utf8) else {
            throw NSError(domain: "TrainingPlanGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "JSON encode failed"])
        }

        do {
            var plan = try JSONDecoder().decode(TrainingPlan.self, from: jsonData)
            // Always assign a fresh id — the model often returns the placeholder.
            plan = TrainingPlan(
                id: UUID().uuidString,
                goalId: plan.goalId ?? event.id,
                raceName: plan.raceName ?? event.name,
                raceDate: plan.raceDate ?? event.date,
                startDate: plan.startDate ?? startDate,
                totalWeeks: plan.totalWeeks,
                currentWeek: plan.currentWeek,
                currentPhase: plan.currentPhase,
                trainingDaysPerWeek: plan.trainingDaysPerWeek,
                phases: plan.phases,
                weeklyPlans: plan.weeklyPlans
            )
            return plan
        } catch {
            NSLog("[plan-generator] decode error: \(error)\njson preview: \(json.prefix(500))")
            throw error
        }
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
