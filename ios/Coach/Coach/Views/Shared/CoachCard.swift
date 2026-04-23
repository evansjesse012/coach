import SwiftUI

/// Legacy card primitive. API stable across the migration — now rendered
/// with the new design system's card styling (18pt radius, `surface1` fill,
/// `line` border, subtle mode-aware shadow) so every consumer inherits the
/// new look without edits.
struct CoachCard<Content: View>: View {
    var accentColor: Color?
    var padding: CGFloat = Theme.Spacing.cardP
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            if let accent = accentColor {
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(accent)
                    .frame(width: 3)
                    .padding(.vertical, 8)
            }
        }
        .dsCardShadow()
    }
}
