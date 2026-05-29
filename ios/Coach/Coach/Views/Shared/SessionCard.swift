import SwiftUI

/// Prescribed/recorded session card.
/// 3pt left rule in discipline color, mono uppercase tag row,
/// sans session name, 3-column stat row, optional chips row.
///
/// When `status` is set, a colored header strip runs across the top of
/// the card using canonical `Theme.SessionStatusKind` tokens. The strip
/// is the only at-a-glance status signal — we no longer strikethrough
/// skipped names or dim completed bodies (both patterns removed during
/// the session-status unification; the canonical colors carry the weight
/// on their own). The sport-colored left rule is preserved so the sport
/// identity still reads in peripheral vision.
struct SessionCard: View {
    let discipline: Theme.Discipline
    /// Mono-uppercase effort or session tag, e.g. "EASY", "INTERVALS".
    var effort: String? = nil
    /// Primary session name, sans weight 600.
    let name: String
    /// Up to 3 data columns; uses mono value + smaller mono unit.
    let stats: [Stat]
    /// Optional row of action chips. Used by legacy surfaces; the Today
    /// surface passes `footer` instead for the new quick-log pill row.
    var chips: [ChipAction] = []
    /// Resolved status. When set, renders the status header strip using
    /// canonical `Theme.SessionStatusKind` tokens.
    var status: Status? = nil
    /// Optional custom footer rendered in the card's action slot —
    /// takes precedence over `chips` when present. Used by Home's Today
    /// section for the 2-tap-confirm status pill row / Edit link.
    var footer: AnyView? = nil
    /// Optional action slot rendered at the far right of the discipline
    /// tag row (top of the card body). Used for the compact status menu
    /// (ellipsis → Menu) so the whole card body stays tappable for
    /// navigation while the menu has its own hit region.
    var trailingAction: AnyView? = nil
    /// Called when the card body itself is tapped (excluding chips/footer).
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

        /// The canonical `Theme.SessionStatusKind` that owns the fill, border,
        /// tint, icon, and label for this status. All rendering goes through
        /// here so no surface hand-rolls its own status colors.
        var kind: Theme.SessionStatusKind {
            switch self {
            case .done:     return .done
            case .modified: return .modified
            case .swapped:  return .swapped
            case .skipped:  return .skipped
            }
        }

        fileprivate var detail: String? {
            switch self {
            case .done(let d), .modified(let d), .swapped(let d), .skipped(let d):
                return d
            }
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
                    // Top row: bigger discipline icon + workout name in
                    // session-title font sit side-by-side. The discipline
                    // word ("RUN", "BIKE", etc.) is intentionally absent —
                    // the icon carries that identity now. The effort label
                    // ("EASY", "LONG ENDURANCE") moved out of this row and
                    // sits below the workout name in the inner VStack.
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: discipline.icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(discipline.color)
                            // 40pt frame fits the widest discipline glyph
                            // (`bicycle`, ~36pt wide at 24pt size). A narrower
                            // frame causes the bike icon to overflow into the
                            // workout-name column.
                            .frame(width: 40, alignment: .leading)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(name)
                                .font(Theme.Typography.sessionTitle)
                                .foregroundStyle(Theme.ink)
                                .tracking(Theme.Tracking.headline)
                                .lineLimit(2)
                                .minimumScaleFactor(0.9)
                                .fixedSize(horizontal: false, vertical: true)

                            if let effort, !effort.isEmpty {
                                Text(effort)
                                    .font(Theme.Typography.monoLabel)
                                    .foregroundStyle(discipline.color)
                                    .textCase(.uppercase)
                                    .tracking(Theme.Tracking.monoLabel)
                            }
                        }

                        if let trailingAction {
                            Spacer(minLength: 8)
                            trailingAction
                        }
                    }

                    if !stats.isEmpty {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(stats.prefix(3)) { stat in
                                statColumn(stat)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .padding(.top, 2)
                    }

                    if let footer {
                        footer
                            .padding(.top, 6)
                    } else if !chips.isEmpty {
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

    @ViewBuilder
    private func statColumn(_ stat: Stat) -> some View {
        VStack(alignment: .center, spacing: 4) {
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
        SessionStatusStrip(status: status)
    }
}

// MARK: - Shared status strip

/// Colored status header strip rendered above a session card when a
/// session has been marked done / modified / swapped / skipped. Used by
/// both `SessionCard` (Home Today) and the `WeekDaySessionCard` inline
/// struct in `WeekDetailView`, so the at-a-glance status treatment
/// reads identically across every surface. Colors come from
/// `Theme.SessionStatusKind` — the single source of truth.
struct SessionStatusStrip: View {
    let status: SessionCard.Status

    var body: some View {
        let kind = status.kind
        HStack(spacing: 8) {
            Image(systemName: kind.icon)
                .font(.system(size: 12, weight: .bold))
            Text(kind.label)
                .font(Theme.Typography.monoLabel)
                .textCase(.uppercase)
                .tracking(Theme.Tracking.monoLabel)
            if let detail = status.detail, !detail.isEmpty {
                Text("·")
                    .font(Theme.Typography.monoLabel)
                    .foregroundStyle(kind.tint.opacity(0.7))
                Text(detail)
                    .font(Theme.Typography.monoMeta)
                    .foregroundStyle(kind.tint.opacity(0.85))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(kind.tint)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(kind.fill)
    }
}


// MARK: - PrescribedSession → presentation mapping

/// Maps a domain `PrescribedSession`'s completion state to the presentation-
/// layer `SessionCard.Status`, composing a concise detail string for the
/// status strip (actual duration for done/modified, swapped sport + duration
/// for swapped, skip reason for skipped). Single source of truth — used by
/// Home Today, Week Detail, and any other surface that renders a session
/// card so the status treatment reads identically everywhere.
extension PrescribedSession {
    var sessionCardStatus: SessionCard.Status? {
        guard let status = completionStatus else { return nil }
        switch status {
        case .completed:
            return .done(detail: Self.actualDurationLabel(self))
        case .modified:
            return .modified(detail: Self.modifiedDetailLabel(self))
        case .swapped:
            return .swapped(detail: Self.swappedDetailLabel(self))
        case .skipped:
            return .skipped(detail: Self.skippedDetailLabel(self))
        }
    }

    private static func actualDurationLabel(_ s: PrescribedSession) -> String? {
        if let actual = s.actualDuration { return "\(actual)m" }
        return nil
    }

    private static func modifiedDetailLabel(_ s: PrescribedSession) -> String? {
        switch (s.actualDuration, s.duration) {
        case let (actual?, prescribed?) where actual != prescribed:
            return "\(actual)m of \(prescribed)m"
        case let (actual?, _):
            return "\(actual)m"
        default:
            return nil
        }
    }

    private static func swappedDetailLabel(_ s: PrescribedSession) -> String? {
        guard let sport = s.actualSport, !sport.isEmpty else { return nil }
        let pretty = sport.prefix(1).uppercased() + sport.dropFirst()
        if let actual = s.actualDuration {
            return "Did \(actual)m of \(pretty)"
        }
        return "Did \(pretty)"
    }

    private static func skippedDetailLabel(_ s: PrescribedSession) -> String? {
        if let reason = s.skipReason {
            return reason.rawValue.capitalized
        }
        return nil
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
