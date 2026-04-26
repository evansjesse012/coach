import SwiftUI

/// Confirmation sheet for a pending Apple Watch match. Shows the
/// imported workout side-by-side with the prescribed session, the
/// matcher's suggested status (already selected), and Confirm /
/// Change actions. The athlete can flip the status to any of the
/// four (done / modified / swapped / skipped) before confirming.
///
/// Confirm flow:
///   - status = .done    → links the workout, sheet dismisses, done.
///   - status = .modified, .swapped, .skipped → links the workout AND
///     hands the parent the same status so it can chain the
///     PostStatusChatSheet for context capture.
struct WatchMatchConfirmSheet: View {
    let match: PendingWatchMatch
    /// Called when the athlete confirms the link with a chosen status.
    /// Parent decides whether to chain into PostStatusChatSheet for
    /// modified/swapped/skipped.
    let onConfirm: (Theme.SessionStatusKind) -> Void
    /// Called when the athlete dismisses the link entirely. The match
    /// is removed from the pending queue and the workout falls back
    /// to the unmatched-imports list.
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pickedStatus: Theme.SessionStatusKind

    init(
        match: PendingWatchMatch,
        onConfirm: @escaping (Theme.SessionStatusKind) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.match = match
        self.onConfirm = onConfirm
        self.onDismiss = onDismiss
        self._pickedStatus = State(initialValue: Self.kindFromStatus(match.suggestedStatus))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    headlineBlock
                    workoutCard
                    matchedSessionCard
                    statusPicker
                }
                .padding(.horizontal, Theme.Spacing.screenH)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Theme.bg.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onDismiss()
                        dismiss()
                    } label: {
                        Text("Not this one")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.ink2)
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .principal) {
                    Text("LINK WORKOUT")
                        .font(Theme.Typography.monoLabel)
                        .foregroundStyle(Theme.ink3)
                        .tracking(Theme.Tracking.monoLabel)
                }
            }
        }
    }

    // MARK: - Subviews

    private var headlineBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Apple Watch imported a workout")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Looks like your \(match.session.label).")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.ink2)
        }
    }

    /// Card showing what the watch recorded.
    private var workoutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FROM YOUR WATCH")
                .font(Theme.Typography.monoLabelS)
                .foregroundStyle(Theme.ink3)
                .tracking(Theme.Tracking.monoLabel)

            HStack(spacing: 8) {
                Image(systemName: workoutDiscipline.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(workoutDiscipline.color)
                Text(match.workout.sport.label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }

            HStack(alignment: .top, spacing: 16) {
                statColumn(label: "Duration", value: "\(match.workout.duration)", unit: "m")
                if let dist = match.workout.distance, !dist.isEmpty {
                    statColumn(label: "Distance", value: dist, unit: nil)
                }
                if let avgHR = match.workout.avgHR {
                    statColumn(label: "Avg HR", value: "\(avgHR)", unit: "bpm")
                }
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

    /// Card showing the prescribed session the matcher picked.
    private var matchedSessionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MATCHES PRESCRIBED")
                .font(Theme.Typography.monoLabelS)
                .foregroundStyle(Theme.ink3)
                .tracking(Theme.Tracking.monoLabel)

            HStack(spacing: 8) {
                Image(systemName: sessionDiscipline.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(sessionDiscipline.color)
                Text(match.session.label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
            }

            HStack(alignment: .top, spacing: 16) {
                if let prescribedDur = match.session.duration {
                    statColumn(label: "Prescribed", value: "\(prescribedDur)", unit: "m")
                } else if let lo = match.session.estimatedDurationMin, let hi = match.session.estimatedDurationMax {
                    statColumn(label: "Prescribed", value: "\(lo)–\(hi)", unit: "m")
                }
                if let zone = match.session.zone, !zone.isEmpty {
                    statColumn(label: "Zone", value: zone.uppercased(), unit: nil)
                }
                if let pace = match.session.paceRange, !pace.isEmpty {
                    statColumn(label: "Pace", value: pace, unit: nil)
                }
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

    /// Status picker — pre-selected to the matcher's suggestion. Athlete
    /// can change before confirming.
    private var statusPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SUGGESTED STATUS")
                .font(Theme.Typography.monoLabelS)
                .foregroundStyle(Theme.ink3)
                .tracking(Theme.Tracking.monoLabel)

            HStack(spacing: 8) {
                statusPill(.done)
                statusPill(.modified)
                statusPill(.swapped)
                statusPill(.skipped)
            }
        }
    }

    private func statusPill(_ kind: Theme.SessionStatusKind) -> some View {
        let isPicked = pickedStatus == kind
        return Button {
            pickedStatus = kind
        } label: {
            HStack(spacing: 4) {
                Image(systemName: kind.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(kind.label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isPicked ? Color.white : kind.tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isPicked ? kind.tint : kind.fill)
            .overlay(
                Capsule().strokeBorder(kind.tint.opacity(isPicked ? 0 : 0.5), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var actionBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.line).frame(height: 1)
            HStack {
                Spacer()
                Pill(title: confirmLabel, variant: .primary) {
                    onConfirm(pickedStatus)
                    dismiss()
                }
            }
            .padding(.horizontal, Theme.Spacing.screenH)
            .padding(.vertical, 12)
        }
        .background(Theme.bg)
    }

    private var confirmLabel: String {
        switch pickedStatus {
        case .done:     return "Confirm — Done"
        case .modified: return "Confirm — Modified"
        case .swapped:  return "Confirm — Swapped"
        case .skipped:  return "Confirm — Skipped"
        case .pending:  return "Confirm"
        }
    }

    // MARK: - Helpers

    private func statColumn(label: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(Theme.Typography.monoLabelS)
                .foregroundStyle(Theme.ink3)
                .textCase(.uppercase)
                .tracking(Theme.Tracking.monoLabel)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(Theme.Typography.mono(16, weight: .medium))
                    .foregroundStyle(Theme.ink)
                if let unit {
                    Text(unit)
                        .font(Theme.Typography.mono(11))
                        .foregroundStyle(Theme.ink3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var workoutDiscipline: Theme.Discipline {
        if let sport = Sport(rawValue: match.workout.sport.rawValue) { return sport.discipline }
        return .recovery
    }

    private var sessionDiscipline: Theme.Discipline {
        if let sport = Sport(rawValue: match.session.type) { return sport.discipline }
        if match.session.type == "strength" { return .strength }
        return .recovery
    }

    private static func kindFromStatus(_ status: CompletionStatus) -> Theme.SessionStatusKind {
        switch status {
        case .completed: return .done
        case .modified:  return .modified
        case .swapped:   return .swapped
        case .skipped:   return .skipped
        }
    }
}
