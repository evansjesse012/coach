import Foundation

// MARK: - PlanEdit
//
// Append-only log row for a single `patch_weekly_plan` operation.
// Schema-mirrors `plan_edits` from migration 013. One row per applied
// op, so a multi-op patch produces multiple rows. The `payload`,
// `beforeState`, and `afterState` are stored as JSONB on the server
// via `AnyCodable`.
//
// `reason` carries the athlete's stated reason as paraphrased by the
// agent (Section 10 prompt makes this required-when-known). `snapshotId`
// is set by `DataService.recordPlanEdits` at write time — it points at
// the most recent `weekly_plan_snapshots` row for (planId, weekNumber)
// as of `appliedAt`, so the retrospective UI can bracket edits under
// the snapshot they modified.

struct PlanEdit: Codable, Identifiable {
    var id: UUID
    var userId: UUID?                       // server-defaulted to auth.uid()
    var planId: String
    var weekNumber: Int
    var appliedAt: String?                  // ISO8601, server-set
    var snapshotId: UUID?
    var opType: OpType
    var day: Int?                           // 0..6, or fromDay for `move`
    var sessionIndex: Int?                  // index within day, when applicable
    var payload: AnyCodable                 // raw op dict as sent to patch_weekly_plan
    var beforeState: AnyCodable?            // affected slice (day or {from,to}) before op
    var afterState: AnyCodable?             // affected slice after op
    var reason: String?
    var source: String                      // 'chat' for model-driven; reserved for future origins

    enum OpType: String, Codable {
        case move
        case update
        case setRest = "set_rest"
        case add
        case delete
    }

    enum CodingKeys: String, CodingKey {
        case id, payload, reason, source, day
        case userId = "user_id"
        case planId = "plan_id"
        case weekNumber = "week_number"
        case appliedAt = "applied_at"
        case snapshotId = "snapshot_id"
        case opType = "op_type"
        case sessionIndex = "session_index"
        case beforeState = "before_state"
        case afterState = "after_state"
    }
}
