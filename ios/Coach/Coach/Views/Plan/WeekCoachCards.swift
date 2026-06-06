import SwiftUI

// Collapsible "coach note" cards for the week-detail page — a preview of the
// week ahead and a review of the week just gone. Both share the same chrome
// (CoachNoteCard) and differ only in accent, icon, kicker, and detail body.
// They render the real WeeklyPreview / WeeklyReview artifacts.

// MARK: - Preview card

struct WeekPreviewCard: View {
    let preview: WeeklyPreview

    // Preview defaults to collapsed in every page state (spec §2).
    @State private var expanded = false

    var body: some View {
        CoachNoteCard(
            stripeColor: Theme.coach,
            icon: "\u{1F4CB}",                 // 📋
            kicker: kicker,
            theme: preview.theme,
            expanded: $expanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if !preview.renderedProse.isEmpty {
                    Text(preview.renderedProse)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.ink2)
                        .lineSpacing(5)        // ~1.55 line-height on 13.5pt
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let q = preview.closingQuestion, !q.isEmpty {
                    Text(q)
                        .font(.system(size: 13.5).italic())
                        .foregroundStyle(Theme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var kicker: Text {
        Text("WEEK PREVIEW")
            .font(Theme.Typography.monoLabelS)
            .foregroundColor(Theme.coach)
    }
}

// MARK: - Review card

struct WeekReviewCard: View {
    let review: WeeklyReview

    // Review defaults to expanded on a complete week (spec §2).
    @State private var expanded = true

    var body: some View {
        CoachNoteCard(
            stripeColor: Theme.accent,
            icon: "\u{2713}",                  // ✓
            kicker: kicker,
            theme: summaryLine,
            expanded: $expanded
        ) {
            VStack(alignment: .leading, spacing: 0) {
                if let prose = review.aiResponseText, !prose.isEmpty {
                    Text(prose)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.ink2)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !carryForward.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle().fill(Theme.line).frame(height: 1)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CARRY FORWARD")
                                .font(Theme.Typography.monoLabelS)
                                .tracking(1.0)
                                .foregroundStyle(Theme.ink3)
                            ForEach(carryForward, id: \.self) { item in
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("\u{2192}")           // →
                                        .foregroundStyle(Theme.accent)
                                    Text(item)
                                        .font(.system(size: 13.5))
                                        .foregroundStyle(Theme.ink2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.top, 12)
                    }
                    .padding(.top, 12)
                }
            }
        }
    }

    private var kicker: Text {
        let base = Text("WEEK REVIEW ")
            .font(Theme.Typography.monoLabelS)
            .foregroundColor(Theme.accent)
        let date = loggedDateText
        guard !date.isEmpty else { return base }
        return base + Text("\u{00B7} logged \(date)")
            .font(Theme.Typography.monoLabelS)
            .foregroundColor(Theme.ink3)
    }

    /// 1–3 line summary shown collapsed: the AI's week assessment, falling
    /// back to the first sentence of the response prose.
    private var summaryLine: String {
        if let a = review.aiResponseComponents.weekAssessment, !a.isEmpty { return a }
        if let t = review.aiResponseText, !t.isEmpty { return firstSentence(t) }
        return "Week complete."
    }

    /// Up to three "carry forward" bullets, drawn from the bridge-to-next-week
    /// note, the athlete's next-week focus, and any detected patterns.
    private var carryForward: [String] {
        var items: [String] = []
        if let b = review.aiResponseComponents.bridgeToNextWeek,
           !b.trimmingCharacters(in: .whitespaces).isEmpty { items.append(b) }
        if let n = review.nextWeekFocus,
           !n.trimmingCharacters(in: .whitespaces).isEmpty { items.append(n) }
        items.append(contentsOf: review.patternsDetected)
        return Array(items.prefix(3))
    }

    private var loggedDateText: String {
        guard let iso = review.completedAt else { return "" }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        guard let date = withFraction.date(from: iso) ?? plain.date(from: iso) else { return "" }
        let out = DateFormatter()
        out.dateFormat = "MMM d"
        return out.string(from: date)
    }

    private func firstSentence(_ s: String) -> String {
        if let r = s.range(of: ". ") { return String(s[..<r.lowerBound]) + "." }
        return s
    }
}

// MARK: - Shared chrome

/// Collapsible card: a tappable head row (icon · kicker + theme · chevron)
/// over an animated, indented detail body. The whole head row is the hit
/// target; the chevron rotates 180° on expand.
private struct CoachNoteCard<Detail: View>: View {
    let stripeColor: Color
    let icon: String
    let kicker: Text
    let theme: String
    @Binding var expanded: Bool
    @ViewBuilder var detail: () -> Detail

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.28)) { expanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Text(icon)
                        .font(.system(size: 14))
                        .frame(width: 30, height: 30)
                        .background(Theme.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 3) {
                        kicker.tracking(1.0)   // ~0.1em on 10pt
                        Text(theme)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .padding(.top, 6)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                detail()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Align the detail under the head's body column
                    // (14 card pad + 30 icon + 12 gap).
                    .padding(.leading, 56)
                    .padding(.trailing, 14)
                    .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface1)
        .overlay(alignment: .leading) {
            Rectangle().fill(stripeColor).frame(width: 3)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .dsCardShadow()
    }
}
