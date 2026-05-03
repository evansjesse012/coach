import Foundation

// MARK: - WeeklyPreview
//
// AI-generated framing for the week ahead. Schema-mirrors
// `weekly_previews` from migration 012. Produced as the second half
// of the paired ritual when a review is completed (or as a standalone
// "generic" preview when the athlete skipped the check-in — in that
// case `pairedReviewId` is nil and the framing acknowledges the
// missing input).
//
// `themeCategory` is free-form text in W1 Phase 1 and gets enum'd in
// Phase 5 as the theme taxonomy is codified — leaving it as String
// here keeps the wire shape stable across that change.

struct WeeklyPreview: Codable, Identifiable, Hashable {
    var id: UUID
    var userId: UUID?                       // server-defaulted to auth.uid()
    var weekStartDate: String               // "yyyy-MM-dd" Monday
    var weekEndDate: String                 // "yyyy-MM-dd" Sunday
    var createdAt: String?                  // ISO8601, server-set

    /// The review that informed this preview. nil for skipped-check-in
    /// previews. ON DELETE SET NULL on the SQL side, so a deleted review
    /// leaves the preview standing alone rather than cascading away.
    var pairedReviewId: UUID?

    // Structured framing
    var theme: String                       // one-sentence header, prominently displayed
    var themeCategory: String?              // "build" / "recovery" / "race_week" / etc. Phase 5 enum'd.
    var macroPosition: String?              // "Week 4 of 8 in build, 12 weeks until Oceanside"

    // Volume metrics
    var totalPlannedHours: Double?
    var totalPlannedDistance: Double?
    var totalPlannedTss: Double?
    var deltaFromPreviousWeekPct: Double?
    var numQualitySessions: Int?
    var numEasySessions: Int?

    // Structured authored content
    var keySessions: [KeySession]
    var watchOuts: [WatchOut]
    var tacticalNotes: [TacticalNote]
    var lifeManagementNotes: [LifeManagementNote]

    var renderedProse: String               // the body the athlete reads
    var closingQuestion: String?

    // Engagement (Phase 1 writes are best-effort; UI consumes later)
    var readAt: String?
    var rereadCount: Int
    var respondedTo: Bool

    // MARK: - Nested types

    struct KeySession: Codable, Hashable {
        var sessionId: UUID?
        var dayOfWeek: String               // "monday".."sunday"
        var name: String
        var whyItMatters: String
        var successCriteria: String
        var watchFor: String

        enum CodingKeys: String, CodingKey {
            case sessionId          = "session_id"
            case dayOfWeek          = "day_of_week"
            case name
            case whyItMatters       = "why_it_matters"
            case successCriteria    = "success_criteria"
            case watchFor           = "watch_for"
        }
    }

    struct WatchOut: Codable, Hashable {
        var type: String                    // "life_stress"|"sleep_deficit"|"weather"|... (free-form in Phase 1)
        var description: String
        /// The data point this is grounded in — kept as a JSON-shaped
        /// `[String: AnyCodableValue]` would be ideal but for v0 we stash
        /// a String summary so callers don't need a polymorphic decoder.
        var referencedData: String?

        enum CodingKeys: String, CodingKey {
            case type
            case description
            case referencedData = "referenced_data"
        }
    }

    struct TacticalNote: Codable, Hashable {
        var category: String                // "pacing"|"fueling"|"gear"|"recovery"|"strength"
        var note: String
    }

    struct LifeManagementNote: Codable, Hashable {
        var referencedContext: String       // what life context the note addresses
        var note: String

        enum CodingKeys: String, CodingKey {
            case referencedContext = "referenced_context"
            case note
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId                     = "user_id"
        case weekStartDate              = "week_start_date"
        case weekEndDate                = "week_end_date"
        case createdAt                  = "created_at"
        case pairedReviewId             = "paired_review_id"
        case theme
        case themeCategory              = "theme_category"
        case macroPosition              = "macro_position"
        case totalPlannedHours          = "total_planned_hours"
        case totalPlannedDistance       = "total_planned_distance"
        case totalPlannedTss            = "total_planned_tss"
        case deltaFromPreviousWeekPct   = "delta_from_previous_week_pct"
        case numQualitySessions         = "num_quality_sessions"
        case numEasySessions            = "num_easy_sessions"
        case keySessions                = "key_sessions"
        case watchOuts                  = "watch_outs"
        case tacticalNotes              = "tactical_notes"
        case lifeManagementNotes        = "life_management_notes"
        case renderedProse              = "rendered_prose"
        case closingQuestion            = "closing_question"
        case readAt                     = "read_at"
        case rereadCount                = "reread_count"
        case respondedTo                = "responded_to"
    }
}
