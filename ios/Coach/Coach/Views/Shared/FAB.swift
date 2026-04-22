import SwiftUI

/// Floating action button — 48×50 accent pill, accent-ink icon,
/// accent-tinted shadow. Positioned by the caller; the component itself
/// is just the button.
struct FAB: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.accentInk)
                .frame(width: 48, height: 50)
                .background(Theme.accent)
                .clipShape(Capsule())
                .shadow(color: Theme.accent.opacity(0.35), radius: 16, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

#Preview("FAB — Light") {
    ZStack {
        Theme.bg.ignoresSafeArea()
        FAB(icon: "bubble.left.fill") {}
    }
    .preferredColorScheme(.light)
}

#Preview("FAB — Dark") {
    ZStack {
        Theme.bg.ignoresSafeArea()
        FAB(icon: "bubble.left.fill") {}
    }
    .preferredColorScheme(.dark)
}
