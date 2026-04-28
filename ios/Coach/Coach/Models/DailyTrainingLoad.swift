import Foundation

// MARK: - DailyTrainingLoad
//
// One row per (user, date) carrying the authoritative CTL/ATL/TSB and a
// breakdown of which workouts contributed to the day's TSS. Past rows are
// immutable by default; only edits or deletes that touch a workout in the
// row's date range trigger a forward recompute (handled in
// `TrainingLoadService`).
//
// Schema-mirrors the `daily_training_load` Postgres table from migration
// 010. The Swift model uses `LocalDate` (yyyy-MM-dd) so it sorts and
// compares the same way the DB does.

struct DailyTrainingLoad: Codable, Identifiable {
    /// `userId|date` — exists only for SwiftUI list identity. Never sent
    /// to the wire; encoded out of `CodingKeys` below.
    var id: String { "\(userId.uuidString)|\(date)" }

    var userId: UUID
    var date: String              // "yyyy-MM-dd"
    var totalTss: Double
    var ctl: Double
    var atl: Double
    var tsb: Double
    var sources: [LoadSource]
    var computedAt: String?       // ISO8601, server-set
    var recomputeReason: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case date
        case totalTss = "total_tss"
        case ctl, atl, tsb, sources
        case computedAt = "computed_at"
        case recomputeReason = "recompute_reason"
    }
}

/// Per-workout contribution to a day's TSS, with provenance so the UI can
/// surface which method produced the number.
struct LoadSource: Codable, Hashable {
    var workoutId: String
    var kind: SourceKind
    var tss: Double
    var method: TSSMethod
    var confidence: Confidence

    enum SourceKind: String, Codable {
        case cardio
        case strength
        case brick
    }

    /// Which calculation tier produced this TSS. The string raw values are
    /// stable across migrations — never rename without a migration plan.
    enum TSSMethod: String, Codable {
        // Cycling
        case powerNormalized   = "power_normalized"
        case powerAvg          = "power_avg"
        // Running
        case paceGap           = "pace_gap"
        case paceFlat          = "pace_flat"
        // Swimming
        case swimPace          = "swim_pace"
        // HR-based (any sport)
        case hrZones           = "hr_zones"
        case hrAvg             = "hr_avg"
        // Strength
        case sessionRPE        = "session_rpe"
        case volumeLoad        = "volume_load"
        // Generic fallback
        case effortCategory    = "effort_category"
        case sportDefault      = "sport_default"
    }

    enum Confidence: String, Codable {
        case high
        case medium
        case low
    }
}

// MARK: - BenchmarkHistory
//
// Versioned timeline of athlete thresholds (LTHR, FTP, threshold pace,
// CSS, max HR, etc). When computing TSS for a workout dated D, we pick
// the row whose `effectiveFrom <= D` and is the latest such row. So
// historical workouts get historical thresholds, even after the athlete
// FTP-tests up.

struct BenchmarkHistoryEntry: Codable, Identifiable {
    var id: Int64?            // server-assigned BIGSERIAL
    var userId: UUID?         // server-defaulted to auth.uid()
    var kind: String          // "lthr" | "max_hr" | "ftp" | "threshold_pace" | "css" | ...
    var value: Double
    var unit: String?
    var effectiveFrom: String // "yyyy-MM-dd"
    var source: String        // "manual" | "test" | "estimated" | "imported"
    var notes: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case kind, value, unit
        case effectiveFrom = "effective_from"
        case source, notes
        case createdAt = "created_at"
    }
}
