import SwiftUI

/// Floating action button — 48×50 pill, icon centered. Two visual variants:
/// `.accent` (brand moments like the coach chat entry) and `.ink` (neutral
/// per-screen actions like the Goals add-item button).
struct FAB: View {
    enum Variant { case accent, ink }

    let icon: String
    var variant: Variant = .accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 48, height: 50)
                .background(background)
                .clipShape(Capsule())
                .shadow(color: shadow, radius: 16, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var background: Color {
        variant == .accent ? Theme.accent : Theme.ink
    }
    private var foreground: Color {
        variant == .accent ? Theme.accentInk : Theme.bg
    }
    private var shadow: Color {
        variant == .accent ? Theme.accent.opacity(0.35) : Theme.ink.opacity(0.25)
    }
}

#Preview("FAB — Light") {
    ZStack {
        Theme.bg.ignoresSafeArea()
        HStack(spacing: 20) {
            FAB(icon: "bubble.left.fill", variant: .accent) {}
            FAB(icon: "plus", variant: .ink) {}
        }
    }
    .preferredColorScheme(.light)
}

#Preview("FAB — Dark") {
    ZStack {
        Theme.bg.ignoresSafeArea()
        HStack(spacing: 20) {
            FAB(icon: "bubble.left.fill", variant: .accent) {}
            FAB(icon: "plus", variant: .ink) {}
        }
    }
    .preferredColorScheme(.dark)
}
