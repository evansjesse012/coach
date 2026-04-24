import SwiftUI

/// Daily coach brief block.
/// Accent dot + mono uppercase kicker + source/time on top,
/// sans body message with optional highlighted phrases in the middle,
/// optional action pills below. The body collapses to `collapsedLines`
/// on first render and surfaces a "Read more / Show less" toggle only
/// when the full text is actually taller than the collapsed version.
struct CoachBrief: View {
    let kicker: String              // e.g. "Today's brief"
    let source: String              // e.g. "Coach"
    let time: String                // e.g. "6:12 AM"
    let message: AttributedString
    var actions: [BriefAction] = []
    /// Collapsed line count before "Read more" appears. Nil = always
    /// expanded (no truncation).
    var collapsedLines: Int? = 5

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

            if let limit = collapsedLines {
                ExpandableBriefText(message: message, collapsedLines: limit)
            } else {
                Text(message)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.ink)
                    .tracking(Theme.Tracking.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }

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

// MARK: - Expandable body

/// Body text with collapse/expand. Measures the rendered height (which
/// respects the current `lineLimit`) against the intrinsic height of
/// the same text rendered with no line limit, and only surfaces the
/// toggle when those two heights differ — so short briefs never show
/// a pointless "Read more" button.
private struct ExpandableBriefText: View {
    let message: AttributedString
    let collapsedLines: Int

    @State private var isExpanded = false
    @State private var isTruncatable = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.ink)
                .tracking(Theme.Tracking.headline)
                .lineSpacing(4)
                .lineLimit(isExpanded ? nil : collapsedLines)
                .fixedSize(horizontal: false, vertical: true)
                .background(truncationProbe)

            if isTruncatable {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Show less" : "Read more")
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: isExpanded ? "arrow.up" : "arrow.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// A hidden duplicate of the same text rendered with no line limit.
    /// Its intrinsic height is compared against the visible Text's
    /// rendered height; if the unlimited copy is taller, we know the
    /// visible copy truncated and the toggle should appear.
    private var truncationProbe: some View {
        GeometryReader { visible in
            Text(message)
                .font(Theme.Typography.body)
                .tracking(Theme.Tracking.headline)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .hidden()
                .background(
                    GeometryReader { full in
                        Color.clear.onAppear {
                            isTruncatable = full.size.height > visible.size.height + 1
                        }
                        .onChange(of: full.size.height) { _, newValue in
                            isTruncatable = newValue > visible.size.height + 1
                        }
                    }
                )
        }
    }
}

// MARK: - Highlight helper

extension AttributedString {
    /// Build a brief message with specific phrases wrapped in the accent-soft
    /// underline wash. Runs the text through `renderInlineMarkdown` first so
    /// `**bold**` / `*italic*` / `` `code` `` come out formatted instead of
    /// leaking the raw `**` markers to the UI — same shared helper the chat
    /// bubbles use.
    static func briefMessage(_ text: String, highlight phrases: [String] = []) -> AttributedString {
        var attr = renderInlineMarkdown(text)
        // Highlight phrases are matched against the post-parse rendered text,
        // not the original source — so a phrase like "Today is straightforward"
        // still matches even if it crosses a bold run in the original markdown.
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
