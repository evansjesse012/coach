import SwiftUI

/// Prescribed/recorded session card.
/// 3pt left rule in discipline color, mono uppercase tag row,
/// sans session name, 3-column stat row, optional chips row.
///
/// When `status` is set, a colored header strip runs across the top of
/// the card, the body dims, and a skipped session's name gets
/// strikethrough. The strip is the primary at-a-glance signal; the
/// sport-colored left rule is preserved so the sport identity still
/// reads in peripheral vision.
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
    /// Resolved status. When set, renders the status header strip,
    /// dims the body, and (for skipped) strikes through the name.
    var status: Status? = nil
    /// Called when the card body itself is tapped (excluding chips).
    /// If nil, no tap gesture is attached and the parent (e.g. a
    /// `NavigationLink`) is free to capture the tap.
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

    /// Presentation-layer status for a resolved session. Callers map their
    /// domain enum (e.g. `CompletionStatus`) to one of these cases and pass
    /// an optional detail string for the strip's meta slot (actual duration,
    /// swapped sport, skip reason, etc.).
    enum Status {
        case done(detail: String? = nil)
        case modified(detail: String? = nil)
        case swapped(detail: String? = nil)
        case skipped(detail: String? = nil)

        fileprivate var title: String {
            switch self {
            case .done:     return "Done"
            case .modified: return "Modified"
            case .swapped:  return "Swapped"
            case .skipped:  return "Skipped"
            }
        }
        fileprivate var detail: String? {
            switch self {
            case .done(let d), .modified(let d), .swapped(let d), .skipped(let d):
                return d
            }
        }
        fileprivate var icon: String {
            switch self {
            case .done:     return "checkmark.circle.fill"
            case .modified: return "pencil.circle.fill"
            case .swapped:  return "arrow.triangle.2.circlepath.circle.fill"
            case .skipped:  return "xmark.circle.fill"
            }
        }
        fileprivate var tint: Color {
            switch self {
            case .done:     return CoachColors.green
            case .modified: return CoachColors.yellow
            case .swapped:  return Theme.info
            case .skipped:  return Theme.warn
            }
        }
        fileprivate var stripBackground: Color {
            switch self {
            case .skipped: return Theme.warnBg
            default:       return tint.opacity(0.15)
            }
        }
        fileprivate var strikesThroughName: Bool {
            if case .skipped = self { return true }
            return false
        }
        fileprivate var bodyOpacity: Double {
            if case .skipped = self { return 0.65 }
            return 0.85
        }
    }

    var body: some View {
        let card = VStack(alignment: .leading, spacing: 0) {
            if let status {
                statusHeader(status)
            }

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
                        .strikethrough(status?.strikesThroughName == true, color: Theme.ink3)
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
                .opacity(status?.bodyOpacity ?? 1.0)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
        .dsCardShadow()

        // Attach a tap gesture only when a caller actually wants one.
        // Leaving it unconditional would swallow taps before a wrapping
        // NavigationLink could route them to a detail view.
        if let onTap {
            card
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
        } else {
            card
        }
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

    @ViewBuilder
    private func statusHeader(_ status: Status) -> some View {
        HStack(spacing: 8) {
            Image(systemName: status.icon)
                .font(.system(size: 12, weight: .bold))
            Text(status.title)
                .font(Theme.Typography.monoLabel)
                .textCase(.uppercase)
                .tracking(Theme.Tracking.monoLabel)
            if let detail = status.detail, !detail.isEmpty {
                Text("·")
                    .font(Theme.Typography.monoLabel)
                    .foregroundStyle(status.tint.opacity(0.7))
                Text(detail)
                    .font(Theme.Typography.monoMeta)
                    .foregroundStyle(status.tint.opacity(0.85))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(status.tint)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(status.stripBackground)
    }
}

#Preview("SessionCard — Light") {
    ScrollView {
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
                discipline: .bike,
                effort: "Easy",
                name: "Z2 Spin — Cadence Focus",
                stats: [
                    .init(label: "Time", value: "45", unit: "m"),
                    .init(label: "Zone", value: "Z2"),
                    .init(label: "Cadence", value: "90", unit: "rpm"),
                ],
                chips: [.init(title: "Tap to undo", variant: .done) {}],
                status: .done(detail: "45m")
            )
            SessionCard(
                discipline: .run,
                effort: "Intervals",
                name: "6 × 800m @ 5k pace",
                stats: [
                    .init(label: "Time", value: "42", unit: "m"),
                    .init(label: "Zone", value: "Z4"),
                    .init(label: "Pace", value: "3:45", unit: "/km"),
                ],
                chips: [.init(title: "Tap to undo", variant: .done) {}],
                status: .modified(detail: "42m of 55m")
            )
            SessionCard(
                discipline: .swim,
                effort: "Technique",
                name: "Drill ladder — Catch",
                stats: [
                    .init(label: "Time", value: "60", unit: "m"),
                    .init(label: "Distance", value: "2.0", unit: "km"),
                ],
                chips: [.init(title: "Tap to undo", variant: .done) {}],
                status: .swapped(detail: "Did a 60m run")
            )
            SessionCard(
                discipline: .strength,
                effort: "Upper",
                name: "Push · Pull · Core",
                stats: [.init(label: "Time", value: "45", unit: "m")],
                chips: [.init(title: "Tap to undo", variant: .done) {}],
                status: .skipped(detail: "Fatigue")
            )
        }
        .padding(Theme.Spacing.screenH)
    }
    .background(Theme.bg)
    .preferredColorScheme(.light)
}

#Preview("SessionCard — Dark") {
    ScrollView {
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
                discipline: .bike,
                effort: "Easy",
                name: "Z2 Spin — Cadence Focus",
                stats: [.init(label: "Time", value: "45", unit: "m")],
                chips: [.init(title: "Tap to undo", variant: .done) {}],
                status: .done(detail: "45m")
            )
            SessionCard(
                discipline: .strength,
                effort: "Upper",
                name: "Push · Pull · Core",
                stats: [.init(label: "Time", value: "45", unit: "m")],
                chips: [.init(title: "Tap to undo", variant: .done) {}],
                status: .skipped(detail: "Fatigue")
            )
        }
        .padding(Theme.Spacing.screenH)
    }
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
