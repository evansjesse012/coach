import Foundation
import Supabase

// MARK: - WeeklyArtifactsService
//
// Read/write layer for `weekly_reviews` and `weekly_previews`. Mirrors
// the `TrainingLoadService` pattern: thin wrapper around the Supabase
// client with one method per access path the rest of the app needs.
//
// In W1 PR 1.1 this is read + create + populate + complete + save —
// the *tools* that drive these (`start_weekly_review_check_in`,
// `populate_review_field`, `complete_weekly_review`) land in PR 1.2,
// and the generators (`WeeklyReviewResponseGenerator`,
// `WeeklyPreviewGenerator`) land in PR 1.3.

@MainActor
enum WeeklyArtifactsService {

    // MARK: - Reads

    /// All reviews for the current user, ascending by week. Used by
    /// `DataService.loadAll`.
    static func loadReviews() async throws -> [WeeklyReview] {
        let client = SupabaseService.shared.client
        let rows: [WeeklyReview] = try await client
            .from("weekly_reviews")
            .select()
            .order("week_start_date", ascending: true)
            .execute()
            .value
        return rows
    }

    /// All previews for the current user, ascending by week. Used by
    /// `DataService.loadAll`.
    static func loadPreviews() async throws -> [WeeklyPreview] {
        let client = SupabaseService.shared.client
        let rows: [WeeklyPreview] = try await client
            .from("weekly_previews")
            .select()
            .order("week_start_date", ascending: true)
            .execute()
            .value
        return rows
    }

    /// Latest in-progress (not-yet-completed) review for the user, or
    /// nil. Used by the trigger to detect whether a check-in is already
    /// underway so we don't start a second one.
    static func latestInProgressReview() async throws -> WeeklyReview? {
        let client = SupabaseService.shared.client
        let rows: [WeeklyReview] = try await client
            .from("weekly_reviews")
            .select()
            .is("completed_at", value: nil)
            .order("week_start_date", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    // MARK: - Writes (drive the check-in lifecycle)

    /// Create an in-progress review row keyed by week-start date (the
    /// athlete's chosen anchor day). If a row already exists for that
    /// week, returns it instead of creating a duplicate — the unique
    /// constraint on `(user_id, week_start_date)` would reject it
    /// anyway, and the caller usually wants idempotent "start or
    /// resume."
    static func createInProgressReview(weekStart: Date, anchor: Weekday) async throws -> WeeklyReview {
        let client = SupabaseService.shared.client
        let weekStartStr = WeekBoundary.weekStartString(of: weekStart, anchor: anchor)
        let weekEndStr = WeekBoundary.weekEndString(of: weekStart, anchor: anchor)

        // Resume if one already exists for this week-start.
        let existing: [WeeklyReview] = try await client
            .from("weekly_reviews")
            .select()
            .eq("week_start_date", value: weekStartStr)
            .limit(1)
            .execute()
            .value
        if let existing = existing.first { return existing }

        // Insert fresh. Server fills user_id, id, created_at; we send
        // only the keys we want set on insert. Decoding the inserted row
        // with `.select()` returns the canonical server view.
        struct Insert: Encodable {
            let week_start_date: String
            let week_end_date: String
            let pain_flag: Bool = false
            let ai_response_components: [String: String] = [:]   // empty {} JSONB
            let patterns_detected: [String] = []                 // empty [] JSONB
        }
        let row: WeeklyReview = try await client
            .from("weekly_reviews")
            .insert(Insert(
                week_start_date: weekStartStr,
                week_end_date: weekEndStr
            ))
            .select()
            .single()
            .execute()
            .value
        return row
    }

    /// Shallow-merge structured fields onto an in-progress review.
    /// Caller passes only the fields they want changed. `populate_review_field`
    /// in PR 1.2 calls this once per athlete answer during the conversation.
    static func updateReviewFields(id: UUID, patch: ReviewFieldPatch) async throws -> WeeklyReview {
        let client = SupabaseService.shared.client
        let row: WeeklyReview = try await client
            .from("weekly_reviews")
            .update(patch)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
        return row
    }

    /// Mark the review complete: stamps `completed_at` and writes the
    /// computed `adherence_pct`. AI-authored fields are written via
    /// `attachAIResponse` from the generator path (PR 1.3); this method
    /// only finalizes athlete-side state.
    static func markReviewComplete(id: UUID, adherencePct: Double?) async throws -> WeeklyReview {
        let client = SupabaseService.shared.client

        struct Patch: Encodable {
            let completed_at: String
            let adherence_pct: Double?
        }

        let row: WeeklyReview = try await client
            .from("weekly_reviews")
            .update(Patch(
                completed_at: ISO8601DateFormatter().string(from: Date()),
                adherence_pct: adherencePct
            ))
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
        return row
    }

    /// Attach the AI-generated response prose, structured components,
    /// and detected patterns to a finalized review. Called from the
    /// review-response generator (PR 1.3).
    static func attachAIResponse(
        reviewId: UUID,
        text: String,
        components: WeeklyReview.AIResponseComponents,
        patternsDetected: [String]
    ) async throws -> WeeklyReview {
        let client = SupabaseService.shared.client

        struct Patch: Encodable {
            let ai_response_text: String
            let ai_response_components: WeeklyReview.AIResponseComponents
            let patterns_detected: [String]
        }

        let row: WeeklyReview = try await client
            .from("weekly_reviews")
            .update(Patch(
                ai_response_text: text,
                ai_response_components: components,
                patterns_detected: patternsDetected
            ))
            .eq("id", value: reviewId.uuidString)
            .select()
            .single()
            .execute()
            .value
        return row
    }

    /// Insert (or upsert on the unique key) the generated preview.
    /// Called from the preview generator (PR 1.3) once it's produced
    /// the prose + structured components.
    static func savePreview(_ preview: WeeklyPreview) async throws -> WeeklyPreview {
        let client = SupabaseService.shared.client
        let row: WeeklyPreview = try await client
            .from("weekly_previews")
            .upsert(preview, onConflict: "user_id,week_start_date")
            .select()
            .single()
            .execute()
            .value
        return row
    }

    // MARK: - Preview engagement

    /// Stamp `read_at` on first view, or increment `reread_count` on
    /// subsequent views. Best-effort: failures are swallowed since
    /// engagement metrics shouldn't block the artifact rendering. The
    /// caller passes the current `read_at` and `reread_count` from the
    /// in-memory model so we don't burn an extra round-trip just to
    /// check; this means concurrent devices could clobber each other,
    /// but single-user-app simplification.
    static func markPreviewOpened(
        id: UUID,
        currentReadAt: String?,
        currentRereadCount: Int
    ) async {
        let client = SupabaseService.shared.client
        do {
            if currentReadAt == nil {
                struct Patch: Encodable { let read_at: String }
                _ = try await client
                    .from("weekly_previews")
                    .update(Patch(read_at: ISO8601DateFormatter().string(from: Date())))
                    .eq("id", value: id.uuidString)
                    .execute()
            } else {
                struct Patch: Encodable { let reread_count: Int }
                _ = try await client
                    .from("weekly_previews")
                    .update(Patch(reread_count: currentRereadCount + 1))
                    .eq("id", value: id.uuidString)
                    .execute()
            }
        } catch {
            // Engagement is best-effort.
        }
    }

    // MARK: - Trigger logic

    /// Returns the `yyyy-MM-dd` week-start of the week that should be
    /// reviewed if the athlete should be prompted to start a check-in
    /// right now, or nil if no prompt is appropriate.
    ///
    /// Trigger window follows the athlete's week anchor: the LAST day
    /// of their week after 16:00 local time, OR the FIRST day of the
    /// new week before 12:00 local time (Sunday evening / Monday
    /// morning for a Monday anchor). Only fires when no completed
    /// review exists for the corresponding week, and only once per
    /// (review-week × launch session) — UserDefaults stores the most
    /// recent prompt timestamp to debounce repeated app-opens within
    /// the same window.
    static func shouldPromptCheckIn(
        now: Date,
        reviews: [WeeklyReview],
        anchor: Weekday
    ) -> String? {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: now) // 1=Sun..7=Sat
        let hour = cal.component(.hour, from: now)
        let inWindow = (weekday == anchor.previous.calendarWeekday && hour >= 16)
            || (weekday == anchor.calendarWeekday && hour < 12)
        guard inWindow else { return nil }

        let weekStart = WeekBoundary.reviewWeekStartString(of: now, anchor: anchor)

        // Already completed for this week — nothing to prompt.
        if reviews.contains(where: { $0.weekStartDate == weekStart && $0.completedAt != nil }) {
            return nil
        }

        // Already prompted in this same review-window — debounce.
        let lastPromptedTs = UserDefaults.standard.double(forKey: lastPromptedKey)
        if lastPromptedTs > 0 {
            let lastPrompted = Date(timeIntervalSince1970: lastPromptedTs)
            if WeekBoundary.reviewWeekStartString(of: lastPrompted, anchor: anchor) == weekStart {
                return nil
            }
        }

        return weekStart
    }

    /// Stamp the prompt time so subsequent `shouldPromptCheckIn` calls
    /// for the same review-window short-circuit. Called immediately
    /// after the trigger fires.
    static func markPromptedForCheckIn(at: Date = Date()) {
        UserDefaults.standard.set(at.timeIntervalSince1970, forKey: lastPromptedKey)
    }

    private static let lastPromptedKey = "coach.weeklyCheckInPromptedAt.v1"
}

// MARK: - Patch type for partial review updates
//
// `populate_review_field` in PR 1.2 collects whichever fields the agent
// extracts from the conversation and forwards them as a patch. All
// fields optional so the LLM can send any subset.

struct ReviewFieldPatch: Encodable {
    var sleep_avg_hours:       Double?
    var energy_rating:         Int?
    var motivation_rating:     Int?
    var soreness_level:        String?
    var soreness_location:     String?
    var pain_flag:             Bool?
    var pain_description:      String?
    var life_stress_rating:    Int?
    var body_weight:           Double?
    var best_session_text:     String?
    var best_session_id:       UUID?
    var worst_session_text:    String?
    var worst_session_id:      UUID?
    var life_context:          String?
    var questions:             String?
    var next_week_focus:       String?
}
