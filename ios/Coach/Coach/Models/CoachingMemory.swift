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

// MARK: - Coaching Notes (hidden internal scratchpad)

/// A single entry in the AI's hidden coaching scratchpad. Stored inside
/// `Observations.coachingNotes`. The athlete never sees these directly —
/// they exist so the AI can track concerns, hypotheses, and patterns
/// across weeks and feed them forward into briefs / previews / pattern
/// detection.
///
/// Per Decision #6 in `Coach/Prompts/DECISIONS.md`: pattern threshold
/// for memorization is 3 observations of the same behavior before it
/// becomes a tracked note. Single occurrences shouldn't show up here.
struct CoachingNoteEntry: Codable, Hashable, Identifiable {
    let id: String
    var text: String
    var createdAt: String              // ISO8601
    var status: NoteStatus
    var relatedTopic: String?          // freeform tag — "tuesday_pace_drift", "right_knee", etc.
    var lastReviewedAt: String?        // when the AI last considered this note

    enum NoteStatus: String, Codable {
        case tracking
        case resolved
    }

    enum CodingKeys: String, CodingKey {
        case id, text, status
        case createdAt      = "created_at"
        case relatedTopic   = "related_topic"
        case lastReviewedAt = "last_reviewed_at"
    }

    static func newTracking(text: String, relatedTopic: String? = nil) -> CoachingNoteEntry {
        CoachingNoteEntry(
            id: UUID().uuidString,
            text: text,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            status: .tracking,
            relatedTopic: relatedTopic,
            lastReviewedAt: nil
        )
    }

    /// Wraps a legacy string note as a tracking entry with no metadata.
    /// `createdAt` is the upgrade moment, not the original write time —
    /// we don't have the latter.
    static func upgradeLegacy(_ text: String) -> CoachingNoteEntry {
        CoachingNoteEntry(
            id: UUID().uuidString,
            text: text,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            status: .tracking,
            relatedTopic: nil,
            lastReviewedAt: nil
        )
    }
}

// MARK: - Observations
struct Observations: Codable {
    var patterns: [String]
    var motivators: [String]
    var consistency: String
    var currentFocus: String
    var openItems: [String]
    /// AI's hidden coaching scratchpad. Decode is backwards-compatible
    /// with the legacy `[String]` shape — old strings get wrapped as
    /// tracking entries on first read. New writes always persist as
    /// the structured form.
    var coachingNotes: [CoachingNoteEntry]

    static func empty() -> Observations {
        Observations(
            patterns: [],
            motivators: [],
            consistency: "",
            currentFocus: "",
            openItems: [],
            coachingNotes: []
        )
    }

    enum CodingKeys: String, CodingKey {
        case patterns, motivators, consistency, currentFocus, openItems, coachingNotes
    }

    init(patterns: [String], motivators: [String], consistency: String, currentFocus: String, openItems: [String], coachingNotes: [CoachingNoteEntry]) {
        self.patterns = patterns
        self.motivators = motivators
        self.consistency = consistency
        self.currentFocus = currentFocus
        self.openItems = openItems
        self.coachingNotes = coachingNotes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.patterns     = try c.decodeIfPresent([String].self, forKey: .patterns) ?? []
        self.motivators   = try c.decodeIfPresent([String].self, forKey: .motivators) ?? []
        self.consistency  = try c.decodeIfPresent(String.self, forKey: .consistency) ?? ""
        self.currentFocus = try c.decodeIfPresent(String.self, forKey: .currentFocus) ?? ""
        self.openItems    = try c.decodeIfPresent([String].self, forKey: .openItems) ?? []

        // coachingNotes: try the new structured form first, fall back to
        // legacy [String]. Empty / missing keys decode to []. Anything
        // else falls through to the structured decoder's error.
        if let structured = try? c.decode([CoachingNoteEntry].self, forKey: .coachingNotes) {
            self.coachingNotes = structured
        } else if let legacy = try? c.decode([String].self, forKey: .coachingNotes) {
            self.coachingNotes = legacy.map(CoachingNoteEntry.upgradeLegacy)
        } else {
            self.coachingNotes = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(patterns, forKey: .patterns)
        try c.encode(motivators, forKey: .motivators)
        try c.encode(consistency, forKey: .consistency)
        try c.encode(currentFocus, forKey: .currentFocus)
        try c.encode(openItems, forKey: .openItems)
        // Always emit the new structured form. Old clients that haven't
        // updated will fail to decode coachingNotes; they need this
        // schema bump to roll out before deploying server-side writes.
        try c.encode(coachingNotes, forKey: .coachingNotes)
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
