import Foundation

// MARK: - PlanSnapshot
//
// Immutable per-generation snapshot of a single week's prescription.
// Schema-mirrors `weekly_plan_snapshots` from migration 013. One row is
// written each time a week is generated: `create_training_plan` (week 1,
// source=create_plan), `generate_week_plan` against a stub week
// (source=generate_week), or `generate_week_plan` against an already-
// populated week (source=regenerate_week).
//
// Multiple rows per (plan_id, week_number) are expected — the row with
// the most recent `frozen_at` is "the plan the athlete is currently
// trying to follow." Prior rows preserve regen history for retrospective
// rendering ("v1 plan and how it evolved before we threw it out").

struct PlanSnapshot: Codable, Identifiable {
    var id: UUID
    var userId: UUID?                       // server-defaulted to auth.uid()
    var planId: String
    var weekNumber: Int
    var frozenAt: String?                   // ISO8601, server-set
    var source: Source
    var sessions: [DayPlan]                 // mirrors WeeklyPlan.sessions
    var phase: Int?
    var focusOfWeek: String?

    enum Source: String, Codable {
        case createPlan = "create_plan"
        case generateWeek = "generate_week"
        case regenerateWeek = "regenerate_week"
    }

    enum CodingKeys: String, CodingKey {
        case id, source, sessions, phase
        case userId = "user_id"
        case planId = "plan_id"
        case weekNumber = "week_number"
        case frozenAt = "frozen_at"
        case focusOfWeek = "focus_of_week"
    }
}
