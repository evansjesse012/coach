import Foundation

struct ChatMessageMetadata: Codable {
    var logged: Bool?
    var nutritionLogged: Bool?
    var planChanged: Bool?
    var appActionTaken: Bool?
    var isError: Bool?
}

// MARK: - Rich Content Components

/// Structured UI components that render inline within chat messages.
/// Each case carries the data needed to render a self-contained card.
struct RichComponent: Codable, Identifiable {
    var id: String
    var kind: RichComponentKind

    static func workoutCard(session: PrescribedSession, weekNum: Int, dayIdx: Int, sessionIdx: Int) -> RichComponent {
        RichComponent(
            id: "workout-\(weekNum)-\(dayIdx)-\(sessionIdx)-\(session.label)",
            kind: .workoutCard(WorkoutCardData(session: session, weekNum: weekNum, dayIdx: dayIdx, sessionIdx: sessionIdx))
        )
    }

    static func weekSummary(dots: [DotStatus], sessionsCompleted: Int, total: Int, adherence: Double, dayLabels: [String]? = nil) -> RichComponent {
        RichComponent(
            id: "week-\(sessionsCompleted)-\(total)",
            kind: .weekSummary(WeekSummaryData(dots: dots, sessionsCompleted: sessionsCompleted, total: total, adherence: adherence, dayLabels: dayLabels))
        )
    }

    static func statHighlight(label: String, value: String, trend: String? = nil, trendUp: Bool? = nil) -> RichComponent {
        RichComponent(
            id: "stat-\(label)-\(value)",
            kind: .statHighlight(StatHighlightData(label: label, value: value, trend: trend, trendUp: trendUp))
        )
    }

    static func raceCountdown(name: String, weeksOut: Int) -> RichComponent {
        RichComponent(
            id: "countdown-\(name)-\(weeksOut)",
            kind: .raceCountdown(RaceCountdownData(name: name, weeksOut: weeksOut))
        )
    }

    static func phaseProgress(phaseName: String, phaseNumber: Int, totalPhases: Int, weeksLeft: Int) -> RichComponent {
        RichComponent(
            id: "phase-\(phaseName)-\(phaseNumber)",
            kind: .phaseProgress(PhaseProgressData(phaseName: phaseName, phaseNumber: phaseNumber, totalPhases: totalPhases, weeksLeft: weeksLeft))
        )
    }
}

enum RichComponentKind: Codable {
    case workoutCard(WorkoutCardData)
    case weekSummary(WeekSummaryData)
    case statHighlight(StatHighlightData)
    case raceCountdown(RaceCountdownData)
    case phaseProgress(PhaseProgressData)
}

struct WorkoutCardData: Codable {
    var session: PrescribedSession
    var weekNum: Int
    var dayIdx: Int
    var sessionIdx: Int
}

struct WeekSummaryData: Codable {
    var dots: [DotStatus]
    var sessionsCompleted: Int
    var total: Int
    var adherence: Double
    /// Weekday letters in the same order as `dots` (anchor-ordered, e.g.
    /// ["S","M","T","W","T","F","S"] for a Sunday-start plan). Optional —
    /// cards persisted before week-start support render Monday-first.
    var dayLabels: [String]?
}

struct StatHighlightData: Codable {
    var label: String
    var value: String
    var trend: String?
    var trendUp: Bool?
}

struct RaceCountdownData: Codable {
    var name: String
    var weeksOut: Int
}

struct PhaseProgressData: Codable {
    var phaseName: String
    var phaseNumber: Int
    var totalPhases: Int
    var weeksLeft: Int
}

/// Status of a single day dot in the week summary.
enum DotStatus: String, Codable {
    case rest          // moon icon
    case pending       // empty circle
    case completed     // green checkmark
    case modified      // yellow checkmark
    case swapped       // blue arrows
    case skipped       // red X
    case needsReview   // yellow circle
    case today         // accent ring (current day, unresolved)
}

// MARK: - Chat Message

struct ChatMessage: Codable, Identifiable {
    let id: Int?          // auto-incremented by Supabase, nil for local-only
    var role: String      // "user" | "assistant"
    var content: String
    var metadata: ChatMessageMetadata?
    var conversationId: String?
    var richContent: [RichComponent]?

    /// Server-side timestamp the row was inserted. Populated by Supabase's
    /// `created_at` column. Optional so legacy rows without the column still
    /// decode; the divider logic in `CoachTab` falls back gracefully when
    /// any neighbor is missing a timestamp.
    var createdAt: String?

    /// Short follow-up reply suggestions returned by the coach LLM alongside
    /// its response. Rendered only under the most recent assistant message
    /// and cleared visually (not mutated in storage) the moment the user
    /// sends anything. Nil when the LLM chose not to suggest replies.
    var suggestedReplies: [String]?

    enum CodingKeys: String, CodingKey {
        case id, role, content, metadata
        case conversationId = "conversation_id"
        case richContent = "rich_content"
        case createdAt = "created_at"
        case suggestedReplies = "suggested_replies"
    }

    static func user(_ content: String, conversationId: String? = nil) -> ChatMessage {
        ChatMessage(id: nil, role: "user", content: content, conversationId: conversationId)
    }

    static func assistant(
        _ content: String,
        metadata: ChatMessageMetadata? = nil,
        conversationId: String? = nil,
        richContent: [RichComponent]? = nil,
        suggestedReplies: [String]? = nil
    ) -> ChatMessage {
        ChatMessage(
            id: nil,
            role: "assistant",
            content: content,
            metadata: metadata,
            conversationId: conversationId,
            richContent: richContent,
            suggestedReplies: suggestedReplies
        )
    }
}
