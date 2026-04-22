import SwiftUI

/// Fully-rounded action button.
/// - `primary`: accent background, `accentInk` label, weight 600.
/// - `secondary`: transparent, `line2` border, `ink` label, weight 500.
struct Pill: View {
    enum Variant { case primary, secondary }

    let title: String
    var icon: String? = nil
    var variant: Variant = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: weight))
                }
                Text(title)
                    .font(.system(size: 14, weight: weight))
                    .tracking(Theme.Tracking.headline)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(bg)
            .foregroundStyle(fg)
            .overlay(
                Capsule().strokeBorder(border, lineWidth: variant == .secondary ? 1 : 0)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var weight: Font.Weight {
        variant == .primary ? .semibold : .medium
    }
    private var bg: Color {
        variant == .primary ? Theme.accent : .clear
    }
    private var fg: Color {
        variant == .primary ? Theme.accentInk : Theme.ink
    }
    private var border: Color {
        variant == .primary ? .clear : Theme.line2
    }
}

#Preview("Pill — Light") {
    VStack(spacing: 12) {
        Pill(title: "Open today's session", variant: .primary) {}
        Pill(title: "Talk to coach", variant: .secondary) {}
        Pill(title: "Start", icon: "play.fill", variant: .primary) {}
        Pill(title: "Skip", icon: "forward.fill", variant: .secondary) {}
    }
    .padding()
    .background(Theme.bg)
    .preferredColorScheme(.light)
}

#Preview("Pill — Dark") {
    VStack(spacing: 12) {
        Pill(title: "Open today's session", variant: .primary) {}
        Pill(title: "Talk to coach", variant: .secondary) {}
        Pill(title: "Start", icon: "play.fill", variant: .primary) {}
        Pill(title: "Skip", icon: "forward.fill", variant: .secondary) {}
    }
    .padding()
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
