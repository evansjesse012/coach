import SwiftUI

/// Reusable collapsible card with animated chevron + fade transition.
struct CollapsibleCard<Header: View, Content: View>: View {
    let isExpanded: Bool
    let toggle: () -> Void
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    header()
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        // Lock the card to its parent's proposed width. Without this, an
        // expanded `content()` whose children have wide intrinsic ideal
        // widths (e.g. an HStack of three `Text`s with `.fixedSize(horizontal:
        // false, vertical: true)` and long single-line content) propagates
        // its ideal width up through this VStack, makes the whole card wider
        // than the screen, and lets the parent ScrollView pan horizontally.
        // Forcing the VStack to its parent's proposal means children get a
        // finite width and the inner Texts actually wrap.
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }
}

/// Convenience initializer for the "icon + title" header pattern.
extension CollapsibleCard where Header == _CollapsibleIconTitleHeader {
    init(
        icon: String,
        iconColor: Color,
        title: String,
        isExpanded: Bool,
        toggle: @escaping () -> Void,
        accessoryIcon: String? = nil,
        accessoryColor: Color = CoachColors.yellow,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isExpanded = isExpanded
        self.toggle = toggle
        self.header = {
            _CollapsibleIconTitleHeader(
                icon: icon,
                iconColor: iconColor,
                title: title,
                accessoryIcon: accessoryIcon,
                accessoryColor: accessoryColor
            )
        }
        self.content = content
    }
}

struct _CollapsibleIconTitleHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    var accessoryIcon: String? = nil
    var accessoryColor: Color = CoachColors.yellow

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(title)
                .font(CoachFonts.ui(13, weight: .semibold))
                .foregroundStyle(.primary)
            if let accessoryIcon {
                Image(systemName: accessoryIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accessoryColor)
            }
        }
    }
}
