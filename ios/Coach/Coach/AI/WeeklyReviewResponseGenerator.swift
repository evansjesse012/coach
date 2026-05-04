import Foundation
import Supabase
import Functions

/// W1 PR 1.3: turns a completed `WeeklyReview` into the AI-authored Half B
/// — the prose response the athlete reads + structured components for
/// later analytics. Issue #70 specifies the required components and tone;
/// this generator implements them as a single Sonnet 4.6 call.
///
/// Pattern detection (Phase 3 in `W1_PLAN.md`) is deferred — the prompt
/// asks for a `pattern_callout` only if something obvious shows up in
/// the conversation history, and `patterns_detected` is left empty for
/// now. The generator returns nil on parse / model failure so the
/// caller can finalize the review without an AI response rather than
/// blocking the whole flow on a transient hiccup.
@MainActor
enum WeeklyReviewResponseGenerator {

    /// Combined output: the prose the athlete reads + the structured
    /// breakdown stored alongside it.
    struct Output {
        let text: String
        let components: WeeklyReview.AIResponseComponents
        let patternsDetected: [String]
    }

    /// Generate the AI response for a completed review. Returns nil on
    /// failure — the caller can still persist the athlete-side fields
    /// of the review and try again later (e.g. via a retry button).
    static func generate(
        review: WeeklyReview,
        plan: TrainingPlan?,
        memory: CoachingMemory,
        recentCardio: [CardioWorkout],
        recentStrength: [StrengthSession]
    ) async -> Output? {
        let userPrompt = buildUserPrompt(
            review: review,
            plan: plan,
            memory: memory,
            recentCardio: recentCardio,
            recentStrength: recentStrength
        )

        let body: [String: Any] = [
            "system": Self.systemPrompt,
            "messages": [["role": "user", "content": userPrompt]],
            "max_tokens": 1200,
            "model": "claude-sonnet-4-6",
        ]

        let bodyData: Data
        do {
            bodyData = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return nil
        }

        let client = SupabaseService.shared.client
        do {
            let response: LightResponse = try await client.functions.invoke(
                "chat",
                options: .init(body: bodyData)
            ) { data, response in
                guard 200..<300 ~= response.statusCode else {
                    throw NSError(domain: "WeeklyReviewResponseGenerator", code: response.statusCode)
                }
                return try JSONDecoder().decode(LightResponse.self, from: data)
            }
            let raw = response.content
                .filter { $0.type == "text" }
                .compactMap(\.text)
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { return nil }
            return parse(raw)
        } catch {
            return nil
        }
    }

    // MARK: - System prompt

    private static let systemPrompt = """
    You are an expert endurance coach writing the AI-authored half of a weekly review for an athlete who just completed their Sunday-evening check-in. You have access to: their structured check-in answers, the training plan and recent workouts, and the athlete's coaching memory (patterns, injuries, motivators).

    Your job is to produce the athlete-facing response. It must hit these components in order, when applicable:

    1. ACKNOWLEDGE LIFE CONTEXT — 1–2 sentences IF the athlete mentioned work stress, illness, family stuff, or sleep disruption. Skip if nothing was raised. Lead with this when it's there; skipping it is the #1 way to feel transactional.
    2. HONEST ASSESSMENT OF THE WEEK — 2–4 sentences. Was this a hit, miss, or mixed bag? Be specific. "Strong week, hit all targets" is too generic. "Strong week — Tuesday's tempo was right on HR target, Saturday's long run pace held even in the back third, easy days actually stayed easy" is what good looks like.
    3. SPECIFIC FEEDBACK ON 1–2 KEY SESSIONS — what the data showed, what they did well, what to clean up. Reference real numbers when you have them ("HR drifted from 152 to 161 over the back half"). Skip if the athlete didn't surface a notable session and the data isn't striking.
    4. PATTERN CALLOUT — only if something across multiple weeks is genuinely surfacing in the conversation history or the structured fields ("third week in a row Tuesdays have felt rough"). Don't invent patterns; if you don't see one, omit this.
    5. DIRECT ANSWERS TO QUESTIONS — if the athlete asked something in their check-in, answer it explicitly. Don't bury it.
    6. BRIDGE TO NEXT WEEK — 1 sentence transition that previews what's coming. The paired preview will carry the details.

    TONE: warm but specific — "smart friend who happens to be your coach," not motivational poster. Acknowledge wins genuinely without over-praising. Be honest about misses without lecturing. Match the athlete's energy — if they wrote a frustrated check-in, do not respond with relentless positivity. Never use generic motivational language ("crush it," "you've got this," "trust the process"). Sections 11 and 13 of the coach prompt govern post-workout coaching and anti-patterns; the same rules apply here.

    LENGTH: 100–250 words for `ai_response_text`. Long enough to be substantive, short enough to be read on a phone.

    OUTPUT FORMAT — respond ONLY with valid JSON matching this exact shape (no markdown fence, no preamble):

    {
      "ai_response_text": "the full athlete-facing prose",
      "components": {
        "life_acknowledgment": "1-2 sentences or null",
        "week_assessment": "2-4 sentences",
        "session_feedback": [{"feedback": "..."}],
        "pattern_callout": "1-2 sentences or null",
        "questions_answered": [{"question": "...", "answer": "..."}],
        "bridge_to_next_week": "1 sentence"
      },
      "patterns_detected": []
    }

    `patterns_detected` is reserved for Phase 3 algorithmic detection — leave it empty. Use null (not empty string) for components that don't apply this week.
    """

    // MARK: - User prompt

    private static func buildUserPrompt(
        review: WeeklyReview,
        plan: TrainingPlan?,
        memory: CoachingMemory,
        recentCardio: [CardioWorkout],
        recentStrength: [StrengthSession]
    ) -> String {
        var lines: [String] = []
        lines.append("Week being reviewed: \(review.weekStartDate) to \(review.weekEndDate).")

        // Adherence
        if let pct = review.adherencePct {
            lines.append("Adherence: \(Int(pct))%.")
        }

        // Structured check-in answers
        lines.append("")
        lines.append("Athlete check-in answers:")
        if let s = review.sleepAvgHours      { lines.append("- Sleep avg: \(String(format: "%.1f", s))h") }
        if let e = review.energyRating       { lines.append("- Energy: \(e)/10") }
        if let m = review.motivationRating   { lines.append("- Motivation: \(m)/10") }
        if let s = review.sorenessLevel      {
            var line = "- Soreness: \(s.rawValue)"
            if let loc = review.sorenessLocation, !loc.isEmpty { line += " (\(loc))" }
            lines.append(line)
        }
        if review.painFlag {
            lines.append("- Pain flag: TRUE\(review.painDescription.map { " — \($0)" } ?? "")")
        }
        if let st = review.lifeStressRating  { lines.append("- Life stress: \(st)/10") }
        if let bw = review.bodyWeight        { lines.append("- Body weight: \(String(format: "%.1f", bw))") }

        // Free-text answers
        if let t = review.bestSessionText, !t.isEmpty   { lines.append("- Best session: \(t)") }
        if let t = review.worstSessionText, !t.isEmpty  { lines.append("- Worst session: \(t)") }
        if let t = review.lifeContext, !t.isEmpty       { lines.append("- Life context: \(t)") }
        if let t = review.questions, !t.isEmpty         { lines.append("- Questions raised: \(t)") }
        if let t = review.nextWeekFocus, !t.isEmpty     { lines.append("- Next-week focus (athlete's framing): \(t)") }

        // Plan / phase context
        if let plan {
            lines.append("")
            lines.append("Training plan context:")
            if let race = plan.raceName { lines.append("- Race: \(race)") }
            if let date = plan.raceDate { lines.append("- Race date: \(date)") }
            lines.append("- Current phase: \(plan.currentPhase)")
            lines.append("- Current week: \(plan.currentWeek) of \(plan.totalWeeks)")
        }

        // Coaching memory — patterns + active injuries are highest-leverage
        let activePatterns = memory.observations.patterns.prefix(5)
        if !activePatterns.isEmpty {
            lines.append("")
            lines.append("Known patterns:")
            for p in activePatterns { lines.append("- \(p)") }
        }
        let activeInjuries = memory.injuries.filter { $0.status != "resolved" }
        if !activeInjuries.isEmpty {
            lines.append("")
            lines.append("Active injuries:")
            for inj in activeInjuries.prefix(3) {
                lines.append("- \(inj.area) (\(inj.status), \(inj.severity))")
            }
        }

        // Recent sessions — last 7 days for session-specific feedback context
        let recent = formatRecentSessions(cardio: recentCardio, strength: recentStrength, weekStart: review.weekStartDate, weekEnd: review.weekEndDate)
        if !recent.isEmpty {
            lines.append("")
            lines.append("Sessions logged this week:")
            lines.append(contentsOf: recent)
        }

        lines.append("")
        lines.append("Write the review response. Output JSON only.")
        return lines.joined(separator: "\n")
    }

    private static func formatRecentSessions(
        cardio: [CardioWorkout],
        strength: [StrengthSession],
        weekStart: String,
        weekEnd: String
    ) -> [String] {
        var out: [String] = []
        for w in cardio where w.date >= weekStart && w.date <= weekEnd {
            var line = "- \(w.date) \(w.sport.rawValue): \(w.duration)min"
            if let dist = w.distance { line += ", \(dist)" }
            if let avg = w.avgHR { line += ", avgHR \(avg)" }
            if let n = w.notes, !n.isEmpty { line += " — \(n)" }
            out.append(line)
        }
        for s in strength where s.date >= weekStart && s.date <= weekEnd {
            let setCount = s.exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
            out.append("- \(s.date) strength: \(s.name), \(setCount) sets, \(s.duration ?? 0)min")
        }
        return out.sorted()
    }

    // MARK: - JSON parsing

    private struct Wire: Decodable {
        let aiResponseText: String
        let components: WeeklyReview.AIResponseComponents
        let patternsDetected: [String]?

        enum CodingKeys: String, CodingKey {
            case aiResponseText   = "ai_response_text"
            case components
            case patternsDetected = "patterns_detected"
        }
    }

    /// Tolerate stray whitespace, accidental markdown fences, and a
    /// leading "Here is the JSON:" preamble — the model occasionally
    /// adds these despite the system prompt asking for raw JSON.
    private static func parse(_ raw: String) -> Output? {
        let cleaned = stripJSONFence(raw)
        guard let data = cleaned.data(using: .utf8) else { return nil }
        do {
            let wire = try JSONDecoder().decode(Wire.self, from: data)
            return Output(
                text: wire.aiResponseText,
                components: wire.components,
                patternsDetected: wire.patternsDetected ?? []
            )
        } catch {
            return nil
        }
    }

    private static func stripJSONFence(_ s: String) -> String {
        var t = s
        if t.hasPrefix("```") {
            // Strip a ```json or ``` opening fence.
            if let endLineRange = t.range(of: "\n") { t = String(t[endLineRange.upperBound...]) }
        }
        if t.hasSuffix("```") {
            t = String(t.dropLast(3))
        }
        // If there's a leading "Here is..." or similar preamble before the
        // opening brace, trim to the brace.
        if let firstBrace = t.firstIndex(of: "{") { t = String(t[firstBrace...]) }
        if let lastBrace = t.lastIndex(of: "}") { t = String(t[...lastBrace]) }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Edge function response

    private struct LightResponse: Codable {
        let content: [Block]
        struct Block: Codable {
            let type: String
            let text: String?
        }
    }
}
