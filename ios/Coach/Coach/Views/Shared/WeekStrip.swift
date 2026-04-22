import SwiftUI

/// Horizontal 7-day strip with mono day labels.
/// Cell states: `.none` (neutral), `.done` (accent), `.miss` (warn),
/// `.today` (ink fill, bg text, bold). Optional 3-stat footer row.
struct WeekStrip: View {
    let days: [Day]
    var footer: [FooterStat]? = nil

    struct Day: Identifiable {
        let id = UUID()
        let label: String         // e.g. "M", "T", "W"
        let state: DayState
    }
    enum DayState { case none, done, miss, today }

    struct FooterStat: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(days) { day in
                    cell(day)
                        .frame(maxWidth: .infinity)
                }
            }

            if let footer, !footer.isEmpty {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(footer) { stat in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(stat.label)
                                .font(Theme.Typography.monoLabelS)
                                .foregroundStyle(Theme.ink3)
                                .textCase(.uppercase)
                                .tracking(Theme.Tracking.monoLabel)
                            Text(stat.value)
                                .font(Theme.Typography.mono(15, weight: .medium))
                                .foregroundStyle(Theme.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func cell(_ day: Day) -> some View {
        VStack(spacing: 6) {
            Text(day.label)
                .font(Theme.Typography.monoLabel)
                .foregroundStyle(Theme.ink3)
                .textCase(.uppercase)
                .tracking(Theme.Tracking.monoLabel)

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(fill(day.state))
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(stroke(day.state), lineWidth: 1)
                // Dot for done/today for visual confirmation
                if day.state == .done {
                    Circle()
                        .fill(Theme.accentInk)
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 36)
            .overlay(
                Group {
                    if day.state == .today {
                        Text("•")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.bg)
                    }
                }
            )
        }
    }

    private func fill(_ state: DayState) -> Color {
        switch state {
        case .none:  return Theme.surface2
        case .done:  return Theme.accent
        case .miss:  return Theme.warnBg
        case .today: return Theme.ink
        }
    }
    private func stroke(_ state: DayState) -> Color {
        switch state {
        case .none:  return Theme.line
        case .done:  return Theme.accentDark
        case .miss:  return Theme.warn.opacity(0.5)
        case .today: return Theme.ink
        }
    }
}

// MARK: - Preview card wrapper

private struct WeekStripPreviewCard: View {
    let title: String
    let range: String
    let strip: WeekStrip

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(range)
                    .font(Theme.Typography.monoMeta)
                    .foregroundStyle(Theme.ink3)
            }
            strip
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

#Preview("WeekStrip — Light") {
    WeekStripPreviewCard(
        title: "Aerobic Foundation",
        range: "Apr 14 — 20",
        strip: WeekStrip(
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
    )
    .padding(Theme.Spacing.screenH)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.bg)
    .preferredColorScheme(.light)
}

#Preview("WeekStrip — Dark") {
    WeekStripPreviewCard(
        title: "Aerobic Foundation",
        range: "Apr 14 — 20",
        strip: WeekStrip(
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
    )
    .padding(Theme.Spacing.screenH)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
