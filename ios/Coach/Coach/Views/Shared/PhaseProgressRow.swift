import SwiftUI

/// Small number badge + phase name + thin progress bar + meta caption.
/// When `isCurrent`, the badge fills with `accent` and the row uses
/// `accentSoft` as a background wash.
struct PhaseProgressRow: View {
    let number: Int
    let name: String
    /// 0...1 fraction complete.
    let progress: Double
    /// Small caption under the progress bar, e.g. "Wk 1 of 4 · Base".
    var caption: String? = nil
    var isCurrent: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        let content = HStack(alignment: .center, spacing: 12) {
            numberBadge

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    if isCurrent {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 6, height: 6)
                    }
                    Spacer(minLength: 0)
                }
                progressBar
                if let caption {
                    Text(caption)
                        .font(Theme.Typography.monoMeta)
                        .foregroundStyle(Theme.ink3)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.cardP)
        .padding(.vertical, 14)
        .background(isCurrent ? Theme.accentSoft : Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(isCurrent ? Theme.accent.opacity(0.5) : Theme.line, lineWidth: 1)
        )

        if let onTap {
            Button(action: onTap) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var numberBadge: some View {
        Text("\(number)")
            .font(Theme.Typography.mono(12, weight: .medium))
            .foregroundStyle(isCurrent ? Theme.accentInk : Theme.ink2)
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.badge)
                    .fill(isCurrent ? Theme.accent : Theme.surface2)
            )
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.surface2)
                Capsule()
                    .fill(isCurrent ? Theme.accent : Theme.ink2)
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
            }
        }
        .frame(height: 4)
    }
}

#Preview("PhaseProgressRow — Light") {
    VStack(spacing: 10) {
        PhaseProgressRow(
            number: 1,
            name: "Aerobic Foundation",
            progress: 0.18,
            caption: "Wk 1 of 4 · Base",
            isCurrent: true
        )
        PhaseProgressRow(
            number: 2,
            name: "Strength Build",
            progress: 0,
            caption: "Starts Jun 2"
        )
        PhaseProgressRow(
            number: 3,
            name: "Race Prep",
            progress: 0,
            caption: "6 wks"
        )
    }
    .padding(Theme.Spacing.screenH)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.bg)
    .preferredColorScheme(.light)
}

#Preview("PhaseProgressRow — Dark") {
    VStack(spacing: 10) {
        PhaseProgressRow(
            number: 1,
            name: "Aerobic Foundation",
            progress: 0.18,
            caption: "Wk 1 of 4 · Base",
            isCurrent: true
        )
        PhaseProgressRow(
            number: 2,
            name: "Strength Build",
            progress: 0,
            caption: "Starts Jun 2"
        )
        PhaseProgressRow(
            number: 3,
            name: "Race Prep",
            progress: 0,
            caption: "6 wks"
        )
    }
    .padding(Theme.Spacing.screenH)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
