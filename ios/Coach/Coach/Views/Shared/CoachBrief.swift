import SwiftUI

/// Daily coach brief block.
/// Accent dot + mono uppercase kicker + source/time on top,
/// sans body message with optional highlighted phrases in the middle,
/// optional action pills below.
struct CoachBrief: View {
    let kicker: String              // e.g. "Today's brief"
    let source: String              // e.g. "Coach"
    let time: String                // e.g. "6:12 AM"
    let message: AttributedString
    var actions: [BriefAction] = []

    struct BriefAction: Identifiable {
        let id = UUID()
        let title: String
        let variant: Pill.Variant
        let action: () -> Void
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 7, height: 7)
                    Text(kicker)
                        .font(Theme.Typography.monoLabel)
                        .foregroundStyle(Theme.ink)
                        .textCase(.uppercase)
                        .tracking(Theme.Tracking.monoLabel)
                }

                Spacer(minLength: 8)

                Text("\(source) · \(time)")
                    .font(Theme.Typography.monoMeta)
                    .foregroundStyle(Theme.ink3)
            }

            Text(message)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.ink)
                .tracking(Theme.Tracking.headline)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)

            if !actions.isEmpty {
                HStack(spacing: 10) {
                    ForEach(actions) { a in
                        Pill(title: a.title, variant: a.variant, action: a.action)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - Highlight helper

extension AttributedString {
    /// Build a brief message with specific phrases wrapped in the accent-soft underline wash.
    static func briefMessage(_ text: String, highlight phrases: [String] = []) -> AttributedString {
        var attr = AttributedString(text)
        for phrase in phrases {
            if let r = attr.range(of: phrase) {
                attr[r].backgroundColor = Theme.accentSoft
            }
        }
        return attr
    }
}

#Preview("CoachBrief — Light") {
    CoachBrief(
        kicker: "Today's brief",
        source: "Coach",
        time: "6:12 AM",
        message: .briefMessage(
            "Yesterday's swim got done — that's your one confirmed tick this week. Today isn't about fitness, it's about wiring the cadence that keeps your legs alive at mile 8 of the run.",
            highlight: ["wiring the cadence"]
        ),
        actions: [
            .init(title: "Open today's session", variant: .primary) {},
            .init(title: "Talk to coach", variant: .secondary) {},
        ]
    )
    .padding(Theme.Spacing.screenH)
    .background(Theme.bg)
    .preferredColorScheme(.light)
}

#Preview("CoachBrief — Dark") {
    CoachBrief(
        kicker: "Today's brief",
        source: "Coach",
        time: "6:12 AM",
        message: .briefMessage(
            "Yesterday's swim got done — that's your one confirmed tick this week. Today isn't about fitness, it's about wiring the cadence that keeps your legs alive at mile 8 of the run.",
            highlight: ["wiring the cadence"]
        ),
        actions: [
            .init(title: "Open today's session", variant: .primary) {},
            .init(title: "Talk to coach", variant: .secondary) {},
        ]
    )
    .padding(Theme.Spacing.screenH)
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
