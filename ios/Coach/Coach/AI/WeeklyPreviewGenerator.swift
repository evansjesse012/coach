import Foundation
import Supabase
import Functions

/// W1 PR 1.3: takes the just-completed review (or a "skipped check-in"
/// signal), the upcoming week's `WeeklyPlan`, and athlete context, and
/// produces the AI-authored preview that frames the week ahead.
///
/// Issue #70 specifies the seven required components in order — theme,
/// macro position, volume summary, key sessions, watch-outs, tactical
/// notes, life management, closing question. The deterministic volume
/// metrics (hours / distance / quality-vs-easy session counts) are
/// computed in Swift before the LLM call so the generator only handles
/// what actually requires judgment. Theme taxonomy stays free-form in
/// W1 Phase 1; Phase 5 enum's the categories.
@MainActor
enum WeeklyPreviewGenerator {

    /// Combined output we'll persist as a `WeeklyPreview` row.
    struct Output {
        let theme: String
        let themeCategory: String?
        let macroPosition: String?
        let keySessions: [WeeklyPreview.KeySession]
        let watchOuts: [WeeklyPreview.WatchOut]
        let tacticalNotes: [WeeklyPreview.TacticalNote]
        let lifeManagementNotes: [WeeklyPreview.LifeManagementNote]
        let renderedProse: String
        let closingQuestion: String?
    }

    /// Generate the preview. Returns nil on failure; caller can fall
    /// back to a generic preview or retry.
    static func generate(
        review: WeeklyReview?,                  // nil = athlete skipped the check-in
        upcomingWeek: WeeklyPlan?,              // upcoming week's plan, may be nil if no plan
        plan: TrainingPlan?,
        memory: CoachingMemory,
        trainingLoad: TrainingLoadSnapshot?,
        metrics: WeeklyPreviewMetrics
    ) async -> Output? {
        let userPrompt = buildUserPrompt(
            review: review,
            upcomingWeek: upcomingWeek,
            plan: plan,
            memory: memory,
            trainingLoad: trainingLoad,
            metrics: metrics
        )

        let body: [String: Any] = [
            "system": Self.systemPrompt,
            "messages": [["role": "user", "content": userPrompt]],
            "max_tokens": 1800,
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
                    throw NSError(domain: "WeeklyPreviewGenerator", code: response.statusCode)
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
    You are an expert endurance coach producing the proactive weekly preview for an athlete. The preview frames the week ahead — it's the single most important communication the coach sends at the week boundary. The athlete will read this on their phone Sunday evening or Monday morning and refer back to it mid-week.

    REQUIRED COMPONENTS, in this order in the rendered prose:

    1. THEME — one explicit sentence stating what kind of week this is. Examples: "This is your hardest week of the build — everything is hard on purpose." / "Recovery week — resist any urge to add intensity." / "Race week. Everything you do should support the start line." / "First week back after illness — we're rebuilding the floor, not the ceiling."
    2. MACRO POSITION — one sentence anchoring where this week fits in the season. "Week 4 of 8 in the build, 12 weeks until Oceanside." Athletes lose track of the macro every week; reanchor every time.
    3. VOLUME SUMMARY — a compact reference to the planned volume + delta from last week. The exact numbers come from `metrics` in the input — don't recompute them.
    4. KEY SESSIONS (1–3) — name them explicitly with day, why they matter this week, what success looks like, what to watch for. The implicit message: protect these, flex the others.
    5. WATCH-OUTS — athlete-specific risk callouts based on the dossier and recent patterns. Generic warnings aren't useful; athlete-specific ones are. Include a `referenced_data` field describing what data point the watch-out is grounded in.
    6. TACTICAL NOTES (optional, contextual) — pacing, fueling, gear, recovery, strength integration. Skip categories that don't apply this week.
    7. LIFE MANAGEMENT NOTES (optional) — anticipatory framing using known life context (work trips, kid schedules, weather forecasts the athlete mentioned). Each carries a `referenced_context` field naming what the note addresses.
    8. CLOSING QUESTION — always end with a door for two-way conversation: "Anything I'm missing or you want to flex?" / "Anything coming up I should know about?"

    THEME CATEGORY — classify the week into one of: base / build / peak / consolidation / recovery / race_week / taper / return_from_break / bridge. Use null only if none fit. The framing should match: a peak week reads differently from a recovery week.

    SKIPPED CHECK-IN — if `review_provided` is false, the athlete didn't complete the check-in. Lead with one short sentence acknowledging that the plan is held flat from last week and an offer to regenerate if they fill it in. The rest of the structure still applies but the watch-outs are thinner without the check-in signal.

    TONE: warm but specific. Athlete-of-one voice, not broadcast voice. Confident but not authoritarian. Specific over abstract — "Tuesday's 5×1k at threshold" beats "your hard workout." Honest about tradeoffs. Never generic motivational ("crush it," "trust the process," "this is your week"). Sections 11 and 13 of the coach prompt govern the tone; same rules apply here.

    LENGTH: 300–500 words for `rendered_prose`. Long enough to be substantive, short enough to be read carefully.

    OUTPUT FORMAT — respond ONLY with valid JSON matching this exact shape (no markdown fence, no preamble):

    {
      "theme": "one-sentence theme",
      "theme_category": "build" | "recovery" | "peak" | "race_week" | "taper" | "base" | "consolidation" | "return_from_break" | "bridge" | null,
      "macro_position": "Week N of M in <phase>, <weeks> until <event>",
      "key_sessions": [
        {"day_of_week": "tuesday", "name": "...", "why_it_matters": "...", "success_criteria": "...", "watch_for": "...", "session_id": null}
      ],
      "watch_outs": [
        {"type": "life_stress" | "sleep_deficit" | "weather" | "pattern_risk" | "injury_risk" | "schedule_conflict", "description": "...", "referenced_data": "the data point this is based on"}
      ],
      "tactical_notes": [
        {"category": "pacing" | "fueling" | "gear" | "recovery" | "strength", "note": "..."}
      ],
      "life_management_notes": [
        {"referenced_context": "what life context this addresses", "note": "..."}
      ],
      "rendered_prose": "the full body the athlete reads",
      "closing_question": "the one-sentence invitation"
    }

    Use empty arrays (not null) for components with nothing to surface. Use null for `theme_category` only as a last resort.
    """

    // MARK: - User prompt

    private static func buildUserPrompt(
        review: WeeklyReview?,
        upcomingWeek: WeeklyPlan?,
        plan: TrainingPlan?,
        memory: CoachingMemory,
        trainingLoad: TrainingLoadSnapshot?,
        metrics: WeeklyPreviewMetrics
    ) -> String {
        var lines: [String] = []
        lines.append("review_provided: \(review != nil)")

        if let review {
            lines.append("")
            lines.append("Just-completed review (the week we're previewing FOLLOWS the week reviewed here):")
            lines.append("- Adherence: \(review.adherencePct.map { "\(Int($0))%" } ?? "n/a")")
            if let e = review.energyRating       { lines.append("- Energy: \(e)/10") }
            if let m = review.motivationRating   { lines.append("- Motivation: \(m)/10") }
            if let st = review.lifeStressRating  { lines.append("- Life stress: \(st)/10") }
            if review.painFlag                   { lines.append("- Pain flag: TRUE\(review.painDescription.map { " — \($0)" } ?? "")") }
            if let s = review.sorenessLevel      { lines.append("- Soreness: \(s.rawValue)") }
            if let t = review.lifeContext, !t.isEmpty   { lines.append("- Life context: \(t)") }
            if let t = review.questions, !t.isEmpty     { lines.append("- Questions raised: \(t)") }
            if let t = review.nextWeekFocus, !t.isEmpty { lines.append("- Athlete's next-week focus: \(t)") }
        }

        // Upcoming-week plan
        lines.append("")
        if let upcomingWeek {
            lines.append("Upcoming week's plan (week \(upcomingWeek.weekNumber)):")
            if let focus = upcomingWeek.focusOfWeek, !focus.isEmpty {
                lines.append("- Focus of week (planner-set): \(focus)")
            }
            for day in upcomingWeek.sessions {
                if day.isRest == true {
                    lines.append("- \(day.day): REST\(day.restNote.map { " (\($0))" } ?? "")")
                    continue
                }
                for session in day.sessions {
                    var line = "- \(day.day): \(session.label) (\(session.type))"
                    if let dur = session.duration { line += ", \(dur)min" }
                    if let dist = session.distanceMiles { line += ", \(String(format: "%.1f", dist))mi" }
                    if let effort = session.effortCategory { line += ", \(effort.rawValue)" }
                    if let zone = session.zone { line += ", zone \(zone)" }
                    lines.append(line)
                }
            }
        } else {
            lines.append("Upcoming week's plan: NONE (no active plan or week not generated yet).")
        }

        // Plan / phase context
        if let plan {
            lines.append("")
            lines.append("Plan context:")
            if let race = plan.raceName { lines.append("- Race: \(race)") }
            if let date = plan.raceDate { lines.append("- Race date: \(date)") }
            lines.append("- Current phase: \(plan.currentPhase)")
            lines.append("- Current week: \(plan.currentWeek) of \(plan.totalWeeks)")
        }

        // Computed volume metrics
        lines.append("")
        lines.append("Computed volume metrics for the upcoming week:")
        if let h = metrics.totalPlannedHours     { lines.append("- Total planned hours: \(String(format: "%.1f", h))") }
        if let d = metrics.totalPlannedDistance  { lines.append("- Total planned distance: \(String(format: "%.1f", d)) mi") }
        if let q = metrics.numQualitySessions    { lines.append("- Quality sessions: \(q)") }
        if let e = metrics.numEasySessions       { lines.append("- Easy/recovery sessions: \(e)") }
        if let delta = metrics.deltaFromPreviousWeekPct {
            let signed = delta >= 0 ? "+\(String(format: "%.0f", delta))%" : "\(String(format: "%.0f", delta))%"
            lines.append("- Delta from previous week: \(signed)")
        }

        // Training load
        if let load = trainingLoad {
            lines.append("")
            lines.append("Training load (chronic frame):")
            lines.append("- CTL \(String(format: "%.1f", load.ctl)) · ATL \(String(format: "%.1f", load.atl)) · TSB \(String(format: "%.1f", load.tsb))" +
                         (load.ctlRamp7d.map { " · 7d Δ \(String(format: "%+.1f", $0))" } ?? ""))
        }

        // Memory: patterns, motivators, active injuries — context for life-mgmt + watch-outs
        let patterns = memory.observations.patterns.prefix(5)
        if !patterns.isEmpty {
            lines.append("")
            lines.append("Known patterns:")
            for p in patterns { lines.append("- \(p)") }
        }
        let motivators = memory.observations.motivators.prefix(3)
        if !motivators.isEmpty {
            lines.append("")
            lines.append("Motivators:")
            for m in motivators { lines.append("- \(m)") }
        }
        let activeInjuries = memory.injuries.filter { $0.status != "resolved" }
        if !activeInjuries.isEmpty {
            lines.append("")
            lines.append("Active injuries:")
            for inj in activeInjuries.prefix(3) {
                lines.append("- \(inj.area) (\(inj.status), \(inj.severity))")
            }
        }

        lines.append("")
        lines.append("Write the preview. Output JSON only.")
        return lines.joined(separator: "\n")
    }

    // MARK: - JSON parsing

    private struct Wire: Decodable {
        let theme: String
        let themeCategory: String?
        let macroPosition: String?
        let keySessions: [WeeklyPreview.KeySession]
        let watchOuts: [WeeklyPreview.WatchOut]
        let tacticalNotes: [WeeklyPreview.TacticalNote]
        let lifeManagementNotes: [WeeklyPreview.LifeManagementNote]
        let renderedProse: String
        let closingQuestion: String?

        enum CodingKeys: String, CodingKey {
            case theme
            case themeCategory          = "theme_category"
            case macroPosition          = "macro_position"
            case keySessions            = "key_sessions"
            case watchOuts              = "watch_outs"
            case tacticalNotes          = "tactical_notes"
            case lifeManagementNotes    = "life_management_notes"
            case renderedProse          = "rendered_prose"
            case closingQuestion        = "closing_question"
        }
    }

    private static func parse(_ raw: String) -> Output? {
        let cleaned = stripJSONFence(raw)
        guard let data = cleaned.data(using: .utf8) else { return nil }
        do {
            let wire = try JSONDecoder().decode(Wire.self, from: data)
            return Output(
                theme: wire.theme,
                themeCategory: wire.themeCategory,
                macroPosition: wire.macroPosition,
                keySessions: wire.keySessions,
                watchOuts: wire.watchOuts,
                tacticalNotes: wire.tacticalNotes,
                lifeManagementNotes: wire.lifeManagementNotes,
                renderedProse: wire.renderedProse,
                closingQuestion: wire.closingQuestion
            )
        } catch {
            return nil
        }
    }

    private static func stripJSONFence(_ s: String) -> String {
        var t = s
        if t.hasPrefix("```") {
            if let endLineRange = t.range(of: "\n") { t = String(t[endLineRange.upperBound...]) }
        }
        if t.hasSuffix("```") {
            t = String(t.dropLast(3))
        }
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

// MARK: - WeeklyPreviewMetrics

/// Deterministic volume metrics computed in Swift from the upcoming
/// week's `WeeklyPlan` and (optionally) the prior week's plan for the
/// delta. Computed BEFORE the LLM call so the generator doesn't have
/// to re-derive numbers it might get wrong; passed into the prompt
/// verbatim.
struct WeeklyPreviewMetrics {
    let totalPlannedHours: Double?
    let totalPlannedDistance: Double?
    let numQualitySessions: Int?
    let numEasySessions: Int?
    let deltaFromPreviousWeekPct: Double?

    static func compute(
        upcoming: WeeklyPlan?,
        previous: WeeklyPlan?
    ) -> WeeklyPreviewMetrics {
        guard let upcoming else {
            return WeeklyPreviewMetrics(
                totalPlannedHours: nil, totalPlannedDistance: nil,
                numQualitySessions: nil, numEasySessions: nil,
                deltaFromPreviousWeekPct: nil
            )
        }

        let upcomingHours = sumHours(upcoming)
        let upcomingDistance = sumDistance(upcoming)
        let (quality, easy) = countByEffort(upcoming)
        var delta: Double?
        if let prev = previous {
            let prevHours = sumHours(prev)
            if prevHours > 0 { delta = (upcomingHours - prevHours) / prevHours * 100 }
        }

        return WeeklyPreviewMetrics(
            totalPlannedHours:        upcomingHours > 0 ? upcomingHours : nil,
            totalPlannedDistance:     upcomingDistance > 0 ? upcomingDistance : nil,
            numQualitySessions:       quality,
            numEasySessions:          easy,
            deltaFromPreviousWeekPct: delta
        )
    }

    private static func sumHours(_ wp: WeeklyPlan) -> Double {
        wp.sessions.reduce(0.0) { acc, day in
            acc + day.sessions.reduce(0.0) { acc2, session in
                acc2 + Double(session.duration ?? 0) / 60.0
            }
        }
    }

    private static func sumDistance(_ wp: WeeklyPlan) -> Double {
        wp.sessions.reduce(0.0) { acc, day in
            acc + day.sessions.reduce(0.0) { acc2, session in
                acc2 + (session.distanceMiles ?? 0)
            }
        }
    }

    /// Quality buckets: tempo / threshold / vo2max / race.
    /// Easy buckets: easy / recovery.
    /// (longEndurance / strength / rest are uncategorized for the W1
    /// "key vs supporting" framing.)
    private static func countByEffort(_ wp: WeeklyPlan) -> (quality: Int, easy: Int) {
        var quality = 0, easy = 0
        for day in wp.sessions {
            for session in day.sessions {
                guard let effort = session.effortCategory else { continue }
                switch effort {
                case .tempo, .threshold, .vo2max, .race:  quality += 1
                case .easy, .recovery:                    easy += 1
                case .longEndurance, .strength, .rest:    break
                }
            }
        }
        return (quality, easy)
    }
}
