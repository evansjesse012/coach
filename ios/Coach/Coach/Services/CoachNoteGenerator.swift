import Foundation
import Supabase
import Functions

/// Generates the daily "coach's note" shown at the top of the Home tab.
/// This is the equivalent of your coach texting you before you start your
/// day — brief, personalized, grounded in your actual data.
///
/// Called once per day from DataService after loadAll completes. The result
/// is stored as `settings.pushMessage` and persisted to Supabase so it
/// survives app restarts without regenerating until the next day.
@MainActor
enum CoachNoteGenerator {
    static func generate(
        plan: TrainingPlan?,
        memory: CoachingMemory,
        settings: UserSettings,
        events: [Event]
    ) async throws -> PushMessage {
        let today = todayString()
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let dayName = dayFormatter.string(from: Date())

        let context = buildContext(
            plan: plan,
            memory: memory,
            events: events,
            today: today,
            dayName: dayName
        )

        let personalityPrompt = getPersonalityPrompt(settings.personality, settings.customPrompt)

        let prompt = """
        \(personalityPrompt)

        You are writing a brief personal morning note to your athlete. This is the equivalent of a text message you'd send them before they start their day. It should feel like it came from someone who knows them, has been watching their training, and cares about their progress.

        RULES:
        1. Open with something specific — never "Good morning!" or "Hey there!" or "Hope you slept well!" Start with a reference to something concrete: yesterday's session, a pattern you noticed, what's coming today, or where they are in the season.
        2. Connect today's session to the bigger picture — why it matters this week, this phase, or for race day.
        3. Give one clear directive for the day. Not a full workout prescription (that's in the plan), but a coaching cue: "keep it easy today," "push the last interval," "practice your fueling," "listen to your body."
        4. If they skipped or modified recent sessions, acknowledge it without judgment but with awareness. Two skips in a week is a signal — name it.
        5. If race day is within 4 weeks, orient around that countdown.
        6. Use **bold** for the one thing you most want them to remember today.
        7. End with something forward-looking — what's next, what to prepare for, or a brief motivational anchor grounded in their actual data (never generic "you got this" or "believe in yourself").
        8. Keep it 3-6 sentences for a routine day. Up to 8 for a key day (long run, race week, phase transition, deload start).
        9. If today is a rest day, acknowledge it and frame it as part of the plan — not a day off. Tell them what the rest is setting up.
        10. Never repeat the full workout details — they'll see those in the plan. Give the coaching FRAME, not the prescription.

        FORMATTING:
        - The FIRST PARAGRAPH is the headline — one punchy sentence that captures today's story. No markdown in the headline. Example: "Threshold day — this is the session that moves the needle this week."
        - Then a blank line.
        - Then 2-4 SHORT paragraphs for the body, each separated by a blank line. Each paragraph is 1-2 sentences max. Do NOT write a single block of text.
        - Use **bold** for the key directive, typically in its own paragraph.
        - The last paragraph is forward-looking (what's tomorrow, what this sets up).

        CONTEXT:
        Today: \(today) (\(dayName))

        \(context)

        Return ONLY a JSON object — no markdown fences, no prose around it:
        {
          "text": "The coach's note using markdown for emphasis. **Bold** the one key takeaway. 3-8 sentences.",
          "actions": ["Action button 1", "Action button 2"],
          "readiness": "green",
          "statusLine": "One plain sentence framing the day."
        }

        READINESS (required):
        - "green": Athlete is rested, plan is on track, no injury flags, good week so far.
        - "yellow": Recent skips, elevated fatigue indicators, minor concerns, or a tough week. Not alarming but worth noting.
        - "red": Multiple missed sessions, soreness flags from the athlete, plan significantly off track, or returning from absence.
        Base this on the context below — adherence data, skip patterns, injury state, and training load.

        STATUS LINE (required):
        One plain sentence (NO markdown, NO bold) that frames the day. It should reference the readiness assessment and orient the athlete.
        Examples: "You're recovered and ready — let's hit today's intervals." / "Readiness is a bit low after a heavy week — we're keeping it easy." / "Two skips this week — today's session matters."

        Action buttons (1-3 short phrases the athlete can tap to start a chat):
        - If today has a workout: include "View today's workout"
        - If yesterday was skipped/modified: include something like "Talk about yesterday"
        - If race is within 4 weeks: include something race-oriented like "Race day prep"
        - Always include "Chat with coach" as a fallback
        """

        let client = SupabaseService.shared.client
        let body: [String: Any] = [
            "system": "You are an expert athletic coach. Return only valid JSON, no markdown fences.",
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 1000,
            "model": "claude-sonnet-4-6",
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let response: NoteResponse = try await client.functions.invoke(
            "chat",
            options: .init(body: bodyData)
        ) { data, response in
            guard 200..<300 ~= response.statusCode else {
                let preview = String(data: data, encoding: .utf8) ?? ""
                NSLog("[coach-note] HTTP \(response.statusCode): \(preview)")
                throw NSError(
                    domain: "CoachNoteGenerator",
                    code: response.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(response.statusCode)"]
                )
            }
            return try JSONDecoder().decode(NoteResponse.self, from: data)
        }

        let text = response.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined(separator: "\n")

        guard let json = extractJSON(from: text),
              let jsonData = json.data(using: .utf8) else {
            throw NSError(
                domain: "CoachNoteGenerator",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Couldn't parse coach note JSON"]
            )
        }

        let note = try JSONDecoder().decode(NoteContent.self, from: jsonData)

        return PushMessage(
            text: note.text,
            actions: note.actions,
            count: nil,
            ts: ISO8601DateFormatter().string(from: Date()),
            readiness: note.readiness,
            statusLine: note.statusLine
        )
    }

    // MARK: - Context builder

    private static func buildContext(
        plan: TrainingPlan?,
        memory: CoachingMemory,
        events: [Event],
        today: String,
        dayName: String
    ) -> String {
        var sections: [String] = []

        if let plan {
            // Current phase
            if let phase = plan.phases.first(where: { $0.number == plan.currentPhase }) {
                let weekPos = plan.weekIndexInPhase(phase)
                var phaseLines = [
                    "CURRENT PHASE: \(phase.name) (phase \(phase.number) of \(plan.phases.count))",
                    "Week \(weekPos) of \(phase.weeks) in this phase.",
                ]
                if let philosophy = phase.philosophy, !philosophy.isEmpty {
                    phaseLines.append("Phase philosophy: \(philosophy)")
                }
                if let deload = phase.deloadWeek, deload == weekPos {
                    phaseLines.append("THIS IS A DELOAD WEEK — volume should be reduced ~25-30%.")
                }
                sections.append(phaseLines.joined(separator: "\n"))
            }

            // Today's sessions
            let todayDayIdx = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
            if let wp = plan.weeklyPlans[String(plan.currentWeek)],
               todayDayIdx < wp.sessions.count {
                let todayPlan = wp.sessions[todayDayIdx]
                if todayPlan.isRest == true {
                    sections.append("TODAY'S PLAN: Rest day." + (todayPlan.restNote.map { " Coach note: \($0)" } ?? ""))
                } else if !todayPlan.sessions.isEmpty {
                    let sessionDescs = todayPlan.sessions.map { sess -> String in
                        var desc = "- \(sess.label) (\(sess.type))"
                        if let dur = sess.duration { desc += ", \(dur)min" }
                        if let effort = sess.effortCategory { desc += ", \(effort.rawValue)" }
                        if sess.priority == .red { desc += " [KEY SESSION]" }
                        return desc
                    }
                    sections.append("TODAY'S PLAN:\n" + sessionDescs.joined(separator: "\n"))
                } else {
                    sections.append("TODAY'S PLAN: No sessions prescribed (stub week — not yet generated).")
                }

                // Yesterday's completion state
                let yesterdayIdx = todayDayIdx == 0 ? 6 : todayDayIdx - 1
                if yesterdayIdx < wp.sessions.count {
                    let yesterdayPlan = wp.sessions[yesterdayIdx]
                    if yesterdayPlan.isRest == true {
                        sections.append("YESTERDAY: Rest day (as planned).")
                    } else if !yesterdayPlan.sessions.isEmpty {
                        let statuses = yesterdayPlan.sessions.map { sess -> String in
                            switch sess.displayState {
                            case .completed: return "\(sess.label): completed"
                            case .modified: return "\(sess.label): modified" + (sess.completionNote.map { " (\($0))" } ?? "")
                            case .swapped: return "\(sess.label): swapped to \(sess.actualSport ?? "different workout")"
                            case .skipped: return "\(sess.label): skipped" + (sess.skipReason.map { " (\($0.rawValue))" } ?? "")
                            case .needsReview: return "\(sess.label): needs review (auto-matched)"
                            case .upcoming: return "\(sess.label): not marked yet"
                            }
                        }
                        sections.append("YESTERDAY:\n" + statuses.map { "- \($0)" }.joined(separator: "\n"))
                    }
                }

                // Recent adherence (this week so far)
                let resolvedThisWeek = wp.sessions.prefix(todayDayIdx).flatMap(\.sessions)
                if !resolvedThisWeek.isEmpty {
                    let total = resolvedThisWeek.count
                    let done = resolvedThisWeek.filter { $0.isResolved }.count
                    let skipped = resolvedThisWeek.filter { $0.displayState == .skipped }.count
                    sections.append("THIS WEEK SO FAR: \(done)/\(total) sessions resolved, \(skipped) skipped.")
                }

                // Upcoming days — the prompt asks the note to be forward-looking
                // ("what's tomorrow, what this sets up"). Without these the model
                // hallucinates tomorrow's session.
                let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                var upcomingLines: [String] = []
                for offset in 1...6 {
                    let absoluteIdx = todayDayIdx + offset
                    let weekOffset = absoluteIdx / 7
                    let dayIdxInWeek = absoluteIdx % 7
                    let weekKey = String(plan.currentWeek + weekOffset)
                    guard let upcomingWp = plan.weeklyPlans[weekKey],
                          dayIdxInWeek < upcomingWp.sessions.count else { continue }
                    let dp = upcomingWp.sessions[dayIdxInWeek]
                    let prefix = offset == 1 ? "TOMORROW (\(dayLabels[dayIdxInWeek]))" : dayLabels[dayIdxInWeek]
                    if dp.isRest == true {
                        let restDesc = dp.restNote.map { "rest — \($0)" } ?? "rest"
                        upcomingLines.append("- \(prefix): \(restDesc)")
                    } else if dp.sessions.isEmpty {
                        upcomingLines.append("- \(prefix): not yet generated (stub)")
                    } else {
                        let descs = dp.sessions.map { sess -> String in
                            var d = "\(sess.label) (\(sess.type))"
                            if let dur = sess.duration { d += ", \(dur)min" }
                            if let effort = sess.effortCategory { d += ", \(effort.rawValue)" }
                            if sess.priority == .red { d += " [KEY]" }
                            return d
                        }
                        upcomingLines.append("- \(prefix): \(descs.joined(separator: "; "))")
                    }
                }
                if !upcomingLines.isEmpty {
                    sections.append("UPCOMING:\n" + upcomingLines.joined(separator: "\n"))
                }
            }

            // Race countdown
            if let raceName = plan.raceName, let raceDate = plan.raceDate {
                if let weeks = plan.weeksUntilRace() {
                    sections.append("RACE: \(raceName) in \(weeks) weeks (\(raceDate)).")
                }
            }
        } else {
            sections.append("PLAN: No training plan active. The athlete hasn't built one yet.")
        }

        // Active injuries
        let injuries = memory.injuries.filter { $0.status.lowercased() != "resolved" }
        if !injuries.isEmpty {
            let summary = injuries.map { "\($0.area) (\($0.status), \($0.severity))" }.joined(separator: "; ")
            sections.append("ACTIVE INJURIES: \(summary)")
        }

        // Benchmarks (brief)
        if !memory.benchmarks.isEmpty {
            let b = memory.benchmarks.prefix(3).map { "\($0.metric): \($0.value)" }.joined(separator: ", ")
            sections.append("BENCHMARKS: \(b)")
        }

        // Skip patterns
        let skipPatterns = memory.observations.patterns.filter {
            $0.lowercased().contains("skip") || $0.lowercased().contains("miss")
        }
        if !skipPatterns.isEmpty {
            sections.append("KNOWN PATTERNS: " + skipPatterns.joined(separator: "; "))
        }

        return sections.joined(separator: "\n\n")
    }

    // MARK: - Response types

    private struct NoteResponse: Codable {
        let content: [Block]
        struct Block: Codable {
            let type: String
            let text: String?
        }
    }

    private struct NoteContent: Codable {
        let text: String
        let actions: [String]?
        let readiness: String?
        let statusLine: String?
    }

    // MARK: - JSON extraction

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
