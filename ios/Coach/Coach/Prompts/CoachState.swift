import Foundation

/// Snapshot of the athlete's chronic training load for the coach prompt.
/// Built fresh each turn from `daily_training_load`. Section 7 explains
/// how to interpret the numbers; this struct just carries them.
struct TrainingLoadSnapshot {
    /// "yyyy-MM-dd" of the row these numbers come from. May be older than
    /// today if the athlete hasn't logged anything recently.
    let asOf: String
    let ctl: Double           // chronic training load (~6-week EWMA)
    let atl: Double           // acute training load   (~7-day EWMA)
    let tsb: Double           // training stress balance (CTL − ATL)
    /// CTL change vs ~7 days ago. nil when there isn't enough history
    /// (athlete just started logging). Positive = building, negative =
    /// detraining or recovery.
    let ctlRamp7d: Double?
}

/// Per-turn state injected into the dynamic block of the assembled
/// system prompt. Decision #2: this block is rendered fresh every turn;
/// the static block above and below it stays byte-identical so Anthropic
/// prompt caching fires.
///
/// Phase 1 carries date + persona content. Recovery picture (Phase 4)
/// and athlete summary (Phase 5) are stubs today — when populated they
/// inject into the same block so the coach has fresh context without
/// invalidating the cached static prompt.
struct CoachState {
    /// Today's date at the moment the prompt is being built.
    let today: Date

    /// Phase 4a: structured chronic-load snapshot (CTL/ATL/TSB + 7-day
    /// CTL ramp). Complements `recoveryPicture` — load is the chronic
    /// frame, recovery picture is the acute overlay. nil when the
    /// daily-load table has no rows yet for this user.
    let trainingLoad: TrainingLoadSnapshot?

    /// Phase 4: a prose narrative built from HealthKit data describing
    /// the athlete's recovery story (acute vs chronic, load context,
    /// data-vs-athlete tension). nil when HealthKit hasn't reported or
    /// the data is too stale to be useful.
    let recoveryPicture: String?

    /// Phase 5: a 2-4 line summary of the athlete (current race, phase,
    /// week N of M, this-week adherence, active injuries). Lets the coach
    /// reason from current state without burning tool calls every turn.
    let athleteSummary: String?

    /// Per-turn recent-conversation summaries for thread-to-thread
    /// continuity. Was previously appended to the static prompt in
    /// `AgentLoop`, which broke caching since each conversation has
    /// different summaries. Lives here now so the static block stays
    /// byte-identical across turns.
    let recentConversationSummaries: [String]

    /// Render this state plus the active persona's content as a single
    /// dynamic block. Sits between Section 11 and Section 12 of the
    /// assembled prompt.
    func render(personality: Personality, customText: String) -> String {
        var lines: [String] = []

        // Persona content first — it's coaching content, not data state.
        lines.append(activePersonaContent(personality: personality, customText: customText))

        // Structured state block follows, fenced for the model to identify.
        lines.append("")
        lines.append("[COACH STATE]")
        lines.append(todayLine)
        if let trainingLoad {
            lines.append("")
            lines.append(trainingLoadLine(trainingLoad))
        }
        if let recoveryPicture, !recoveryPicture.isEmpty {
            lines.append("")
            lines.append("Recovery picture:")
            lines.append(recoveryPicture)
        }
        if let athleteSummary, !athleteSummary.isEmpty {
            lines.append("")
            lines.append("Athlete summary:")
            lines.append(athleteSummary)
        }
        if !recentConversationSummaries.isEmpty {
            lines.append("")
            lines.append("Recent conversations (for thread-to-thread continuity):")
            for (idx, summary) in recentConversationSummaries.enumerated() {
                lines.append("- \(idx + 1). \(summary)")
            }
        }
        lines.append("[/COACH STATE]")

        return lines.joined(separator: "\n")
    }

    private var todayLine: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        return "Today: \(dateFormatter.string(from: today)) (\(dayFormatter.string(from: today)))"
    }

    /// One-line compact rendering of the training-load snapshot. Section 7
    /// teaches the coach how to interpret these — this just emits the
    /// numbers. Format: "Training load (as of YYYY-MM-DD): CTL X · ATL Y ·
    /// TSB Z [· 7d CTL Δ ±A]". Numbers rounded to one decimal to match
    /// the PMC chart's display precision.
    private func trainingLoadLine(_ load: TrainingLoadSnapshot) -> String {
        let f = { (x: Double) -> String in String(format: "%.1f", x) }
        var parts = ["CTL \(f(load.ctl))", "ATL \(f(load.atl))", "TSB \(f(load.tsb))"]
        if let ramp = load.ctlRamp7d {
            let signed = ramp >= 0 ? "+\(f(ramp))" : f(ramp)
            parts.append("7d CTL Δ \(signed)")
        }
        return "Training load (as of \(load.asOf)): " + parts.joined(separator: " · ")
    }

    private func activePersonaContent(personality: Personality, customText: String) -> String {
        switch personality {
        case .normal:  return Persona_Normal.content
        case .goggins: return Persona_Goggins.content
        case .hype:    return Persona_Hype.content
        case .custom:
            let trimmed = customText.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? Persona_Normal.content : "Your coaching style: \(trimmed)"
        }
    }
}
