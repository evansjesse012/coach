import SwiftUI

// MARK: - Pill / Badge

/// Legacy inline badge — not interactive. (See `Pill` in Pill.swift for the
/// new button-style pill.) API stable; colors forward to Theme so a given
/// `color` is used at both foreground and a soft tint background.
struct CoachPill: View {
    let text: String
    var color: Color = Theme.accent

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Sport Badge

struct SportBadge: View {
    let sport: Sport

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: sport.sfSymbol)
                .font(.system(size: 10, weight: .semibold))
            Text(sport.label)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(sport.swiftUIColor.opacity(0.15))
        .foregroundStyle(sport.swiftUIColor)
        .clipShape(Capsule())
    }
}

// MARK: - Section Label

/// Legacy section label. Rendered with the same mono-uppercase token style
/// as the new `SectionHeader(variant: .system)` so legacy screens align
/// typographically with the priority screens.
struct CoachLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Typography.monoLabel)
            .foregroundStyle(Theme.ink3)
            .textCase(.uppercase)
            .tracking(Theme.Tracking.monoLabel)
    }
}

// MARK: - Input Field

struct CoachInput: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        TextField(placeholder, text: $text)
            .font(Theme.Typography.body)
            .keyboardType(keyboardType)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )
    }
}

// MARK: - Dots Loader

struct DotsLoader: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 6, height: 6)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .opacity(animating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

// MARK: - Sheet Header

struct SheetHeader: View {
    let title: String
    var subtitle: String?
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.ink2)
                }
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .frame(width: 34, height: 34)
                    .background(Circle().strokeBorder(Theme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.screenH)
        .padding(.top, 14)
    }
}

// MARK: - Filter Dropdown Label

/// Compact capsule label used inside a `Menu` to show the current selection
/// for a dropdown filter. Tints accent when a non-default option is active.
/// Used by LogTab (Activities page) and ExerciseLibraryView.
struct FilterDropdown: View {
    let label: String
    let icon: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(.system(size: 13, weight: .medium))
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? Theme.accentSoft : Theme.surface2)
        .foregroundStyle(isActive ? Theme.accent : Theme.ink)
        .overlay(
            Capsule()
                .strokeBorder(isActive ? Theme.accent.opacity(0.4) : Theme.line, lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}
