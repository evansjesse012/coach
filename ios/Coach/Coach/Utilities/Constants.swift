import SwiftUI

// MARK: - Design System
// Port of theme system from page.jsx lines 22-49

enum CoachColors {
    // Light theme
    static let lightBg = Color(hex: "F5F4F0")
    static let lightSurface = Color.white
    static let lightCard = Color.white
    static let lightElevated = Color(hex: "F0EFF8")
    static let lightBorder = Color(hex: "E8E7F0")
    static let lightBorderBright = Color(hex: "C8C7DC")
    static let lightText = Color(hex: "1C1B2E")
    static let lightSubtle = Color(hex: "5C5B78")
    static let lightMuted = Color(hex: "A0A0BC")

    // Dark theme
    static let darkBg = Color(hex: "07070E")
    static let darkSurface = Color(hex: "0E0E1A")
    static let darkCard = Color(hex: "121222")
    static let darkElevated = Color(hex: "1A1A2C")
    static let darkBorder = Color(hex: "222236")
    static let darkBorderBright = Color(hex: "363658")
    static let darkText = Color(hex: "EEEEF8")
    static let darkSubtle = Color(hex: "9898BE")
    static let darkMuted = Color(hex: "565678")

    // Shared accent colors
    static let accent = Color(hex: "E8604C")
    static let green = Color(hex: "2ABF84")
    static let cyan = Color(hex: "2BAFC4")
    static let yellow = Color(hex: "F0A830")
    static let purple = Color(hex: "8B6FE8")
    static let red = Color(hex: "CC1111")
    static let blue = Color(hex: "4A8FE8")
    static let teal = Color(hex: "2BAFC4")
}

// MARK: - Effort Category Colors

extension EffortCategory {
    var color: Color {
        switch self {
        case .easy, .recovery: return CoachColors.green
        case .tempo, .threshold: return CoachColors.yellow
        case .longEndurance: return CoachColors.purple
        case .strength: return CoachColors.blue
        case .vo2max, .race: return CoachColors.red
        case .rest: return Color.gray
        }
    }
}

// MARK: - Sport Colors

extension Sport {
    var swiftUIColor: Color {
        switch self {
        case .run: return CoachColors.accent
        case .bike: return CoachColors.cyan
        case .swim: return CoachColors.purple
        case .strength: return CoachColors.yellow
        case .brick: return CoachColors.green
        case .hike: return CoachColors.green
        case .other: return Color.gray
        }
    }
}

// MARK: - Font Helpers

enum CoachFonts {
    // Custom fonts — register in Info.plist after adding .ttf files
    // For now, use system fonts as fallbacks
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        // TODO: Replace with .custom("Outfit", size: size) after bundling font
        .system(size: size, weight: weight, design: .rounded)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // TODO: Replace with .custom("DMSans", size: size) after bundling font
        .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // TODO: Replace with .custom("JetBrainsMono", size: size) after bundling font
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
