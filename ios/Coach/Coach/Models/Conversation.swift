import Foundation

/// A distinct chat session between the athlete and coach. Each
/// conversation starts fresh, carries its own messages, and is archived
/// after a period of inactivity (currently 2 hours). On archival a
/// 1-2 sentence summary is generated so the coach has thread-to-thread
/// continuity without re-reading old transcripts.
struct Conversation: Codable, Identifiable {
    let id: String
    var startedAt: String
    var lastMessageAt: String
    var summary: String?
    var isArchived: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case startedAt = "started_at"
        case lastMessageAt = "last_message_at"
        case summary
        case isArchived = "is_archived"
    }

    static func create() -> Conversation {
        let now = ISO8601DateFormatter().string(from: Date())
        return Conversation(
            id: UUID().uuidString,
            startedAt: now,
            lastMessageAt: now,
            summary: nil,
            isArchived: false
        )
    }

    /// How many hours since the last message in this conversation.
    var hoursSinceLastMessage: Double {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: lastMessageAt) else { return 0 }
        return Date().timeIntervalSince(date) / 3600
    }

    /// True when the conversation has been inactive long enough to
    /// auto-close and start a fresh one.
    var isStale: Bool {
        hoursSinceLastMessage >= 2
    }
}

/// Minimal Anthropic response shape used by the conversation-summary
/// generator. Shared with other one-shot generators that parse the same
/// content-block structure.
struct SummaryResponse: Codable {
    let content: [SummaryBlock]
    struct SummaryBlock: Codable {
        let type: String
        let text: String?
    }
}
