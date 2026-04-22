import SwiftUI

/// Section header rendered above a content block.
/// - `content`: sentence-case title (sans, 13pt, weight 600).
/// - `system`: mono uppercase title (10pt, `ink3`, wide tracking).
/// Meta is always mono uppercase tracked.
struct SectionHeader: View {
    enum Variant { case content, system }

    let title: String
    var meta: String? = nil
    var variant: Variant = .content

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            titleView
            Spacer(minLength: 8)
            if let meta {
                Text(meta)
                    .font(Theme.Typography.monoLabel)
                    .foregroundStyle(Theme.ink3)
                    .textCase(.uppercase)
                    .tracking(Theme.Tracking.monoLabel)
            }
        }
    }

    @ViewBuilder
    private var titleView: some View {
        switch variant {
        case .content:
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
        case .system:
            Text(title)
                .font(Theme.Typography.monoLabel)
                .foregroundStyle(Theme.ink3)
                .textCase(.uppercase)
                .tracking(Theme.Tracking.monoLabel)
        }
    }
}

#Preview("SectionHeader — Light") {
    VStack(alignment: .leading, spacing: 20) {
        SectionHeader(title: "This week", meta: "Wk 1 / 24")
        SectionHeader(title: "Today · Friday", meta: "1 of 1", variant: .system)
        SectionHeader(title: "Active", meta: "3 goals")
        SectionHeader(title: "Season plan", meta: "5 phases · 24 wks", variant: .system)
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background(Theme.bg)
    .preferredColorScheme(.light)
}

#Preview("SectionHeader — Dark") {
    VStack(alignment: .leading, spacing: 20) {
        SectionHeader(title: "This week", meta: "Wk 1 / 24")
        SectionHeader(title: "Today · Friday", meta: "1 of 1", variant: .system)
        SectionHeader(title: "Active", meta: "3 goals")
        SectionHeader(title: "Season plan", meta: "5 phases · 24 wks", variant: .system)
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
