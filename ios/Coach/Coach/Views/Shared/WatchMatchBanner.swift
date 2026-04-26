import SwiftUI

/// Inline banner shown on Today when HealthKit imports a workout the
/// matcher tied to a prescribed session — but the athlete hasn't yet
/// confirmed. Tapping opens `WatchMatchConfirmSheet` for confirmation.
///
/// Replaces the old silent auto-apply behavior. Nothing is written to
/// the prescribed session until the athlete taps through here.
struct WatchMatchBanner: View {
    let match: PendingWatchMatch
    let totalCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "applewatch")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.accentSoft))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(headlineText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        if totalCount > 1 {
                            Text("· \(totalCount)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    Text(subheadText)
                        .font(Theme.Typography.monoMeta)
                        .foregroundStyle(Theme.ink3)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface1)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(Theme.accent.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New workout from Apple Watch — tap to review")
    }

    private var headlineText: String {
        "New from Apple Watch"
    }

    /// Short one-liner: e.g. "Looks like your Z2 run · 42m"
    private var subheadText: String {
        let label = match.session.label
        let duration = "\(match.workout.duration)m"
        return "Looks like your \(label) · \(duration)"
    }
}
