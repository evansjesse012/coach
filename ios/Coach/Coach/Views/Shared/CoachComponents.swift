import SwiftUI

// MARK: - Pill / Badge

struct CoachPill: View {
    let text: String
    var color: Color = CoachColors.accent

    var body: some View {
        Text(text)
            .font(CoachFonts.ui(11, weight: .semibold))
            .padding(.horizontal, 8)
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
        HStack(spacing: 4) {
            Image(systemName: sport.sfSymbol)
                .font(.system(size: 10, weight: .semibold))
            Text(sport.label)
                .font(CoachFonts.ui(11, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(sport.swiftUIColor.opacity(0.15))
        .foregroundStyle(sport.swiftUIColor)
        .clipShape(Capsule())
    }
}

// MARK: - Section Label

struct CoachLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(CoachFonts.ui(11, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
    }
}

// MARK: - Input Field

struct CoachInput: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        TextField(placeholder, text: $text)
            .font(CoachFonts.ui(15))
            .keyboardType(keyboardType)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(colorScheme == .dark ? CoachColors.darkElevated : CoachColors.lightElevated)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
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
                    .fill(CoachColors.accent)
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
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CoachFonts.display(20, weight: .bold))
                if let subtitle {
                    Text(subtitle)
                        .font(CoachFonts.ui(13))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top)
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
                .font(CoachFonts.ui(13, weight: .medium))
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? CoachColors.accent.opacity(0.15) : Color(.secondarySystemBackground))
        .foregroundStyle(isActive ? CoachColors.accent : .primary)
        .clipShape(Capsule())
    }
}
