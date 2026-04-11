import SwiftUI

/// Reusable card component matching the PWA's Card component.
struct CoachCard<Content: View>: View {
    var accentColor: Color?
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(padding)
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            if let accent = accentColor {
                RoundedRectangle(cornerRadius: 14)
                    .fill(accent)
                    .frame(width: 3)
                    .padding(.vertical, 8)
            }
        }
    }
}
