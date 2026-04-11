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

    // Voice & Messaging
    var voiceOutputEnabled: Bool
    var phoneNumber: String
    var smsEnabled: Bool
    var callsEnabled: Bool
    var scheduledCheckIns: [ScheduledCheckIn]?

    enum CodingKeys: String, CodingKey {
        case personality
        case customPrompt = "custom_prompt"
        case darkMode = "dark_mode"
        case pushMessage = "push_message"
        case voiceOutputEnabled = "voice_output_enabled"
        case phoneNumber = "phone_number"
        case smsEnabled = "sms_enabled"
        case callsEnabled = "calls_enabled"
        case scheduledCheckIns = "scheduled_check_ins"
    }

    static func defaults() -> UserSettings {
        UserSettings(
            personality: .normal,
            customPrompt: "",
            darkMode: false,
            voiceOutputEnabled: false,
            phoneNumber: "",
            smsEnabled: false,
            callsEnabled: false
        )
    }
}

// MARK: - Scheduled Check-In

struct ScheduledCheckIn: Codable, Identifiable {
    var id: String
    var type: String        // CheckInType rawValue
    var time: String        // HH:mm format
    var enabled: Bool
    var channel: String     // "sms", "push", or "call"

    static func create(type: CheckInType, time: String, channel: MessagingChannel) -> ScheduledCheckIn {
        ScheduledCheckIn(
            id: UUID().uuidString,
            type: type.rawValue,
            time: time,
            enabled: true,
            channel: channel.rawValue
        )
    }
}
