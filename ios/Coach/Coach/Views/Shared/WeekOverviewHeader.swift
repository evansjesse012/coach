import SwiftUI

/// Two-line header for the Home screen week overview card.
///
/// Line 1 — "Week N" (sans) on the left, date range (mono) on the right.
/// Line 2 — plain-language phase description · weeks-left-in-phase countdown,
/// single line, truncating with ellipsis. Line 2 is hidden entirely when
/// `phaseLabel` is nil (e.g. gap weeks with no active phase).
struct WeekOverviewHeader: View {
    let weekNumber: Int
    let dateRange: String
    /// Athlete-facing phase description, e.g. "Building your aerobic base".
    /// Pass `nil` to hide the second line (gap weeks / no active phase).
    let phaseLabel: String?
    /// Whole weeks left after the current week. 0 means "last week of phase".
    let weeksLeft: Int?
    /// Whether the tap chevron is shown. The week card is a NavigationLink,
    /// so the default is `true`.
    var showsChevron: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text("Week \(weekNumber)")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.14)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(dateRange)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(Theme.ink3)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                }
            }

            if let secondary = secondaryLine() {
                secondary
                    .font(.system(size: 12, weight: .medium))
                    .tracking(-0.06)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    /// Composed Text for line 2 so the middle dot can take a muted color while
    /// the description and countdown share the same baseline in a single line.
    private func secondaryLine() -> Text? {
        guard let phaseLabel, !phaseLabel.isEmpty else { return nil }
        let desc = Text(phaseLabel).foregroundColor(Theme.ink2)
        guard let weeksLeft else { return desc }
        let countdown = Text(Self.weeksLeftText(weeksLeft)).foregroundColor(Theme.ink2)
        let separator = Text(" · ").foregroundColor(Theme.ink3)
        return desc + separator + countdown
    }

    /// Grammar rules from the spec:
    ///   0  → "last week of phase"
    ///   1  → "1 wk left in phase"
    ///   >1 → "N wks left in phase"
    static func weeksLeftText(_ weeksLeft: Int) -> String {
        switch weeksLeft {
        case ..<1:  return "last week of phase"
        case 1:     return "1 wk left in phase"
        default:    return "\(weeksLeft) wks left in phase"
        }
    }
}

// MARK: - Preview card wrapper
//
// Mirrors the production week card chrome (surface, border, radius, padding,
// 7-day strip, and stats footer) so the header renders in context without
// needing a full TrainingPlan / WeekAdherence to be set up.

private struct WeekOverviewPreviewCard: View {
    let header: WeekOverviewHeader

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            WeekStrip(
                days: [
                    .init(label: "M", state: .done),
                    .init(label: "T", state: .done),
                    .init(label: "W", state: .miss),
                    .init(label: "T", state: .done),
                    .init(label: "F", state: .today),
                    .init(label: "S", state: .none),
                    .init(label: "S", state: .none),
                ],
                footer: [
                    .init(label: "Sessions",  value: "3 / 6"),
                    .init(label: "Adherence", value: "82%"),
                    .init(label: "Missed",    value: "1"),
                ]
            )
        }
        .padding(Theme.Spacing.cardP)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }
}

#Preview("Week card header — mid-phase, light") {
    WeekOverviewPreviewCard(
        header: WeekOverviewHeader(
            weekNumber: 3,
            dateRange: "Apr 14 — 20",
            phaseLabel: "Building your aerobic base",
            weeksLeft: 2
        )
    )
    .padding(Theme.Spacing.screenH)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.bg)
    .preferredColorScheme(.light)
}

#Preview("Week card header — mid-phase, dark") {
    WeekOverviewPreviewCard(
        header: WeekOverviewHeader(
            weekNumber: 3,
            dateRange: "Apr 14 — 20",
            phaseLabel: "Building your aerobic base",
            weeksLeft: 2
        )
    )
    .padding(Theme.Spacing.screenH)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}

#Preview("Week card header — last week of phase, light") {
    WeekOverviewPreviewCard(
        header: WeekOverviewHeader(
            weekNumber: 10,
            dateRange: "Jun 9 — 15",
            phaseLabel: "Growing your weekly volume",
            weeksLeft: 0
        )
    )
    .padding(Theme.Spacing.screenH)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.bg)
    .preferredColorScheme(.light)
}

#Preview("Week card header — last week of phase, dark") {
    WeekOverviewPreviewCard(
        header: WeekOverviewHeader(
            weekNumber: 10,
            dateRange: "Jun 9 — 15",
            phaseLabel: "Growing your weekly volume",
            weeksLeft: 0
        )
    )
    .padding(Theme.Spacing.screenH)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
