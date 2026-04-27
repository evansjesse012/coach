import Foundation

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

    /// Phase 4: a prose narrative built from HealthKit data describing
    /// the athlete's recovery story (acute vs chronic, load context,
    /// data-vs-athlete tension). nil when HealthKit hasn't reported or
    /// the data is too stale to be useful.
    let recoveryPicture: String?

    /// Phase 5: a 2-4 line summary of the athlete (current race, phase,
    /// week N of M, this-week adherence, active injuries). Lets the coach
    /// reason from current state without burning tool calls every turn.
    let athleteSummary: String?

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
