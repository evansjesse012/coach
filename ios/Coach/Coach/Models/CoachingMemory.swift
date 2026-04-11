import Foundation

// MARK: - Schedule
struct Schedule: Codable {
    var availableDays: Int
    var preferredTimes: String
    var constraints: [String]

    static func empty() -> Schedule {
        Schedule(availableDays: 0, preferredTimes: "", constraints: [])
    }
}

// MARK: - Safety Rule
struct SafetyRule: Codable {
    var rule: String
    var reason: String
    var addedDate: String?
}

// MARK: - Permanent Memory
struct PermanentMemory: Codable {
    var equipment: [String]
    var facilities: [String]
    var schedule: Schedule
    var medicalHistory: [String]
    var dietaryConstraints: [String]
    var communicationPrefs: String
    var safetyRules: [SafetyRule]

    static func empty() -> PermanentMemory {
        PermanentMemory(
            equipment: [], facilities: [],
            schedule: .empty(),
            medicalHistory: [], dietaryConstraints: [],
            communicationPrefs: "",
            safetyRules: []
        )
    }
}

// MARK: - Benchmark
struct Benchmark: Codable {
    var metric: String
    var value: String
    var testDate: String?
    var method: String?
}

// MARK: - Injury History Entry
struct InjuryHistoryEntry: Codable {
    var date: String
    var note: String
}

// MARK: - Injury Record
struct InjuryRecord: Codable, Identifiable {
    var id: String
    var area: String
    var status: String      // active, monitoring, resolved
    var severity: String    // mild, moderate, severe
    var firstReported: String?
    var lastUpdated: String?
    var triggers: [String]
    var safeActivities: [String]
    var modifications: [String]
    var returnCriteria: String?
    var history: [InjuryHistoryEntry]
}

// MARK: - Observations
struct Observations: Codable {
    var patterns: [String]
    var motivators: [String]
    var consistency: String
    var currentFocus: String
    var openItems: [String]
    var coachingNotes: [String]

    static func empty() -> Observations {
        Observations(patterns: [], motivators: [], consistency: "", currentFocus: "", openItems: [], coachingNotes: [])
    }
}

// MARK: - Response Profile
struct ResponseProfile: Codable {
    var volumeVsIntensity: String
    var recoveryRate: String
    var easyDayDiscipline: String
    var sessionPreferences: String
    var skipPatterns: [String]
    var communicationNeeds: String

    static func empty() -> ResponseProfile {
        ResponseProfile(volumeVsIntensity: "", recoveryRate: "", easyDayDiscipline: "", sessionPreferences: "", skipPatterns: [], communicationNeeds: "")
    }
}

// MARK: - Conversation Summary
struct ConversationSummary: Codable {
    var date: String
    var summary: String
}

// MARK: - Coaching Memory (v2)
struct CoachingMemory: Codable {
    var permanent: PermanentMemory
    var benchmarks: [Benchmark]
    var injuries: [InjuryRecord]
    var observations: Observations
    var responseProfile: ResponseProfile
    var conversationSummaries: [ConversationSummary]
    var periodSummaries: [ConversationSummary]
    var lastUpdated: String

    enum CodingKeys: String, CodingKey {
        case permanent, benchmarks, injuries, observations
        case responseProfile = "response_profile"
        case conversationSummaries = "conversation_summaries"
        case periodSummaries = "period_summaries"
        case lastUpdated = "last_updated"
    }

    static func empty() -> CoachingMemory {
        CoachingMemory(
            permanent: .empty(),
            benchmarks: [],
            injuries: [],
            observations: .empty(),
            responseProfile: .empty(),
            conversationSummaries: [],
            periodSummaries: [],
            lastUpdated: ""
        )
    }
}
