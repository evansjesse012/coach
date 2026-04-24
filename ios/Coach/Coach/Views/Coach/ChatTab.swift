import SwiftUI

// MARK: - Chat Completion Sheet

/// Legacy enum kept for backward compat with any completion-action handling
/// RichComponentView still emits. The new CoachTab does not open these
/// sheets directly; workout completion lives on the Home tab.
enum ChatCompletionSheet: Identifiable {
    case modified(session: PrescribedSession, weekNum: Int, dayIdx: Int, sessionIdx: Int)
    case swapped(session: PrescribedSession, weekNum: Int, dayIdx: Int, sessionIdx: Int)
    case skipped(weekNum: Int, dayIdx: Int, sessionIdx: Int)

    var id: String {
        switch self {
        case .modified(_, let w, let d, let s): return "modified-\(w)-\(d)-\(s)"
        case .swapped(_, let w, let d, let s):  return "swapped-\(w)-\(d)-\(s)"
        case .skipped(let w, let d, let s):     return "skipped-\(w)-\(d)-\(s)"
        }
    }
}

// MARK: - Conversation History View

/// Shows archived conversations with their summaries. Tapping opens
/// the transcript read-only.
struct ConversationHistoryView: View {
    @Environment(DataService.self) var data
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            if data.archivedConversations.isEmpty {
                ContentUnavailableView(
                    "No Past Conversations",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Your past conversations with the coach will appear here.")
                )
                .padding(.top, 60)
            } else {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(data.archivedConversations) { convo in
                        NavigationLink {
                            ArchivedConversationView(conversation: convo)
                        } label: {
                            conversationRow(convo)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Theme.Spacing.screenH)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .navigationTitle("Past Conversations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func conversationRow(_ convo: Conversation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formatConversationDate(convo.startedAt))
                .font(Theme.Typography.monoLabel)
                .foregroundStyle(Theme.accent)
                .textCase(.uppercase)
                .tracking(Theme.Tracking.monoLabel)
            if let summary = convo.summary, !summary.isEmpty {
                Text(summary)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No summary available")
                    .font(Theme.Typography.body)
                    .italic()
                    .foregroundStyle(Theme.ink3)
            }
        }
        .padding(Theme.Spacing.cardP)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    private func formatConversationDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return isoString }
        let display = DateFormatter()
        display.doesRelativeDateFormatting = true
        display.dateStyle = .medium
        display.timeStyle = .short
        return display.string(from: date)
    }
}

// MARK: - Archived Conversation View

/// Read-only transcript of an archived conversation.
struct ArchivedConversationView: View {
    let conversation: Conversation
    @Environment(DataService.self) var data

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                    MessageBubble(message: message)
                        .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
                }
            }
            .padding(.horizontal, Theme.Spacing.screenH)
            .padding(.vertical, 20)
        }
        .background(Theme.bg.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .navigationTitle(formattedDate)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var messages: [ChatMessage] {
        data.messagesForConversation(conversation.id)
    }

    private var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: conversation.startedAt) else { return "Conversation" }
        let display = DateFormatter()
        display.dateFormat = "MMM d, h:mm a"
        return display.string(from: date)
    }
}

// MARK: - Timestamp divider

/// Centered mono-uppercase date + time label inserted into the message
/// stream by CoachTab. Matches iMessage / WhatsApp convention — a divider
/// at the top of a conversation, after long gaps, and when the date changes.
struct ChatTimestampDivider: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Typography.monoLabelS)
            .foregroundStyle(Theme.ink3)
            .textCase(.uppercase)
            .tracking(Theme.Tracking.monoLabel)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
    }
}

/// Renders "TODAY · 7:14 AM" / "YESTERDAY · 8:02 PM" / "TUESDAY · 6:30 AM" /
/// "APR 14 · 7:45 AM" style labels. Uppercasing is applied at render time.
func chatDividerText(for date: Date) -> String {
    let cal = Calendar.current
    let timeFmt = DateFormatter()
    timeFmt.dateFormat = "h:mm a"
    let timeStr = timeFmt.string(from: date)

    if cal.isDateInToday(date)     { return "Today · \(timeStr)" }
    if cal.isDateInYesterday(date) { return "Yesterday · \(timeStr)" }

    let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: Date())).day ?? 0
    if days < 7 {
        let f = DateFormatter(); f.dateFormat = "EEEE"
        return "\(f.string(from: date)) · \(timeStr)"
    }
    let f = DateFormatter(); f.dateFormat = "MMM d"
    return "\(f.string(from: date)) · \(timeStr)"
}

// MARK: - Suggested replies row

/// Horizontal row of 2–3 tappable reply pills. Pre-fills the composer's
/// input text when tapped (does not auto-send). Scrolls if the content
/// exceeds the viewport width.
struct SuggestedRepliesRow: View {
    let replies: [String]
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(replies.enumerated()), id: \.offset) { _, reply in
                    Button {
                        onTap(reply)
                    } label: {
                        Text(reply)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Theme.surface1)
                            .foregroundStyle(Theme.ink)
                            .overlay(
                                Capsule().strokeBorder(Theme.line2, lineWidth: 1)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }
}

// MARK: - Message renderer
//
// Coach messages split on `\n\n` into sequential bubbles; only the first
// bubble shows the "COACH" label and each bubble is accented by the 2pt
// left rule. User messages render as a single right-aligned bubble. All
// per-message timestamps are removed — CoachTab inserts stream-level
// ChatTimestampDivider rows instead.

struct MessageBubble: View {
    let message: ChatMessage
    var onCompletion: ((CompletionAction) -> Void)?

    var body: some View {
        if message.role == "user" {
            userRow
        } else {
            assistantRow
        }
    }

    // MARK: Assistant

    private var assistantRow: some View {
        let beats = splitBeats(message.content)
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(beats.enumerated()), id: \.offset) { idx, beat in
                assistantBubble(beat, isFirst: idx == 0)
            }
            if let components = message.richContent, !components.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(components) { c in
                        RichComponentView(component: c, onCompletion: onCompletion)
                    }
                }
            }
            if let meta = message.metadata {
                toolReceipts(for: meta)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func assistantBubble(_ beat: String, isFirst: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if isFirst {
                Text("Coach")
                    .font(Theme.Typography.monoLabelS)
                    .foregroundStyle(Theme.ink3)
                    .textCase(.uppercase)
                    .tracking(Theme.Tracking.monoLabel)
            }
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity, alignment: .top)
                MarkdownView(
                    text: beat,
                    baseFont: .system(size: 15.5, weight: .medium),
                    textColor: contentForeground
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Splits a coach message on double newlines into sequential bubbles.
    /// Trims surrounding whitespace per beat. A message with no double-newlines
    /// returns a single-element array, preserving the old single-bubble feel.
    private func splitBeats(_ content: String) -> [String] {
        guard !content.isEmpty else { return [] }
        let beats = content
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return beats.isEmpty ? [content] : beats
    }

    private var contentForeground: Color {
        message.metadata?.isError == true ? Theme.warn : Theme.ink
    }

    @ViewBuilder
    private func toolReceipts(for meta: ChatMessageMetadata) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if meta.planChanged == true {
                ToolReceiptCard(kicker: "Plan updated", main: "Your training plan was updated")
            }
            if meta.logged == true {
                ToolReceiptCard(kicker: "Workout logged", main: "Recorded to your training log")
            }
            if meta.nutritionLogged == true {
                ToolReceiptCard(kicker: "Nutrition logged", main: "Entry added to today")
            }
        }
    }

    // MARK: User

    private var userRow: some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 6) {
                if !message.content.isEmpty {
                    userBubble
                }
                if let components = message.richContent, !components.isEmpty {
                    VStack(alignment: .trailing, spacing: 6) {
                        ForEach(components) { c in
                            RichComponentView(component: c, onCompletion: onCompletion)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity * 0.82, alignment: .trailing)
        }
    }

    private var userBubble: some View {
        Text(rendered(message.content))
            .font(.system(size: 14.5, weight: .medium))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 18,
                    bottomLeadingRadius: 18,
                    bottomTrailingRadius: 4,
                    topTrailingRadius: 18,
                    style: .continuous
                )
                .fill(Theme.surface2)
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 18,
                    bottomLeadingRadius: 18,
                    bottomTrailingRadius: 4,
                    topTrailingRadius: 18,
                    style: .continuous
                )
                .strokeBorder(Theme.line, lineWidth: 1)
            )
    }

    // MARK: Content rendering

    private func rendered(_ text: String) -> AttributedString {
        // Shared helper — see MarkdownView.swift for the quirk handling.
        renderInlineMarkdown(text)
    }
}

// MARK: - Tool receipt card

/// Dashed accent-bordered card with `accentSoft` fill. Shown under an
/// assistant message when metadata indicates a side effect (logged workout,
/// plan update, nutrition entry).
private struct ToolReceiptCard: View {
    let kicker: String
    let main: String
    var meta: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Theme.accent).frame(width: 24, height: 24)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.accentInk)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(kicker)
                    .font(Theme.Typography.monoLabel)
                    .foregroundStyle(Theme.accent)
                    .textCase(.uppercase)
                    .tracking(Theme.Tracking.monoLabel)
                Text(main)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let meta, !meta.isEmpty {
                    Text(meta)
                        .font(Theme.Typography.monoMeta)
                        .foregroundStyle(Theme.ink3)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    Theme.accent.opacity(0.5),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
        )
    }
}
