import SwiftUI

// MARK: - Chat Completion Sheet

enum ChatCompletionSheet: Identifiable {
    case modified(session: PrescribedSession, weekNum: Int, dayIdx: Int, sessionIdx: Int)
    case swapped(session: PrescribedSession, weekNum: Int, dayIdx: Int, sessionIdx: Int)
    case skipped(weekNum: Int, dayIdx: Int, sessionIdx: Int)

    var id: String {
        switch self {
        case .modified(_, let w, let d, let s): return "modified-\(w)-\(d)-\(s)"
        case .swapped(_, let w, let d, let s): return "swapped-\(w)-\(d)-\(s)"
        case .skipped(let w, let d, let s): return "skipped-\(w)-\(d)-\(s)"
        }
    }
}

// MARK: - Conversation History View

/// Shows archived conversations with their summaries. Tapping opens
/// the transcript read-only.
struct ConversationHistoryView: View {
    @Environment(DataService.self) var data
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

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
                .padding()
            }
        }
        .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
        .navigationTitle("Past Conversations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func conversationRow(_ convo: Conversation) -> some View {
        CoachCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(formatConversationDate(convo.startedAt))
                    .font(CoachFonts.ui(12, weight: .semibold))
                    .foregroundStyle(CoachColors.accent)
                if let summary = convo.summary, !summary.isEmpty {
                    Text(summary)
                        .font(CoachFonts.ui(13))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No summary available")
                        .font(CoachFonts.ui(13))
                        .italic()
                        .foregroundStyle(.secondary)
                }
            }
        }
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
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                    MessageBubble(message: message)
                }
            }
            .padding()
        }
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

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    var onCompletion: ((CompletionAction) -> Void)?

    @Environment(\.colorScheme) var colorScheme

    private var hasRichContent: Bool {
        message.richContent != nil && !(message.richContent!.isEmpty)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == "user" { Spacer(minLength: 48) }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 8) {
                // Text bubble (skip if content is empty and we have rich content)
                if !message.content.isEmpty {
                    Text(renderedContent)
                        .font(CoachFonts.ui(14))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            message.role == "user"
                                ? CoachColors.accent
                                : (colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightElevated)
                        )
                        .foregroundStyle(message.role == "user" ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Rich content components
                if let components = message.richContent {
                    ForEach(components) { component in
                        RichComponentView(component: component, onCompletion: onCompletion)
                    }
                }

                // Side-effect indicators
                if let meta = message.metadata {
                    HStack(spacing: 6) {
                        if meta.logged == true {
                            Label("Logged", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(CoachColors.green)
                        }
                        if meta.planChanged == true {
                            Label("Plan updated", systemImage: "calendar.badge.checkmark")
                                .foregroundStyle(CoachColors.cyan)
                        }
                    }
                    .font(CoachFonts.ui(11))
                }
            }

            // Full-width for assistant messages with rich content
            if message.role == "assistant" && !hasRichContent { Spacer(minLength: 48) }
        }
    }

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
