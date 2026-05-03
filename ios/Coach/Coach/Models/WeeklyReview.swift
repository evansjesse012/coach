import Foundation

// MARK: - WeeklyReview
//
// Athlete-authored half (structured + free text) plus AI-authored half
// (response prose + structured components + detected patterns) for a
// single Mon–Sun window. Schema-mirrors `weekly_reviews` from migration
// 012. Populated incrementally during the conversational check-in:
// `start_weekly_review_check_in` inserts a row with most fields null,
// `populate_review_field` writes structured fields one at a time as
// the agent extracts them, `complete_weekly_review` stamps
// `completed_at`, computes `adherence_pct`, and triggers the paired
// generators that fill in `ai_response_text`, `ai_response_components`,
// and `patterns_detected`.

struct WeeklyReview: Codable, Identifiable, Hashable {
    var id: UUID
    var userId: UUID?                       // server-defaulted to auth.uid()
    var weekStartDate: String               // "yyyy-MM-dd" Monday, athlete-local
    var weekEndDate: String                 // "yyyy-MM-dd" Sunday, athlete-local
    var createdAt: String?                  // ISO8601, server-set
    var completedAt: String?                // ISO8601, null while in-progress

    // Structured athlete inputs
    var sleepAvgHours: Double?
    var energyRating: Int?                  // 1..10
    var motivationRating: Int?              // 1..10
    var sorenessLevel: SorenessLevel?
    var sorenessLocation: String?
    var painFlag: Bool
    var painDescription: String?
    var lifeStressRating: Int?              // 1..10
    var bodyWeight: Double?
    var adherencePct: Double?               // auto-computed at complete

    // Free-text athlete inputs
    var bestSessionText: String?
    var bestSessionId: UUID?
    var worstSessionText: String?
    var worstSessionId: UUID?
    var lifeContext: String?
    var questions: String?
    var nextWeekFocus: String?

    // AI-authored
    var aiResponseText: String?
    var aiResponseComponents: AIResponseComponents
    var patternsDetected: [String]

    var isComplete: Bool { completedAt != nil }

    enum SorenessLevel: String, Codable, Hashable {
        case none
        case mild
        case significant
        case concerning
    }

    /// Components the LLM returns alongside the prose. Stored as JSONB on
    /// the row; nested types here so callers don't need to dig through
    /// `[String: Any]`. Empty defaults so the in-progress row decodes
    /// before the generator has run.
    struct AIResponseComponents: Codable, Hashable {
        var lifeAcknowledgment: String?
        var weekAssessment: String?
        var sessionFeedback: [SessionFeedback]
        var patternCallout: String?
        var questionsAnswered: [QA]
        var bridgeToNextWeek: String?

        struct SessionFeedback: Codable, Hashable {
            var sessionId: UUID?
            var feedback: String

            enum CodingKeys: String, CodingKey {
                case feedback
                case sessionId = "session_id"
            }
        }

        struct QA: Codable, Hashable {
            var question: String
            var answer: String
        }

        static func empty() -> AIResponseComponents {
            AIResponseComponents(
                lifeAcknowledgment: nil,
                weekAssessment: nil,
                sessionFeedback: [],
                patternCallout: nil,
                questionsAnswered: [],
                bridgeToNextWeek: nil
            )
        }

        enum CodingKeys: String, CodingKey {
            case lifeAcknowledgment = "life_acknowledgment"
            case weekAssessment     = "week_assessment"
            case sessionFeedback    = "session_feedback"
            case patternCallout     = "pattern_callout"
            case questionsAnswered  = "questions_answered"
            case bridgeToNextWeek   = "bridge_to_next_week"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId             = "user_id"
        case weekStartDate      = "week_start_date"
        case weekEndDate        = "week_end_date"
        case createdAt          = "created_at"
        case completedAt        = "completed_at"
        case sleepAvgHours      = "sleep_avg_hours"
        case energyRating       = "energy_rating"
        case motivationRating   = "motivation_rating"
        case sorenessLevel      = "soreness_level"
        case sorenessLocation   = "soreness_location"
        case painFlag           = "pain_flag"
        case painDescription    = "pain_description"
        case lifeStressRating   = "life_stress_rating"
        case bodyWeight         = "body_weight"
        case adherencePct       = "adherence_pct"
        case bestSessionText    = "best_session_text"
        case bestSessionId      = "best_session_id"
        case worstSessionText   = "worst_session_text"
        case worstSessionId     = "worst_session_id"
        case lifeContext        = "life_context"
        case questions
        case nextWeekFocus      = "next_week_focus"
        case aiResponseText     = "ai_response_text"
        case aiResponseComponents = "ai_response_components"
        case patternsDetected   = "patterns_detected"
    }
}
