import Foundation

struct ChatMessageMetadata: Codable {
    var logged: Bool?
    var nutritionLogged: Bool?
    var planChanged: Bool?
    var appActionTaken: Bool?
    var isError: Bool?
}

struct ChatMessage: Codable, Identifiable {
    let id: Int?          // auto-incremented by Supabase, nil for local-only
    var role: String      // "user" | "assistant"
    var content: String
    var metadata: ChatMessageMetadata?

    enum CodingKeys: String, CodingKey {
        case id, role, content, metadata
    }

    static func user(_ content: String) -> ChatMessage {
        ChatMessage(id: nil, role: "user", content: content)
    }

    static func assistant(_ content: String, metadata: ChatMessageMetadata? = nil) -> ChatMessage {
        ChatMessage(id: nil, role: "assistant", content: content, metadata: metadata)
    }
}
