import Foundation

/// Athlete recovery state assembled from HealthKit. Feeds the LLM-built
/// `recovery_picture` narrative the coach reads each turn (Section 7).
///
/// Each metric pairs its latest value with a ~30-day rolling baseline so
/// the narrative generator can reason in deltas (e.g. "HRV down ~15%
/// from baseline") rather than dumping raw numbers. Any field can be
/// nil — HealthKit auth is partial, the watch isn't always worn, sleep
/// tracking misses naps. The generator handles partial snapshots
/// gracefully; if literally nothing is available we skip the LLM call
/// entirely and let CoachState render without a recovery picture.
///
/// Wrist temperature is special: Apple already exposes it as a signed
/// delta from a learned baseline (`appleSleepingWristTemperature`), so
/// we carry the delta directly and don't compute our own baseline.
struct RecoverySnapshot {
    /// When the snapshot was assembled. Used as the cache key — once we
    /// have a snapshot for a given date, we reuse the generated narrative
    /// across all chat turns that day.
    let asOf: Date

    // MARK: Cardiovascular
    let hrvMs: Double?
    let hrvBaselineMs: Double?

    let restingHrBpm: Double?
    let restingHrBaselineBpm: Double?

    let respiratoryRate: Double?
    let respiratoryRateBaseline: Double?

    // MARK: Temperature
    /// Signed delta in °C from Apple's own learned baseline. Positive =
    /// warmer than usual (often illness or excess load). Apple builds the
    /// baseline itself — typically takes ~30 nights of wear to stabilize.
    let wristTempDeltaC: Double?

    // MARK: Sleep
    let sleep: SleepSummary?

    // MARK: Activity context (yesterday)
    let stepsYesterday: Int?
    let stepsBaseline: Int?
    let activeEnergyYesterdayKcal: Int?
    let activeEnergyBaselineKcal: Int?

    // MARK: Slow-moving fitness signals
    let vo2Max: Double?
    let bodyMassKg: Double?

    /// True iff there's enough data to bother running the narrative
    /// generator. We don't burn an LLM call to write a paragraph that
    /// would just say "no data available."
    var hasAnySignal: Bool {
        hrvMs != nil
            || restingHrBpm != nil
            || respiratoryRate != nil
            || wristTempDeltaC != nil
            || sleep != nil
            || stepsYesterday != nil
            || activeEnergyYesterdayKcal != nil
            || vo2Max != nil
    }
}

struct SleepSummary {
    /// Time actually asleep (sum of asleep stages). Distinct from `inBedHours`.
    let asleepHours: Double
    let inBedHours: Double
    let deepHours: Double?
    let remHours: Double?
    let awakeHours: Double?
}
