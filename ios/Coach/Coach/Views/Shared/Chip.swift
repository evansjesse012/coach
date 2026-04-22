import SwiftUI

/// Compact tappable capsule, smaller than `Pill`.
/// - `default`: transparent, `line` border, `ink2` label.
/// - `done`: accent text, accent border, `accentSoft` background.
struct Chip: View {
    enum Variant { case `default`, done }

    let title: String
    var icon: String? = nil
    var variant: Variant = .default
    var action: (() -> Void)? = nil

    var body: some View {
        let content = HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(bg)
        .foregroundStyle(fg)
        .overlay(Capsule().strokeBorder(border, lineWidth: 1))
        .clipShape(Capsule())

        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var bg: Color {
        switch variant {
        case .default: return .clear
        case .done:    return Theme.accentSoft
        }
    }
    private var fg: Color {
        switch variant {
        case .default: return Theme.ink2
        case .done:    return Theme.accent
        }
    }
    private var border: Color {
        switch variant {
        case .default: return Theme.line
        case .done:    return Theme.accent.opacity(0.5)
        }
    }
}

#Preview("Chip — Light") {
    HStack(spacing: 8) {
        Chip(title: "Did it", variant: .done)
        Chip(title: "Modified")
        Chip(title: "Swapped")
        Chip(title: "Skipped")
    }
    .padding()
    .background(Theme.bg)
    .preferredColorScheme(.light)
}

#Preview("Chip — Dark") {
    HStack(spacing: 8) {
        Chip(title: "Did it", variant: .done)
        Chip(title: "Modified")
        Chip(title: "Swapped")
        Chip(title: "Skipped")
    }
    .padding()
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
