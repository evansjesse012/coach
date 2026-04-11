import SwiftUI

/// Reusable button matching the PWA's Btn component.
struct CoachButton: View {
    let label: String
    var icon: String?
    var style: ButtonStyle = .primary
    var isDisabled: Bool = false
    let action: () -> Void

    enum ButtonStyle {
        case primary, outline, danger
    }

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(label)
                    .font(CoachFonts.ui(14, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: style == .primary ? .infinity : nil)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: style == .outline ? 1 : 0)
            )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return CoachColors.accent
        case .outline: return .clear
        case .danger: return CoachColors.red
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .danger: return .white
        case .outline: return colorScheme == .dark ? CoachColors.darkText : CoachColors.lightText
        }
    }

    private var borderColor: Color {
        colorScheme == .dark ? CoachColors.darkBorderBright : CoachColors.lightBorderBright
    }
}
