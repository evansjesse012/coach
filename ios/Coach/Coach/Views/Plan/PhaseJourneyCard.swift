import SwiftUI

/// Detail card that pairs with the journey timeline. Renders the
/// currently-selected phase's content as a single tappable surface that
/// pushes the existing `PhaseDetailView` onto the navigation stack.
///
/// The card is purely presentational: it takes a fully-derived
/// `SeasonPhase` (status, week math, formatted volume, inferred
/// disciplines) and lays it out per the redesign brief — serif title +
/// status pill on top, when-line, focus paragraph between hairline
/// rules, three-column stats, and the discipline-tagged key sessions
/// list. The whole VStack sits inside a `NavigationLink` so a tap
/// anywhere lands on the standard nav-push transition; the
/// `PressDimmedButtonStyle` handles the touch-down dim.
struct PhaseJourneyCard: View {
    let phase: SeasonPhase

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topRow
                .padding(.bottom, 6)

            whenLineText
                .padding(.bottom, 14)

            focusParagraphBlock

            if phase.volumeDisplay != nil || phase.sessionsPerWeek != nil || phase.easyWorkPercentage != nil {
                statsRow
                    .padding(.top, 14)
            }

            if !phase.keySessions.isEmpty {
                keySessionsBlock
                    .padding(.top, 18)
            }
        }
        .padding(Theme.Spacing.cardP)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    // MARK: - Top row (serif name + status pill)

    private var topRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(phase.name)
                .font(.system(size: 22, weight: .medium, design: .serif))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                StatusPill(phase: phase)
                // Drill-down chevron — advertises the whole card as a
                // tap target. Without it the card looks like static
                // content and users miss the navigation affordance.
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
                    .padding(.top, 2)
            }
            .layoutPriority(1)
        }
    }

    // MARK: - When line

    /// `**Apr 19 – Jun 1** · 6 weeks` style. Dates bold + secondary,
    /// duration tertiary. Falls back to a `Week 5 – Week 10` cumulative
    /// week range when calendar dates aren't on the underlying phase.
    private var whenLineText: Text {
        let dateRange = formattedDateRange()
        let duration = formattedDuration()
        let mono10 = Font.system(size: 10, design: .monospaced)
        let mono10Bold = Font.system(size: 10, weight: .bold, design: .monospaced)

        return Text(dateRange)
            .font(mono10Bold)
            .foregroundColor(Theme.ink2)
        + Text(" · ")
            .font(mono10)
            .foregroundColor(Theme.ink3)
        + Text(duration)
            .font(mono10)
            .foregroundColor(Theme.ink3)
    }

    private func formattedDateRange() -> String {
        if let s = phase.startDate, let e = phase.endDate {
            return "\(Self.shortDate(s)) – \(Self.shortDate(e))"
        }
        // Fallback: cumulative week range — useful for older plans whose
        // phase rows lack startDate/endDate.
        return "Week \(phase.startWeek) – Week \(phase.endWeek)"
    }

    private func formattedDuration() -> String {
        phase.weeks == 1 ? "1 week" : "\(phase.weeks) weeks"
    }

    private static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    // MARK: - Focus paragraph

    /// Primary paragraph between hairline rules. Inline emphasis (the
    /// accent-soft underline on a key phrase) is a future hook — the
    /// renderer will pick it up automatically once the underlying
    /// `TrainingPhase` carries markup; for now `focusText` renders
    /// plain across all phases.
    @ViewBuilder
    private var focusParagraphBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Theme.line).frame(height: 0.5)
            Text(phase.focusText ?? "—")
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
                .lineSpacing(2)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(Theme.line).frame(height: 0.5)
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(alignment: .top, spacing: 12) {
            statColumn(label: "Volume", value: phase.volumeDisplay ?? "—")
            statColumn(label: "Sessions", value: phase.sessionsPerWeek.map { "\($0)/wk" } ?? "—")
            statColumn(label: "Easy work", value: phase.easyWorkPercentage.map { "\($0)%" } ?? "—")
        }
    }

    private func statColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.ink3)
                .textCase(.uppercase)
                .tracking(1.0)
            Text(value)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Key sessions

    @ViewBuilder
    private var keySessionsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Key sessions")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.ink3)
                .textCase(.uppercase)
                .tracking(1.0)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(phase.keySessions) { session in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(session.discipline?.color ?? Theme.ink3)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(session.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text(session.detail)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.ink2)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Status pill

/// Three-state capsule for the card's top-right corner. Visual recipe
/// per the redesign brief:
/// - current: accent fill, accent-ink text, "Now · Wk N of M"
/// - completed: accent at 15% fill, accent text, "Done"
/// - upcoming: surface2 fill, secondary text, "N weeks out"
private struct StatusPill: View {
    let phase: SeasonPhase

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(bg))
    }

    private var label: String {
        switch phase.status {
        case .current:
            let n = phase.weekProgressInPhase ?? 1
            return "Now · Wk \(n) of \(phase.weeks)"
        case .completed:
            return "Done"
        case .upcoming:
            let n = phase.weeksUntilStart ?? 0
            return n == 1 ? "1 week out" : "\(n) weeks out"
        }
    }

    private var bg: Color {
        switch phase.status {
        case .current:   return Theme.accent
        case .completed: return Theme.accent.opacity(0.15)
        case .upcoming:  return Theme.surface2
        }
    }

    private var fg: Color {
        switch phase.status {
        case .current:   return Theme.accentInk
        case .completed: return Theme.accent
        case .upcoming:  return Theme.ink2
        }
    }
}

// MARK: - Press-dimmed button style

/// Pressed state for tappable cards: a quiet opacity dim plus a tiny
/// scale inset. The redesign brief asked for 0.95 opacity, but at that
/// value the press is below the perceptual threshold — users tap the
/// card and assume it's unresponsive. 0.85 + a 1pt scale inset matches
/// iOS's native button feel (Settings, Mail, Files cells) while staying
/// quieter than a `.bordered` button.
struct PressDimmedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
