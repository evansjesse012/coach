import SwiftUI

/// Reusable collapsible card with animated chevron + fade transition.
/// Used by PlanReviewView (expandable phases) and PrescribedSessionDetailView
/// (coach notes, nutrition).
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
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
    }
}

/// Convenience initializer for the existing "icon + title" header pattern used
/// throughout PrescribedSessionDetailView.
extension CollapsibleCard where Header == _CollapsibleIconTitleHeader {
    init(
        icon: String,
        iconColor: Color,
        title: String,
        isExpanded: Bool,
        toggle: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isExpanded = isExpanded
        self.toggle = toggle
        self.header = {
            _CollapsibleIconTitleHeader(icon: icon, iconColor: iconColor, title: title)
        }
        self.content = content
    }
}

struct _CollapsibleIconTitleHeader: View {
    let icon: String
    let iconColor: Color
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(title)
                .font(CoachFonts.ui(13, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }
}
