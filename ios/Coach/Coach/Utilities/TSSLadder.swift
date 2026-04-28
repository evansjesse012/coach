import Foundation

// MARK: - TSSLadder
//
// Per-sport TSS computation with an explicit ideal-vs-fallback ladder.
// Each call returns the TSS plus the *method* and *confidence* used so
// the daily-load row can carry full provenance — the UI shows "computed
// from your power file" vs "estimated from sport default" with the right
// confidence dot.
//
// Threshold inputs come from `BenchmarkResolver`, which is built from
// the versioned `benchmark_history` timeline so a 2024 workout uses the
// 2024 LTHR / FTP, not today's value. That keeps long histories
// internally consistent across re-tests.

enum TSSLadder {

    /// One workout's contribution to the day's TSS, with provenance.
    struct Result {
        let tss: Double
        let method: LoadSource.TSSMethod
        let confidence: LoadSource.Confidence
    }

    // MARK: - Cardio

    /// Best-available TSS for a logged cardio workout.
    /// Order per sport (best → fallback):
    ///   * Bike — power_normalized > power_avg > hr_zones > hr_avg > sport_default
    ///   * Run  — pace_flat (vs threshold pace) > hr_zones > hr_avg > sport_default
    ///   * Swim — swim_pace (vs CSS) > sport_default (HR is unreliable in water)
    ///   * Hike / brick / other — hr_zones > hr_avg > sport_default
    static func tss(
        for workout: CardioWorkout,
        resolver: BenchmarkResolver
    ) -> Result {
        let hours = Double(workout.duration) / 60.0
        guard hours > 0 else {
            return Result(tss: 0, method: .sportDefault, confidence: .low)
        }

        switch workout.sport {
        case .bike:
            return bikeTSS(workout, hours: hours, resolver: resolver)
        case .run:
            return runTSS(workout, hours: hours, resolver: resolver)
        case .swim:
            return swimTSS(workout, hours: hours, resolver: resolver)
        case .hike, .brick, .strength, .other:
            return generalHRTSS(workout, hours: hours, resolver: resolver)
        }
    }

    // MARK: - Strength

    /// Strength TSS via Foster's session-RPE method when available, else
    /// a sport-default estimate. We don't try to derive volume-load TSS
    /// from set/rep/weight tuples — the conversion factor is too sport-
    /// specific to be reliable, and session-RPE is the validated method.
    static func tss(forStrength session: StrengthSession) -> Result {
        let minutes = Double(session.duration ?? 45)
        if let rpe = session.rpe, rpe > 0 {
            // Foster session-RPE: TSS ≈ RPE × duration_min / 10
            return Result(
                tss: Double(rpe) * minutes / 10.0,
                method: .sessionRPE,
                confidence: .medium
            )
        }
        return Result(
            tss: (minutes / 60.0) * 40,        // 40 TSS/hr default
            method: .sportDefault,
            confidence: .low
        )
    }

    // MARK: - Bike branch

    private static func bikeTSS(
        _ w: CardioWorkout,
        hours: Double,
        resolver: BenchmarkResolver
    ) -> Result {
        let date = w.date

        // 1. Power-based, normalized power preferred. Use sample stream
        //    when present; otherwise treat avg power as the NP proxy.
        if let ftp = resolver.ftp(on: date), ftp > 0 {
            if let samples = w.healthData?.powerSamples,
               let np = normalizedPower(from: samples), np > 0 {
                let tss = (Double(w.duration) * 60.0 * np * (np / ftp))
                            / (ftp * 3600.0) * 100.0
                return Result(tss: tss, method: .powerNormalized, confidence: .high)
            }
            if let avg = w.avgPower, avg > 0 {
                let intensity = Double(avg) / ftp
                let tss = hours * intensity * intensity * 100
                return Result(tss: tss, method: .powerAvg, confidence: .medium)
            }
        }

        // 2. HR-zone or HR-avg fallback.
        return generalHRTSS(w, hours: hours, resolver: resolver, defaultPerHour: 55)
    }

    // MARK: - Run branch

    private static func runTSS(
        _ w: CardioWorkout,
        hours: Double,
        resolver: BenchmarkResolver
    ) -> Result {
        let date = w.date

        // 1. Pace-based rTSS — IF = thresholdPace / actualPace (pace is
        //    inverted: faster = lower number, so the ratio flips).
        if let avgPace = parsePace(w.pace),
           let threshold = resolver.thresholdPace(on: date),
           threshold > 0, avgPace > 0 {
            let intensity = threshold / avgPace        // > 1.0 means faster than threshold
            let tss = hours * intensity * intensity * 100
            return Result(tss: tss, method: .paceFlat, confidence: .medium)
        }

        // 2. HR ladder.
        return generalHRTSS(w, hours: hours, resolver: resolver, defaultPerHour: 60)
    }

    // MARK: - Swim branch

    private static func swimTSS(
        _ w: CardioWorkout,
        hours: Double,
        resolver: BenchmarkResolver
    ) -> Result {
        let date = w.date

        // 1. Pace vs CSS (critical swim speed). Same intensity-inversion
        //    as running pace.
        if let avgPace = parsePace(w.pace),
           let css = resolver.css(on: date),
           css > 0, avgPace > 0 {
            let intensity = css / avgPace
            let tss = hours * intensity * intensity * 100
            return Result(tss: tss, method: .swimPace, confidence: .high)
        }

        // 2. No HR fallback — heart rate in water is unreliable.
        return Result(tss: hours * 50, method: .sportDefault, confidence: .low)
    }

    // MARK: - General HR ladder (used by run/bike fallback + everything else)

    private static func generalHRTSS(
        _ w: CardioWorkout,
        hours: Double,
        resolver: BenchmarkResolver,
        defaultPerHour: Double? = nil
    ) -> Result {
        // 1. HR-zone time-in-zone (already validated upstream as having
        //    >60s of zone data).
        if let zones = w.hrZones, hasZoneData(zones) {
            let tss = tssFromHRZones(zones, totalMinutes: w.duration)
            return Result(tss: tss, method: .hrZones, confidence: .medium)
        }

        // 2. Avg-HR proxy. Resolver gives a date-correct max HR; failing
        //    that, fall back to 190 (matches the legacy hard-coded value).
        if let avgHR = w.avgHR, avgHR > 0 {
            let maxHR = resolver.maxHR(on: w.date) ?? Double(w.maxHR ?? 190)
            let intensity = Double(avgHR) / maxHR
            let tss = hours * intensity * intensity * 100
            return Result(tss: tss, method: .hrAvg, confidence: .low)
        }

        // 3. Sport default — fully fallback estimate.
        let perHour = defaultPerHour ?? sportDefaultPerHour(w.sport)
        return Result(tss: hours * perHour, method: .sportDefault, confidence: .low)
    }

    // MARK: - HR zone math (shared with the legacy calculator)

    private static func tssFromHRZones(_ zones: HRZones, totalMinutes: Int) -> Double {
        let z1 = Double(zones.z1 ?? 0)
        let z2 = Double(zones.z2 ?? 0)
        let z3 = Double(zones.z3 ?? 0)
        let z4 = Double(zones.z4 ?? 0)
        let z5 = Double(zones.z5 ?? 0)
        let total = z1 + z2 + z3 + z4 + z5
        guard total > 0 else { return Double(totalMinutes) / 60.0 * 60 }

        let weighted = (z1 * 0.55 * 0.55
                      + z2 * 0.75 * 0.75
                      + z3 * 0.90 * 0.90
                      + z4 * 1.00 * 1.00
                      + z5 * 1.15 * 1.15) / total
        let hours = total / 3600.0
        return hours * weighted * 100
    }

    private static func hasZoneData(_ zones: HRZones) -> Bool {
        let total = (zones.z1 ?? 0) + (zones.z2 ?? 0) + (zones.z3 ?? 0)
                  + (zones.z4 ?? 0) + (zones.z5 ?? 0)
        return total > 60
    }

    private static func sportDefaultPerHour(_ sport: Sport) -> Double {
        switch sport {
        case .run:      return 60
        case .bike:     return 55
        case .swim:     return 50
        case .hike:     return 40
        case .brick:    return 65
        case .strength: return 40
        case .other:    return 50
        }
    }

    // MARK: - Normalized Power
    //
    // Coggan NP: 30s rolling average of power, raised to the 4th power,
    // averaged, 4th-root taken. Approximates the metabolic cost of
    // variable-intensity efforts better than simple average power.

    private static func normalizedPower(from samples: [TimedSample]) -> Double? {
        guard samples.count >= 30 else { return nil }
        // Pull just the values; we assume samples are roughly 1s apart
        // (HK power streams typically are). For uneven streams the answer
        // is approximate but still better than avg power.
        let values = samples.map(\.v)

        // 30-second rolling mean.
        var rolling: [Double] = []
        rolling.reserveCapacity(values.count)
        var window = ArraySlice<Double>()
        var sum: Double = 0
        for (i, v) in values.enumerated() {
            sum += v
            if i >= 30 { sum -= values[i - 30] }
            let count = Swift.min(i + 1, 30)
            rolling.append(sum / Double(count))
        }

        // Mean of fourth powers.
        let fourthMean = rolling.reduce(0.0) { $0 + pow($1, 4) } / Double(rolling.count)
        return pow(fourthMean, 0.25)
    }

    // MARK: - Pace parsing
    //
    // Accepts "7:30/mi", "10:30 / mi", "1:25/100m", or a bare "7:30".
    // Returns the value in decimal minutes (e.g. 7.5 for 7:30). Sport-
    // specific unit handling (per mile vs per 100m) is the caller's
    // responsibility — the threshold value is stored in the same units.

    static func parsePace(_ paceStr: String?) -> Double? {
        guard let raw = paceStr?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
            return nil
        }
        // Strip everything after the first "/" or space (drops "/mi",
        // " / mi", "/100m", etc.) so we're left with M:SS or MM:SS.
        let head = raw.split(whereSeparator: { $0 == "/" || $0 == " " }).first ?? Substring(raw)
        let parts = head.split(separator: ":")
        guard parts.count == 2,
              let mins = Double(parts[0]),
              let secs = Double(parts[1]) else {
            return nil
        }
        return mins + secs / 60.0
    }
}
