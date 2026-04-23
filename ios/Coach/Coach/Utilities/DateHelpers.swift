import Foundation

// MARK: - Date Formatting Helpers

extension ISO8601DateFormatter {
    /// Formats dates as YYYY-MM-DD only
    static let dateOnly: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return f
    }()
}

/// Format minutes as human-readable duration: "1h 30m", "45m"
func formatDuration(_ minutes: Int) -> String {
    let h = minutes / 60
    let m = minutes % 60
    if h > 0 {
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
    return "\(m)m"
}

/// Today's date as YYYY-MM-DD
func todayString() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
}

/// Formats a Date as YYYY-MM-DD in the system timezone. Prefer this over
/// `ISO8601DateFormatter.dateOnly.string(from:)` for app-internal plan
/// dates — ISO 8601's dateOnly formatter runs in UTC and can shift dates
/// by a day for users in western timezones seeding late in the evening.
func localDateString(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

/// Snaps a date to the Monday of its calendar week (Mon = day 0 …
/// Sun = day 6). No-op when the input is already a Monday. Used to keep
/// plan start dates aligned so week math is unambiguous — `plan.startDate
/// + (weekNum-1)*7 + dayIdx` always lands on the right weekday.
func mondayOf(_ date: Date) -> Date {
    let cal = Calendar.current
    let wd = cal.component(.weekday, from: date)   // Sun = 1, Mon = 2, ... Sat = 7
    guard wd != 2 else { return date }
    let shiftBack = (wd + 5) % 7                   // Mon → 0, Tue → 1, ... Sun → 6
    return cal.date(byAdding: .day, value: -shiftBack, to: date) ?? date
}

/// `yyyy-MM-dd` local date for the session at (weekNum, dayIdx) in a plan.
/// Monday-anchored: week N's day 0 is the Monday of the week containing
/// `planStart + (weekNum-1)*7`, so legacy plans with a non-Monday
/// `startDate` still line up Mon–Sun visually. Both `HomeTab`'s week card
/// and `WeekDetailView` route through this helper so their "today"
/// decisions agree. Returns nil if the plan has no `startDate`.
func sessionDateString(planStartDate: String?, weekNumber: Int, dayIdx: Int) -> String? {
    guard let startStr = planStartDate else { return nil }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let planStart = formatter.date(from: startStr) else { return nil }
    let cal = Calendar.current
    let raw = cal.date(byAdding: .day, value: (weekNumber - 1) * 7, to: planStart) ?? planStart
    let weekMonday = mondayOf(raw)
    guard let date = cal.date(byAdding: .day, value: dayIdx, to: weekMonday) else { return nil }
    return formatter.string(from: date)
}

/// Days between a date string and today
func daysUntil(_ dateStr: String) -> Int? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let target = formatter.date(from: dateStr) else { return nil }
    return Calendar.current.dateComponents([.day], from: Date(), to: target).day
}

/// Human-readable countdown: weeks when >= 7 days, days when < 7.
/// Returns nil if the date can't be parsed or is in the past.
func countdownText(_ dateStr: String, compact: Bool = false) -> String? {
    guard let days = daysUntil(dateStr), days >= 0 else { return nil }
    if days < 7 {
        return compact ? "\(days)d" : "\(days) days"
    }
    let weeks = days / 7
    return compact ? "\(weeks)w" : "\(weeks) weeks"
}

/// Short date format: "Mon Jan 5"
func formatDateShort(_ dateStr: String) -> String {
    let input = DateFormatter()
    input.dateFormat = "yyyy-MM-dd"
    guard let date = input.date(from: dateStr) else { return dateStr }
    let output = DateFormatter()
    output.dateFormat = "EEE MMM d"
    return output.string(from: date)
}

/// Long date with year: "Sun, Nov 15, 2026"
func formatDateLong(_ dateStr: String) -> String {
    let input = DateFormatter()
    input.dateFormat = "yyyy-MM-dd"
    guard let date = input.date(from: dateStr) else { return dateStr }
    let output = DateFormatter()
    output.dateFormat = "EEE, MMM d, yyyy"
    return output.string(from: date)
}

/// Full day + date: "Thursday, Apr 9"
func formatDayLong(_ dateStr: String) -> String {
    let input = DateFormatter()
    input.dateFormat = "yyyy-MM-dd"
    guard let date = input.date(from: dateStr) else { return dateStr }
    let output = DateFormatter()
    output.dateFormat = "EEEE, MMM d"
    return output.string(from: date)
}

/// Relative date: "Today", "Yesterday", "3 days ago", "Jan 5"
func formatDateRelative(_ dateStr: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let date = formatter.date(from: dateStr) else { return dateStr }
    let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    switch days {
    case 0: return "Today"
    case 1: return "Yesterday"
    case 2...6: return "\(days) days ago"
    default: return formatDateShort(dateStr)
    }
}
