import SwiftUI

/// Three-up card picker for Appearance (System / Light / Dark).
/// Each option shows an icon + label, with a filled accent background when selected.
struct AppearancePicker: View {
    @Binding var selection: Appearance
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Appearance.allCases) { option in
                AppearanceOption(
                    option: option,
                    isSelected: selection == option
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selection = option
                    }
                }
            }
        }
    }
}

private struct AppearanceOption: View {
    let option: Appearance
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconBackground)
                        .frame(width: 46, height: 46)
                    Image(systemName: option.iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(iconForeground)
                        .symbolRenderingMode(.hierarchical)
                }
                Text(option.label)
                    .font(CoachFonts.ui(12, weight: .semibold))
                    .foregroundStyle(isSelected ? CoachColors.accent : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? CoachColors.accent : borderColor, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(
                color: isSelected ? CoachColors.accent.opacity(0.25) : .clear,
                radius: isSelected ? 8 : 0,
                y: isSelected ? 2 : 0
            )
            .scaleEffect(isSelected ? 1.0 : 0.97)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Colors

    private var iconBackground: LinearGradient {
        switch option {
        case .system:
            return LinearGradient(
                colors: [CoachColors.accent.opacity(0.9), CoachColors.purple.opacity(0.9)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .light:
            return LinearGradient(
                colors: [CoachColors.yellow, Color(hex: "FFD580")],
                startPoint: .top, endPoint: .bottom
            )
        case .dark:
            return LinearGradient(
                colors: [Color(hex: "2C2C3E"), Color(hex: "0B0B18")],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    private var iconForeground: Color {
        switch option {
        case .system: return .white
        case .light: return Color(hex: "8B5E14")
        case .dark: return Color(hex: "D8D8FF")
        }
    }

    private var backgroundFill: Color {
        if isSelected {
            return CoachColors.accent.opacity(colorScheme == .dark ? 0.18 : 0.10)
        }
        return colorScheme == .dark ? CoachColors.darkElevated : CoachColors.lightElevated
    }

    private var borderColor: Color {
        colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder
    }
}

private extension Appearance {
    var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}
