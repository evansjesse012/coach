import Foundation

// MARK: - BenchmarkResolver
//
// Date-aware lookup of athlete thresholds (LTHR, FTP, threshold pace, CSS,
// max HR) against the versioned `benchmark_history` timeline. A workout
// dated 2024-08-15 should be scored against the FTP that was effective on
// that date, not whatever the athlete tested up to last week — otherwise
// every history-recompute rewrites the entire chart whenever a benchmark
// changes.
//
// Built once per recompute pass with the user's full history sorted
// descending by `effectiveFrom`, then queried per workout. O(rows) build,
// O(log rows) per lookup.

struct BenchmarkResolver {

    /// All known benchmark records, grouped by `kind` and sorted DESC by
    /// effectiveFrom. The lookup walks the array for the first row whose
    /// effectiveFrom is on or before the workout date.
    private let byKind: [String: [BenchmarkHistoryEntry]]

    init(history: [BenchmarkHistoryEntry]) {
        var grouped: [String: [BenchmarkHistoryEntry]] = [:]
        for entry in history {
            grouped[entry.kind, default: []].append(entry)
        }
        // Sort each kind descending so the first match in the lookup is the
        // most recent one effective on the date in question.
        for k in grouped.keys {
            grouped[k]?.sort { $0.effectiveFrom > $1.effectiveFrom }
        }
        byKind = grouped
    }

    // MARK: - Single-value lookup

    /// Threshold value for `kind` effective on `dateString` (yyyy-MM-dd),
    /// or nil when the athlete has no history for that benchmark on or
    /// before that date.
    func value(_ kind: String, on dateString: String) -> Double? {
        guard let rows = byKind[kind] else { return nil }
        for row in rows where row.effectiveFrom <= dateString {
            return row.value
        }
        return nil
    }

    // MARK: - Convenience

    /// Lactate-threshold heart rate effective on the given date.
    func lthr(on date: String) -> Double? { value("lthr", on: date) }

    /// Maximum heart rate effective on the given date. When unknown,
    /// callers should fall back to a conservative age-based estimate
    /// (`208 − 0.7 × age`) — this resolver returns nil instead of guessing.
    func maxHR(on date: String) -> Double? { value("max_hr", on: date) }

    /// Functional threshold power (cycling), watts.
    func ftp(on date: String) -> Double? { value("ftp", on: date) }

    /// Threshold running pace stored as decimal minutes per mile (e.g.
    /// "7:30/mi" parsed to 7.5). The ingestion path is responsible for
    /// normalizing units when a value is recorded.
    func thresholdPace(on date: String) -> Double? { value("threshold_pace", on: date) }

    /// Critical swim speed stored as decimal minutes per 100m.
    func css(on date: String) -> Double? { value("css", on: date) }
}
