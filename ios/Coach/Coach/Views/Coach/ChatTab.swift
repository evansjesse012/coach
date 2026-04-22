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

// MARK: - Message renderer
//
// Two row shapes:
// - **Assistant**: no bubble. 2pt accent vertical rule on the left, mono
//   "COACH" kicker above the body, 15.5pt body with inline markdown, optional
//   rich-content blocks, optional tool-call receipt cards from metadata flags.
// - **User**: right-aligned bubble up to 82% width, `surface2` background with
//   `line` border and 18/18/4/18 corner radius.

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
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(Theme.accent)
                .frame(width: 2)
                .frame(maxHeight: .infinity, alignment: .top)

            VStack(alignment: .leading, spacing: 10) {
                Text(assistantKicker)
                    .font(Theme.Typography.monoLabel)
                    .foregroundStyle(Theme.ink3)
                    .textCase(.uppercase)
                    .tracking(Theme.Tracking.monoLabel)

                if !message.content.isEmpty {
                    Text(renderedContent)
                        .font(.system(size: 15.5, weight: .medium))
                        .foregroundStyle(contentForeground)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
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
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var contentForeground: Color {
        message.metadata?.isError == true ? Theme.warn : Theme.ink
    }

    private var assistantKicker: String {
        "Coach"
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
        Text(renderedContent)
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

    private var renderedContent: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let parsed = try? AttributedString(markdown: message.content, options: options) {
            return parsed
        }
        return AttributedString(message.content)
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
