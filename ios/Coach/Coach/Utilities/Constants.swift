import SwiftUI

// MARK: - Legacy design-system bridge
//
// The new design system lives in `Theme` (Utilities/Theme.swift). These
// `CoachColors` and `CoachFonts` types predate it and are still referenced
// by the unmigrated screens (Log, Stats, Settings, Auth, Exercises, Strength,
// and the Plan/Goals sub-views). Rather than touch every one of those files,
// this module now forwards the legacy names to their new equivalents so a
// single token edit in Theme cascades through the whole app.
//
// Call-site pattern in legacy code:
//     colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg
// resolves to Theme.bg in both branches, since Theme colors are dynamic and
// auto-adapt via UITraitCollection. The ternary is redundant but harmless.

enum CoachColors {
    // Chrome — forwards to Theme
    static var lightBg:           Color { Theme.bg }
    static var darkBg:            Color { Theme.bg }
    static var lightSurface:      Color { Theme.surface1 }
    static var darkSurface:       Color { Theme.surface1 }
    static var lightCard:         Color { Theme.surface1 }
    static var darkCard:          Color { Theme.surface1 }
    static var lightElevated:     Color { Theme.surface2 }
    static var darkElevated:      Color { Theme.surface2 }
    static var lightBorder:       Color { Theme.line }
    static var darkBorder:        Color { Theme.line }
    static var lightBorderBright: Color { Theme.line2 }
    static var darkBorderBright:  Color { Theme.line2 }
    static var lightText:         Color { Theme.ink }
    static var darkText:          Color { Theme.ink }
    static var lightSubtle:       Color { Theme.ink2 }
    static var darkSubtle:        Color { Theme.ink2 }
    static var lightMuted:        Color { Theme.ink3 }
    static var darkMuted:         Color { Theme.ink3 }

    // Brand — was coral E8604C, now the olive brand accent.
    static var accent:            Color { Theme.accent }

    // Domain colors — effort categories and sports. These don't have clean
    // mappings in the new token set (the design system keeps brand accents
    // rare), so the legacy hex values are preserved for semantic distinction.
    // Bike/info-tinted and error-tinted callers forward to the design tokens.
    static let green  = Color(hex: "2ABF84")  // logged / completed / easy effort
    static let yellow = Color(hex: "F0A830")  // tempo / threshold effort
    static let purple = Color(hex: "8B6FE8")  // long-endurance / strength
    static var cyan:  Color { Theme.info }    // bike / info
    static var blue:  Color { Theme.info }    // strength (legacy) / info
    static var teal:  Color { Theme.info }
    static var red:   Color { Theme.warn }    // errors / vo2max / race effort
}

// MARK: - Effort Category Colors

extension TrainingPhase {
    var accentColor: Color {
        switch number {
        case 1: return CoachColors.green
        case 2: return CoachColors.accent
        case 3: return CoachColors.purple
        default: return CoachColors.cyan
        }
    }
}

extension EffortCategory {
    var color: Color {
        switch self {
        case .easy, .recovery: return CoachColors.green
        case .tempo, .threshold: return CoachColors.yellow
        case .longEndurance: return CoachColors.purple
        case .strength: return CoachColors.blue
        case .vo2max, .race: return CoachColors.red
        case .rest: return Theme.ink3
        }
    }

    /// Vertical gradient used for the left edge color bar on session cards.
    var gradient: LinearGradient {
        let stops: [Color]
        switch self {
        case .easy:
            stops = [CoachColors.green, CoachColors.yellow]
        case .recovery:
            stops = [CoachColors.green, CoachColors.cyan]
        case .tempo, .threshold:
            stops = [CoachColors.yellow, CoachColors.accent]
        case .longEndurance:
            stops = [CoachColors.purple, Color(hex: "E84CA0")]
        case .strength:
            stops = [CoachColors.blue, CoachColors.purple]
        case .vo2max, .race:
            stops = [CoachColors.accent, CoachColors.red]
        case .rest:
            stops = [Theme.ink3.opacity(0.5), Theme.ink3.opacity(0.3)]
        }
        return LinearGradient(colors: stops, startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Sport Colors

extension Sport {
    var swiftUIColor: Color {
        switch self {
        case .run:      return Theme.Discipline.run.color
        case .bike:     return Theme.Discipline.bike.color
        case .swim:     return Theme.Discipline.swim.color
        case .strength: return Theme.Discipline.strength.color
        case .brick:    return CoachColors.green
        case .hike:     return CoachColors.green
        case .other:    return Theme.ink3
        }
    }
}

// MARK: - Font helpers
//
// Legacy font helpers now forward to the Theme typography system.
// Display is sans (was rounded in the pre-redesign look); ui is plain sans;
// mono is the monospace system font.

enum CoachFonts {
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Color hex extension

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
