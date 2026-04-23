import SwiftUI
import UIKit

// MARK: - Design System
//
// Tokens and typography helpers for the Coach redesign.
// Coexists with the legacy `CoachColors` / `CoachFonts` in `Constants.swift`
// during migration. Phase 3 retires the legacy types.

enum Theme {

    // MARK: Colors

    static let bg         = dyn(l: "EFEDE6", d: "15161A")
    static let surface1   = dyn(l: "FFFFFF", d: "1D1F24")
    static let surface2   = dyn(l: "E5E2D9", d: "272A31")
    static let line       = dyn(l: "D8D4C8", d: "2E3138")
    static let line2      = dyn(l: "BFBAAB", d: "3B3F47")
    static let ink        = dyn(l: "15171B", d: "ECEAE0")
    static let ink2       = dyn(l: "50535B", d: "B0AEA3")
    static let ink3       = dyn(l: "8B8C90", d: "74726A")
    static let accent     = dyn(l: "5C7A12", d: "8DB347")
    static let accentDark = dyn(l: "41560C", d: "6F9434")
    static let accentSoft = dyn(l: "E8EFCE", d: "1C2A14")
    static let accentInk  = dyn(l: "FFFFFF", d: "15161A")
    static let warn       = dyn(l: "C73320", d: "FF6A5C")
    static let warnBg     = dyn(l: "FBE8E4", d: "2C1611")
    static let info       = dyn(l: "2C5DC7", d: "7CB0FF")

    // Status fills for modified / swapped sessions. Amber family, not a
    // core brand color — lives here because the canonical status palette
    // requires it. Dark variant approximates `rgba(232,179,71,0.18)` over
    // the `bg` token.
    static let modifiedSoft   = dyn(l: "FAEEDA", d: "3B3222")
    static let modifiedAccent = dyn(l: "B07820", d: "E8B347")

    /// Dark emphasis fill used for the "today" cell in the Home week grid.
    /// Near-black in both modes so today pops off the tinted canonical
    /// surfaces (accentSoft, modifiedSoft, etc.) without swapping sides
    /// when the appearance changes.
    static let todayEmphFill  = dyn(l: "15171B", d: "0B0C10")

    // MARK: Session status — canonical presentation

    /// The five session states every surface in the app renders the
    /// same way: fill / border / tint / icon / label. This is the
    /// single source of truth — no screen hand-rolls its own status
    /// colors. `pending` has no border (neutral surface); `done`,
    /// `modified`, `swapped`, and `skipped` each have a 1pt border
    /// in their accent color. `modified` and `swapped` share the
    /// amber family (compact displays like week strips and list rows
    /// collapse them into one visual treatment; Session Detail and
    /// quick-log distinguish them).
    enum SessionStatusKind: Hashable {
        case pending, done, modified, swapped, skipped

        var label: String {
            switch self {
            case .pending:  return "Not yet"
            case .done:     return "Done"
            case .modified: return "Modified"
            case .swapped:  return "Swapped"
            case .skipped:  return "Skipped"
            }
        }

        var icon: String {
            switch self {
            case .pending:  return "circle"
            case .done:     return "checkmark.circle.fill"
            case .modified: return "pencil.circle.fill"
            case .swapped:  return "arrow.triangle.2.circlepath.circle.fill"
            case .skipped:  return "xmark.circle.fill"
            }
        }

        /// Background fill for the status indicator.
        var fill: Color {
            switch self {
            case .pending:  return Theme.surface2
            case .done:     return Theme.accentSoft
            case .modified, .swapped: return Theme.modifiedSoft
            case .skipped:  return Theme.warnBg
            }
        }

        /// 1pt border color. `nil` for `pending` (no border).
        var border: Color? {
            switch self {
            case .pending:  return nil
            case .done:     return Theme.accent
            case .modified, .swapped: return Theme.modifiedAccent
            case .skipped:  return Theme.warn
            }
        }

        /// Foreground tint for the status icon and label text.
        var tint: Color {
            switch self {
            case .pending:  return Theme.ink3
            case .done:     return Theme.accent
            case .modified, .swapped: return Theme.modifiedAccent
            case .skipped:  return Theme.warn
            }
        }
    }

    // MARK: Discipline

    enum Discipline: String, CaseIterable, Hashable {
        case swim, bike, run, strength, recovery

        var color: Color {
            switch self {
            case .swim:     return Theme.dyn(l: "6E9CFF", d: "6E9CFF")
            case .bike:     return Theme.info
            case .run:      return Theme.accent
            case .strength: return Theme.dyn(l: "C77DD9", d: "C77DD9")
            case .recovery: return Theme.dyn(l: "B89968", d: "B89968")
            }
        }

        /// Default SF Symbol for the discipline; callers may override.
        var icon: String {
            switch self {
            case .swim:     return "figure.pool.swim"
            case .bike:     return "bicycle"
            case .run:      return "figure.run"
            case .strength: return "dumbbell.fill"
            case .recovery: return "leaf.fill"
            }
        }

        /// Display name for mono-uppercase discipline tags.
        var label: String {
            switch self {
            case .swim:     return "SWIM"
            case .bike:     return "BIKE"
            case .run:      return "RUN"
            case .strength: return "STRENGTH"
            case .recovery: return "RECOVERY"
            }
        }
    }

    // MARK: Typography
    //
    // Sans: system SF Pro.
    // Serif: system New York via `.serif` design — ONLY for race names and countdown numbers.
    // Mono: SF Mono for data, dates, durations, and system labels.

    enum Typography {
        // Sans
        static let pageTitle     = Font.system(size: 24, weight: .semibold)
        static let cardTitle     = Font.system(size: 14, weight: .semibold)
        static let sessionTitle  = Font.system(size: 18, weight: .semibold)
        static let body          = Font.system(size: 15, weight: .medium)
        static let bodyS         = Font.system(size: 14, weight: .medium)
        static let small         = Font.system(size: 11, weight: .regular)

        // Mono
        static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
        static let monoLabel  = mono(10, weight: .medium)
        static let monoLabelS = mono(9,  weight: .medium)
        static let monoData   = mono(13, weight: .regular)
        static let monoMeta   = mono(11, weight: .regular)

        // Serif (restricted)
        static let serifRace    = Font.system(size: 22, weight: .medium, design: .serif)
        static func serifNumber(_ size: CGFloat = 72) -> Font {
            .system(size: size, weight: .regular, design: .serif)
        }
    }

    // MARK: Tracking (letter-spacing, absolute pt)

    enum Tracking {
        static let headline: CGFloat       = -0.3   // ~-0.02em on 15pt
        static let monoLabel: CGFloat      = 1.6    // ~0.16em on 10pt
        static let monoLabelTight: CGFloat = 1.2
    }

    // MARK: Spacing

    enum Spacing {
        static let screenH: CGFloat       = 22
        static let cardP: CGFloat         = 16
        static let section: CGFloat       = 24

        /// Bottom padding added to each tab's scroll content so it clears
        /// the anchored `TabBar` on every device. `safeAreaInset` mounts
        /// the bar at the MainTabView level, but its safe-area reservation
        /// doesn't reliably propagate through ZStack → NavigationStack →
        /// ScrollView, so scroll content needs its own padding budget.
        /// 90pt covers the 56pt tab row + 34pt home-indicator inset on
        /// notched devices; renders as a bit of extra whitespace below
        /// content on iPhone SE (no home indicator).
        static let bottomReserve: CGFloat = 90
    }

    // MARK: Radius

    enum Radius {
        static let card: CGFloat   = 18
        static let pill: CGFloat   = 100
        static let badge: CGFloat  = 7
        static let chip: CGFloat   = 100
    }
}

// MARK: - Private helpers

private extension Theme {
    static func dyn(l: String, d: String) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(rgbHex: d)
                : UIColor(rgbHex: l)
        })
    }
}

private extension UIColor {
    convenience init(rgbHex: String) {
        let s = rgbHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = CGFloat((v >> 16) & 0xFF) / 255
        let g = CGFloat((v >> 8) & 0xFF) / 255
        let b = CGFloat(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - View modifiers & helpers

extension View {
    /// Card shadow matching the design system (mode-aware, two-layer).
    func dsCardShadow() -> some View { modifier(DSCardShadow()) }

    /// Ensures scrollable content ends cleanly above the app's anchored
    /// tab bar on every screen — tab roots AND anything pushed from a
    /// tab's NavigationStack. Wraps `contentMargins(.bottom:for: .scrollContent)`
    /// sized at `Theme.Spacing.bottomReserve` so the scroll view's bottom
    /// content region is inset by one constant value. Applied once per
    /// ScrollView, any new screen added under the tab bar just adds this
    /// modifier — no custom padding math, no per-screen drift.
    ///
    /// Do NOT apply to ScrollViews inside a `.sheet` or `.fullScreenCover`:
    /// those presentations cover the tab bar, so the reserve would only
    /// manifest as unnecessary bottom whitespace.
    func clearsTabBar() -> some View {
        contentMargins(.bottom, Theme.Spacing.bottomReserve, for: .scrollContent)
    }
}

private struct DSCardShadow: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        if scheme == .dark {
            content
                .shadow(color: .black.opacity(0.40), radius: 0,  x: 0, y: 1)
                .shadow(color: .black.opacity(0.35), radius: 32, x: 0, y: 12)
        } else {
            let ink = Color(red: 20/255, green: 22/255, blue: 25/255)
            content
                .shadow(color: ink.opacity(0.04), radius: 0,  x: 0, y: 1)
                .shadow(color: ink.opacity(0.06), radius: 24, x: 0, y: 8)
        }
    }
}

// MARK: - Hairline

/// 1pt horizontal divider using `Theme.line`.
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Theme.line)
            .frame(height: 1)
    }
}
