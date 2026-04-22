import SwiftUI

/// Prescribed/recorded session card.
/// 3pt left rule in discipline color, mono uppercase tag row,
/// sans session name, 3-column stat row, optional chips row.
struct SessionCard: View {
    let discipline: Theme.Discipline
    /// Mono-uppercase effort or session tag, e.g. "EASY", "INTERVALS".
    var effort: String? = nil
    /// Primary session name, sans weight 600.
    let name: String
    /// Up to 3 data columns; uses mono value + smaller mono unit.
    let stats: [Stat]
    /// Optional row of action chips.
    var chips: [ChipAction] = []
    /// Called when the card body itself is tapped (excluding chips).
    var onTap: (() -> Void)? = nil

    struct Stat: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        var unit: String? = nil
    }
    struct ChipAction: Identifiable {
        let id = UUID()
        let title: String
        var variant: Chip.Variant = .default
        let action: () -> Void
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(discipline.color)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: discipline.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(discipline.color)
                    Text(effortLine)
                        .font(Theme.Typography.monoLabel)
                        .foregroundStyle(discipline.color)
                        .textCase(.uppercase)
                        .tracking(Theme.Tracking.monoLabel)
                }

                Text(name)
                    .font(Theme.Typography.sessionTitle)
                    .foregroundStyle(Theme.ink)
                    .tracking(Theme.Tracking.headline)
                    .fixedSize(horizontal: false, vertical: true)

                if !stats.isEmpty {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(stats.prefix(3)) { stat in
                            statColumn(stat)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, 2)
                }

                if !chips.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(chips) { c in
                            Chip(title: c.title, variant: c.variant, action: c.action)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
        .dsCardShadow()
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    private var effortLine: String {
        if let effort, !effort.isEmpty {
            return "\(discipline.label) · \(effort)"
        }
        return discipline.label
    }

    @ViewBuilder
    private func statColumn(_ stat: Stat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stat.label)
                .font(Theme.Typography.monoLabelS)
                .foregroundStyle(Theme.ink3)
                .textCase(.uppercase)
                .tracking(Theme.Tracking.monoLabel)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(stat.value)
                    .font(Theme.Typography.mono(18, weight: .medium))
                    .foregroundStyle(Theme.ink)
                if let unit = stat.unit {
                    Text(unit)
                        .font(Theme.Typography.mono(11, weight: .regular))
                        .foregroundStyle(Theme.ink3)
                }
            }
        }
    }
}

#Preview("SessionCard — Light") {
    VStack(spacing: 16) {
        SessionCard(
            discipline: .bike,
            effort: "Easy",
            name: "Z2 Spin — Cadence Focus",
            stats: [
                .init(label: "Time",    value: "38–45", unit: "m"),
                .init(label: "Zone",    value: "Z2"),
                .init(label: "Cadence", value: "90",    unit: "rpm"),
            ],
            chips: [
                .init(title: "Did it",   variant: .done) {},
                .init(title: "Modified") {},
                .init(title: "Swapped")  {},
                .init(title: "Skipped")  {},
            ]
        )
        SessionCard(
            discipline: .run,
            effort: "Intervals",
            name: "6 × 800m @ 5k pace",
            stats: [
                .init(label: "Time", value: "55",  unit: "m"),
                .init(label: "Zone", value: "Z4"),
                .init(label: "Pace", value: "3:40", unit: "/km"),
            ]
        )
    }
    .padding(Theme.Spacing.screenH)
    .background(Theme.bg)
    .preferredColorScheme(.light)
}

#Preview("SessionCard — Dark") {
    VStack(spacing: 16) {
        SessionCard(
            discipline: .bike,
            effort: "Easy",
            name: "Z2 Spin — Cadence Focus",
            stats: [
                .init(label: "Time",    value: "38–45", unit: "m"),
                .init(label: "Zone",    value: "Z2"),
                .init(label: "Cadence", value: "90",    unit: "rpm"),
            ],
            chips: [
                .init(title: "Did it",   variant: .done) {},
                .init(title: "Modified") {},
                .init(title: "Swapped")  {},
                .init(title: "Skipped")  {},
            ]
        )
        SessionCard(
            discipline: .swim,
            effort: "Technique",
            name: "Drill ladder — Catch",
            stats: [
                .init(label: "Time",     value: "35", unit: "m"),
                .init(label: "Distance", value: "2.0", unit: "km"),
                .init(label: "Focus",    value: "EVF"),
            ]
        )
    }
    .padding(Theme.Spacing.screenH)
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
