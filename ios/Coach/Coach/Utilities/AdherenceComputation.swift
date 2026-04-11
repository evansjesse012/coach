import Foundation

// MARK: - Session Status

enum SessionStatus: String {
    case completed, shortened, missed, substituted, today, upcoming
}

// MARK: - Session Review

struct SessionReview {
    var type: String
    var label: String
    var duration: Int?
    var status: SessionStatus
    var actualDuration: Int?
    var substitute: String?
    var dateStr: String
}

// MARK: - Day Review

struct DayReview {
    var day: String
    var dateStr: String
    var isPast: Bool
    var isToday: Bool
    var isRest: Bool
    var sessions: [SessionReview]
}

// MARK: - Week Adherence Result

struct WeekAdherence {
    var weekNumber: Int
    var days: [DayReview]
    var prescribed: Int
    var completed: Int
    var shortened: Int
    var missed: Int
    var substituted: Int
    var adherence: Int           // 0-100 percentage
    var missedByType: [String: Int]
}

// MARK: - Compute Week Adherence

/// Port of computeWeekAdherence from page.jsx lines 382-437
func computeWeekAdherence(
    plan: TrainingPlan,
    weekNum: Int,
    cardio: [CardioWorkout],
    strength: [StrengthSession]
) -> WeekAdherence? {
    guard let wp = plan.weeklyPlans[String(weekNum)],
          let startDateStr = plan.startDate else { return nil }

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let planStart = formatter.date(from: startDateStr) else { return nil }

    let calendar = Calendar.current

    // Calculate the Monday of the target week
    var weekMonday = calendar.date(byAdding: .day, value: (weekNum - 1) * 7, to: planStart)!
    let startDay = calendar.component(.weekday, from: weekMonday)
    if startDay != 2 { // 2 = Monday
        weekMonday = calendar.date(byAdding: .day, value: -((startDay + 5) % 7), to: weekMonday)!
    }

    let todayStr = todayString()

    let days: [DayReview] = wp.sessions.enumerated().map { (di, dayObj) in
        let dayDate = calendar.date(byAdding: .day, value: di, to: weekMonday)!
        let dateStr = formatter.string(from: dayDate)
        let isPast = dateStr < todayStr
        let isToday = dateStr == todayStr

        let dayCardio = cardio.filter { $0.date == dateStr }
        let dayStrength = strength.filter { $0.date == dateStr }

        let sessions: [SessionReview] = dayObj.sessions.map { sess in
            let isStr = sess.type == "strength"

            if isStr {
                let match = dayStrength.first { $0.name == sess.label || $0.templateId == sess.templateId }
                if let match {
                    return SessionReview(type: sess.type, label: sess.label, duration: sess.duration, status: .completed, actualDuration: match.duration, dateStr: dateStr)
                }
                return SessionReview(type: sess.type, label: sess.label, duration: sess.duration, status: isPast ? .missed : .upcoming, dateStr: dateStr)
            }

            // Cardio matching
            if let match = dayCardio.first(where: { $0.sport.rawValue == sess.type }) {
                let ratio = sess.duration.map { Double(match.duration) / Double($0) } ?? 1.0
                let status: SessionStatus = ratio >= 0.8 ? .completed : .shortened
                return SessionReview(type: sess.type, label: sess.label, duration: sess.duration, status: status, actualDuration: match.duration, dateStr: dateStr)
            }

            // Check for substitution
            let anySport = !dayCardio.isEmpty
            if isPast && anySport {
                return SessionReview(type: sess.type, label: sess.label, duration: sess.duration, status: .substituted, substitute: dayCardio.first?.sport.rawValue, dateStr: dateStr)
            }

            return SessionReview(
                type: sess.type, label: sess.label, duration: sess.duration,
                status: isPast ? .missed : (isToday ? .today : .upcoming),
                dateStr: dateStr
            )
        }

        return DayReview(day: dayObj.day, dateStr: dateStr, isPast: isPast, isToday: isToday, isRest: dayObj.isRest ?? false, sessions: sessions)
    }

    let allSessions = days.flatMap(\.sessions)
    let prescribed = allSessions.count
    let completed = allSessions.filter { $0.status == .completed }.count
    let shortened = allSessions.filter { $0.status == .shortened }.count
    let missed = allSessions.filter { $0.status == .missed }.count
    let substituted = allSessions.filter { $0.status == .substituted }.count

    var missedByType: [String: Int] = [:]
    allSessions.filter { $0.status == .missed }.forEach { s in
        missedByType[s.type, default: 0] += 1
    }

    let adherence = prescribed > 0 ? Int(round(Double(completed) + Double(shortened) * 0.5) / Double(prescribed) * 100) : 100

    return WeekAdherence(
        weekNumber: weekNum,
        days: days,
        prescribed: prescribed,
        completed: completed,
        shortened: shortened,
        missed: missed,
        substituted: substituted,
        adherence: adherence,
        missedByType: missedByType
    )
}

// MARK: - Multi-Week Patterns

/// Port of computeMultiWeekPatterns from page.jsx lines 439-465
func computeMultiWeekPatterns(
    plan: TrainingPlan,
    currentWeek: Int,
    cardio: [CardioWorkout],
    strength: [StrengthSession],
    lookback: Int = 4
) -> [String] {
    var patterns: [String] = []
    var weekReviews: [WeekAdherence] = []

    for w in max(1, currentWeek - lookback)..<currentWeek {
        if let review = computeWeekAdherence(plan: plan, weekNum: w, cardio: cardio, strength: strength) {
            weekReviews.append(review)
        }
    }

    guard !weekReviews.isEmpty else { return patterns }

    // Detect sport-specific miss patterns
    var sportMissCounts: [String: Int] = [:]
    for review in weekReviews {
        for (sport, count) in review.missedByType {
            sportMissCounts[sport, default: 0] += count
        }
    }

    for (sport, count) in sportMissCounts {
        let weeksWithMiss = weekReviews.filter { $0.missedByType[sport] != nil }.count
        if weeksWithMiss >= 2 {
            patterns.append("\(sport) missed in \(weeksWithMiss) of last \(weekReviews.count) weeks (\(count) total sessions)")
        }
    }

    // Detect adherence trend
    let adherences = weekReviews.map(\.adherence)
    if adherences.count >= 3 {
        let recent = adherences.suffix(2)
        let earlier = adherences.dropLast(2)
        let recentAvg = Double(recent.reduce(0, +)) / Double(recent.count)
        let earlierAvg = Double(earlier.reduce(0, +)) / Double(earlier.count)
        if recentAvg < earlierAvg - 15 {
            patterns.append("Adherence declining: \(Int(earlierAvg))% → \(Int(recentAvg))%")
        }
        if recentAvg > earlierAvg + 15 {
            patterns.append("Adherence improving: \(Int(earlierAvg))% → \(Int(recentAvg))%")
        }
    }

    return patterns
}
