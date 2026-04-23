import SwiftUI

/// Legacy button primitive. API stable across the migration — now rendered
/// as a fully-rounded pill (matching the new design system's `Pill` shape)
/// using Theme tokens, so every consumer inherits the new look.
struct CoachButton: View {
    let label: String
    var icon: String?
    var style: ButtonStyle = .primary
    var isDisabled: Bool = false
    let action: () -> Void

    enum ButtonStyle {
        case primary, outline, danger
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: weight))
                }
                Text(label)
                    .font(.system(size: 14, weight: weight))
                    .tracking(Theme.Tracking.headline)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(maxWidth: style == .primary ? .infinity : nil)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .overlay(Capsule().strokeBorder(borderColor, lineWidth: style == .outline ? 1 : 0))
            .clipShape(Capsule())
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }

    private var weight: Font.Weight {
        style == .primary ? .semibold : .medium
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return Theme.accent
        case .outline: return .clear
        case .danger:  return Theme.warn
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return Theme.accentInk
        case .outline: return Theme.ink
        case .danger:  return .white
        }
    }

    private var borderColor: Color {
        style == .outline ? Theme.line2 : .clear
    }
}
