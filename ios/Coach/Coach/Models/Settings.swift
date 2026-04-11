import Foundation

struct PushMessage: Codable {
    var text: String
    var actions: [String]?
    var count: Int?
    var ts: String?
}

struct UserSettings: Codable {
    var personality: Personality
    var customPrompt: String
    var darkMode: Bool
    var pushMessage: PushMessage?

    enum CodingKeys: String, CodingKey {
        case personality
        case customPrompt = "custom_prompt"
        case darkMode = "dark_mode"
        case pushMessage = "push_message"
    }

    static func defaults() -> UserSettings {
        UserSettings(personality: .normal, customPrompt: "", darkMode: false)
    }
}
