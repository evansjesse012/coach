import Foundation

struct PushMessage: Codable {
    var text: String
    var actions: [String]?
    var count: Int?
    var ts: String?
    var readiness: String?    // "green", "yellow", "red"
    var statusLine: String?   // One plain sentence framing the day
}

struct UserSettings: Codable {
    var personality: Personality
    var customPrompt: String
    var darkMode: Bool
    var appearance: Appearance?
    var pushMessage: PushMessage?

    enum CodingKeys: String, CodingKey {
        case personality
        case customPrompt = "custom_prompt"
        case darkMode = "dark_mode"
        case appearance
        case pushMessage = "push_message"
    }

    static func defaults() -> UserSettings {
        UserSettings(personality: .normal, customPrompt: "", darkMode: false, appearance: .system)
    }

    /// Effective appearance: prefers the explicit `appearance` field, falls
    /// back to the legacy `darkMode` bool for rows written before migration 004.
    var effectiveAppearance: Appearance {
        if let appearance { return appearance }
        return darkMode ? .dark : .system
    }
}
