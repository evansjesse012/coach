import Foundation

// MARK: - Training Stress Score (TSS)

/// Calculates per-session TSS and rolling fitness/fatigue/form metrics.
///
/// TSS estimation hierarchy (best → fallback):
/// 1. HR zone distribution (weighted zone-time method)
/// 2. Average HR as intensity proxy
/// 3. Effort category from prescribed session
/// 4. Duration-only flat estimate
enum TrainingStressCalculator {

    // MARK: - Per-Session TSS

    /// TSS for a cardio workout. Uses the best available data.
    static func tss(for workout: CardioWorkout) -> Double {
        let hours = Double(workout.duration) / 60.0
        guard hours > 0 else { return 0 }

        // Best: HR zone distribution (seconds in each zone)
        if let zones = workout.hrZones, hasZoneData(zones) {
            return tssFromHRZones(zones, totalMinutes: workout.duration)
        }

        // Good: average HR as intensity proxy (assume max HR ~190 if unknown)
        if let avgHR = workout.avgHR, avgHR > 0 {
            let maxHR = Double(workout.maxHR ?? 190)
            let intensity = Double(avgHR) / maxHR
            // TSS ≈ duration_hours × intensity² × 100
            return hours * intensity * intensity * 100
        }

        // Fallback: sport-based estimate
        return tssFromSportEstimate(sport: workout.sport, minutes: workout.duration)
    }

    /// TSS for a strength session. Lower stress contribution than cardio.
    static func tss(forStrength session: StrengthSession) -> Double {
        let minutes = Double(session.duration ?? 45)
        // Strength contributes ~40 TSS/hour (moderate systemic stress)
        return (minutes / 60.0) * 40
    }

    /// TSS estimate from a prescribed session's effort category.
    static func tss(forPrescribed session: PrescribedSession) -> Double {
        let minutes = Double(session.duration ?? session.estimatedDurationMin ?? 40)
        let hours = minutes / 60.0
        guard hours > 0 else { return 0 }

        let tssPerHour: Double
        switch session.effortCategory {
        case .rest, .none:       tssPerHour = 0
        case .recovery:          tssPerHour = 30
        case .easy:              tssPerHour = 50
        case .longEndurance:     tssPerHour = 55
        case .tempo:             tssPerHour = 70
        case .strength:          tssPerHour = 40
        case .threshold:         tssPerHour = 90
        case .vo2max:            tssPerHour = 110
        case .race:              tssPerHour = 100
        }
        return hours * tssPerHour
    }

    // MARK: - HR Zone TSS

    /// Weighted zone-time method. Each zone contributes proportionally
    /// to its intensity factor squared.
    private static func tssFromHRZones(_ zones: HRZones, totalMinutes: Int) -> Double {
        let z1 = Double(zones.z1 ?? 0)  // seconds in Z1
        let z2 = Double(zones.z2 ?? 0)
        let z3 = Double(zones.z3 ?? 0)
        let z4 = Double(zones.z4 ?? 0)
        let z5 = Double(zones.z5 ?? 0)
        let total = z1 + z2 + z3 + z4 + z5
        guard total > 0 else {
            return tssFromSportEstimate(sport: .run, minutes: totalMinutes)
        }

        // Intensity factor per zone (fraction of threshold)
        // Z1=0.55, Z2=0.75, Z3=0.90, Z4=1.0, Z5=1.15
        let weighted = (z1 * 0.55 * 0.55
                      + z2 * 0.75 * 0.75
                      + z3 * 0.90 * 0.90
                      + z4 * 1.00 * 1.00
                      + z5 * 1.15 * 1.15) / total

        let hours = total / 3600.0
        return hours * weighted * 100
    }

    private static func hasZoneData(_ zones: HRZones) -> Bool {
        let total = (zones.z1 ?? 0) + (zones.z2 ?? 0) + (zones.z3 ?? 0) + (zones.z4 ?? 0) + (zones.z5 ?? 0)
        return total > 60 // at least 1 minute of zone data
    }

    // MARK: - Sport Estimate Fallback

    private static func tssFromSportEstimate(sport: Sport, minutes: Int) -> Double {
        let hours = Double(minutes) / 60.0
        let tssPerHour: Double
        switch sport {
        case .run:      tssPerHour = 60   // moderate Z2 run
        case .bike:     tssPerHour = 55   // moderate Z2 ride
        case .swim:     tssPerHour = 50   // steady swim
        case .hike:     tssPerHour = 40
        case .brick:    tssPerHour = 65
        case .strength: tssPerHour = 40
        case .other:    tssPerHour = 50
        }
        return hours * tssPerHour
    }

    // MARK: - Daily TSS Aggregation

    /// Aggregates all workouts into daily TSS totals, keyed by "yyyy-MM-dd".
    static func dailyTSS(
        cardio: [CardioWorkout],
        strength: [StrengthSession]
    ) -> [String: Double] {
        var daily: [String: Double] = [:]
        for w in cardio {
            daily[w.date, default: 0] += tss(for: w)
        }
        for s in strength {
            daily[s.date, default: 0] += tss(forStrength: s)
        }
        return daily
    }

    // MARK: - CTL / ATL / TSB Time Series

    struct FitnessDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let ctl: Double   // chronic training load (fitness)
        let atl: Double   // acute training load (fatigue)
        let tsb: Double   // training stress balance (form)
        let tss: Double   // that day's TSS
    }

    /// Computes the full CTL/ATL/TSB time series from workout data.
    /// Returns one data point per day from the earliest workout to today.
    static func fitnessTimeSeries(
        cardio: [CardioWorkout],
        strength: [StrengthSession]
    ) -> [FitnessDataPoint] {
        let daily = dailyTSS(cardio: cardio, strength: strength)
        guard !daily.isEmpty else { return [] }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        // Find date range
        let allDates = daily.keys.compactMap { fmt.date(from: $0) }
        guard let earliest = allDates.min() else { return [] }
        let today = Calendar.current.startOfDay(for: Date())

        // Walk day by day from earliest to today
        var ctl: Double = 0
        var atl: Double = 0
        var results: [FitnessDataPoint] = []
        var current = Calendar.current.startOfDay(for: earliest)

        while current <= today {
            let key = fmt.string(from: current)
            let dayTSS = daily[key] ?? 0

            // Exponentially weighted moving averages
            ctl = ctl + (dayTSS - ctl) / 42.0
            atl = atl + (dayTSS - atl) / 7.0
            let tsb = ctl - atl

            results.append(FitnessDataPoint(
                date: current,
                ctl: ctl,
                atl: atl,
                tsb: tsb,
                tss: dayTSS
            ))

            current = Calendar.current.date(byAdding: .day, value: 1, to: current)!
        }

        return results
    }

    // MARK: - Weekly Volume by Sport

    struct WeeklyVolume: Identifiable {
        let id = UUID()
        let weekStart: Date
        var runMinutes: Double = 0
        var bikeMinutes: Double = 0
        var swimMinutes: Double = 0
        var strengthMinutes: Double = 0
        var otherMinutes: Double = 0

        var totalMinutes: Double {
            runMinutes + bikeMinutes + swimMinutes + strengthMinutes + otherMinutes
        }
    }

    /// Groups workout duration by sport into weekly buckets.
    static func weeklyVolume(
        cardio: [CardioWorkout],
        strength: [StrengthSession]
    ) -> [WeeklyVolume] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let cal = Calendar.current

        func weekStart(for dateStr: String) -> Date? {
            guard let d = fmt.date(from: dateStr) else { return nil }
            return cal.dateInterval(of: .weekOfYear, for: d)?.start
        }

        var buckets: [Date: WeeklyVolume] = [:]

        for w in cardio {
            guard let ws = weekStart(for: w.date) else { continue }
            var vol = buckets[ws] ?? WeeklyVolume(weekStart: ws)
            let mins = Double(w.duration)
            switch w.sport {
            case .run:                vol.runMinutes += mins
            case .bike:               vol.bikeMinutes += mins
            case .swim:               vol.swimMinutes += mins
            case .strength:           vol.strengthMinutes += mins
            case .hike, .brick, .other: vol.otherMinutes += mins
            }
            buckets[ws] = vol
        }

        for s in strength {
            guard let ws = weekStart(for: s.date) else { continue }
            var vol = buckets[ws] ?? WeeklyVolume(weekStart: ws)
            vol.strengthMinutes += Double(s.duration ?? 45)
            buckets[ws] = vol
        }

        return buckets.values.sorted { $0.weekStart < $1.weekStart }
    }

    // MARK: - Weekly TSS

    struct WeeklyTSS: Identifiable {
        let id = UUID()
        let weekStart: Date
        let tss: Double
    }

    static func weeklyTSS(
        cardio: [CardioWorkout],
        strength: [StrengthSession]
    ) -> [WeeklyTSS] {
        let daily = dailyTSS(cardio: cardio, strength: strength)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let cal = Calendar.current

        var buckets: [Date: Double] = [:]
        for (dateStr, tss) in daily {
            guard let d = fmt.date(from: dateStr),
                  let ws = cal.dateInterval(of: .weekOfYear, for: d)?.start else { continue }
            buckets[ws, default: 0] += tss
        }

        return buckets.map { WeeklyTSS(weekStart: $0.key, tss: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }
    }

    // MARK: - Race Day Projection

    /// Projects TSB on race day assuming the athlete follows the plan.
    /// Uses current CTL/ATL and estimates remaining TSS from prescribed sessions.
    static func raceDayProjection(
        currentCTL: Double,
        currentATL: Double,
        plan: TrainingPlan?,
        events: [Event]
    ) -> (date: Date, projectedTSB: Double)? {
        guard let race = events.first(where: { $0.isRace && !$0.completed && $0.date != nil }),
              let dateStr = race.date else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let raceDate = fmt.date(from: dateStr) else { return nil }

        let today = Calendar.current.startOfDay(for: Date())
        let daysOut = Calendar.current.dateComponents([.day], from: today, to: raceDate).day ?? 0
        guard daysOut > 0 else { return nil }

        // Estimate average daily TSS from plan's prescribed sessions
        var avgDailyTSS: Double = 50  // default if no plan
        if let plan, let wp = plan.weeklyPlans[String(plan.currentWeek)] {
            let weekTSS = wp.sessions.flatMap(\.sessions).map { tss(forPrescribed: $0) }.reduce(0, +)
            avgDailyTSS = weekTSS / 7.0
        }

        // Simulate forward
        var ctl = currentCTL
        var atl = currentATL
        for day in 0..<daysOut {
            // Taper: reduce TSS in last 2 weeks
            let tssToday: Double
            if day >= daysOut - 14 {
                tssToday = avgDailyTSS * 0.5  // taper estimate
            } else {
                tssToday = avgDailyTSS
            }
            ctl = ctl + (tssToday - ctl) / 42.0
            atl = atl + (tssToday - atl) / 7.0
        }

        return (raceDate, ctl - atl)
    }
}
