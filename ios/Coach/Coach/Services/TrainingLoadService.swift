import Foundation
import Supabase

// MARK: - TrainingLoadService
//
// Read/write/recompute layer for the `daily_training_load` table. The
// table is the source of truth for CTL/ATL/TSB on every surface — Stats
// chart, Today readiness chip, coach prompt readiness section. The old
// `TrainingStressCalculator.fitnessTimeSeries` recomputed from scratch on
// every read; this service writes the values once and reads back O(rows).
//
// Recompute model: soft immutable past. A daily row, once written, is
// never touched unless an underlying workout in its date range is
// added / edited / deleted, at which point we walk forward from that
// date applying the EWMAs to the row immediately preceding the trigger
// date. Idempotent — re-running over the same range produces the same
// values.
//
// Phase 1 scope: persistence + recompute orchestration. Per-session TSS
// still goes through `TrainingStressCalculator.tss(for:)` (the legacy
// fallback ladder). Phase 2 swaps in per-sport ideal-vs-fallback
// computation and stamps method/confidence into each `LoadSource`.

@MainActor
enum TrainingLoadService {

    // MARK: - Read

    /// Fetch every daily-load row for the current user, ordered ascending.
    /// Used by AnalyticsTab and any caller that wants the full series.
    static func loadAll() async throws -> [DailyTrainingLoad] {
        let client = SupabaseService.shared.client
        let rows: [DailyTrainingLoad] = try await client
            .from("daily_training_load")
            .select()
            .order("date", ascending: true)
            .execute()
            .value
        return rows
    }

    /// Latest row, or nil if the table is empty for this user. Convenient
    /// for the readiness chip / coach prompt's "current" snapshot.
    static func loadLatest() async throws -> DailyTrainingLoad? {
        let client = SupabaseService.shared.client
        let rows: [DailyTrainingLoad] = try await client
            .from("daily_training_load")
            .select()
            .order("date", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Up to `days` most-recent rows, ascending by date. Used by the coach
    /// prompt's training-load snapshot to compute a 7-day CTL ramp without
    /// pulling the entire timeline.
    static func loadRecent(days: Int) async throws -> [DailyTrainingLoad] {
        let client = SupabaseService.shared.client
        let rows: [DailyTrainingLoad] = try await client
            .from("daily_training_load")
            .select()
            .order("date", ascending: false)
            .limit(days)
            .execute()
            .value
        return rows.reversed()
    }

    // MARK: - Recompute

    /// Recompute the daily-load timeline from `fromDate` (inclusive)
    /// through today, reading workouts from the in-memory `cardio` /
    /// `strength` arrays. Writes one row per day, upserting (so re-runs
    /// are idempotent).
    ///
    /// The seed values for `fromDate` come from the row immediately
    /// preceding it (which is left untouched). When `fromDate` is the
    /// earliest available date, seeds at 0 and accepts the standard
    /// EWMA warm-up window.
    static func recompute(
        from fromDate: Date,
        cardio: [CardioWorkout],
        strength: [StrengthSession],
        resolver: BenchmarkResolver,
        reason: String
    ) async throws {
        let client = SupabaseService.shared.client
        let cal = Calendar.current
        let fmt = Self.dateFormatter

        let from = cal.startOfDay(for: fromDate)
        let today = cal.startOfDay(for: Date())
        guard from <= today else { return }

        // Seed from the row immediately before `from`. If none exists, we
        // start at 0.
        let priorDate = cal.date(byAdding: .day, value: -1, to: from)!
        let priorKey = fmt.string(from: priorDate)
        let priorRows: [DailyTrainingLoad] = (try? await client
            .from("daily_training_load")
            .select()
            .eq("date", value: priorKey)
            .limit(1)
            .execute()
            .value) ?? []
        let prior = priorRows.first

        var ctl = prior?.ctl ?? 0
        var atl = prior?.atl ?? 0

        let lambdaCTL = TrainingStressCalculator.lambdaCTL
        let lambdaATL = TrainingStressCalculator.lambdaATL

        // Group workouts by date once for fast per-day lookup.
        let cardioByDate = Dictionary(grouping: cardio, by: \.date)
        let strengthByDate = Dictionary(grouping: strength, by: \.date)

        var rows: [DailyTrainingLoad] = []
        var current = from
        while current <= today {
            let key = fmt.string(from: current)
            let dayCardio = cardioByDate[key] ?? []
            let dayStrength = strengthByDate[key] ?? []

            // Per-workout sources via the per-sport TSS ladder. Each
            // result carries the actual method used (power/pace/HR/etc)
            // and a confidence level for UI provenance.
            var sources: [LoadSource] = []
            for w in dayCardio {
                let r = TSSLadder.tss(for: w, resolver: resolver)
                sources.append(LoadSource(
                    workoutId: w.id,
                    kind: .cardio,
                    tss: r.tss,
                    method: r.method,
                    confidence: r.confidence
                ))
            }
            for s in dayStrength {
                let r = TSSLadder.tss(forStrength: s)
                sources.append(LoadSource(
                    workoutId: s.id,
                    kind: .strength,
                    tss: r.tss,
                    method: r.method,
                    confidence: r.confidence
                ))
            }

            let totalTSS = sources.reduce(0.0) { $0 + $1.tss }
            ctl = ctl * (1 - lambdaCTL) + totalTSS * lambdaCTL
            atl = atl * (1 - lambdaATL) + totalTSS * lambdaATL

            rows.append(DailyTrainingLoad(
                userId: prior?.userId ?? UUID(),  // server defaults if zero
                date: key,
                totalTss: totalTSS,
                ctl: ctl,
                atl: atl,
                tsb: ctl - atl,
                sources: sources,
                computedAt: nil,
                recomputeReason: reason
            ))

            current = cal.date(byAdding: .day, value: 1, to: current)!
        }

        guard !rows.isEmpty else { return }

        // Upsert in batches of 500 so a multi-year backfill doesn't ship
        // a single 10MB request body.
        for batch in rows.chunked(into: 500) {
            try await client
                .from("daily_training_load")
                .upsert(batch, onConflict: "user_id,date")
                .execute()
        }
    }

    /// One-shot backfill: wipes the user's daily-load rows and recomputes
    /// from the earliest cardio/strength workout (or 365 days back if
    /// no logged workouts) to today. Called once after the migration ships
    /// and again if HealthKit imports a long history.
    static func backfill(
        cardio: [CardioWorkout],
        strength: [StrengthSession],
        resolver: BenchmarkResolver
    ) async throws {
        let cal = Calendar.current
        let fmt = Self.dateFormatter

        let allDates: [Date] = (cardio.map(\.date) + strength.map(\.date))
            .compactMap { fmt.date(from: $0) }

        let earliest: Date
        if let min = allDates.min() {
            earliest = cal.startOfDay(for: min)
        } else {
            // No history — start 365 days back so a future imported workout
            // can land somewhere in-window without a forced recompute.
            earliest = cal.date(byAdding: .day, value: -365, to: Date())!
        }

        // Wipe and rebuild. Cleaner than trying to delta-merge.
        let client = SupabaseService.shared.client
        try await client
            .from("daily_training_load")
            .delete()
            .gte("date", value: fmt.string(from: earliest))
            .execute()

        try await recompute(
            from: earliest,
            cardio: cardio,
            strength: strength,
            resolver: resolver,
            reason: "backfill"
        )
    }

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC") // server stores DATE w/o tz
        return f
    }()
}

// MARK: - Array chunking

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return self.isEmpty ? [] : [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
