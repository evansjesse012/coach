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

/// Snaps a date to the start of its week as defined by `anchor` (the
/// athlete's chosen week-start day — Monday for legacy plans). No-op when
/// the input is already on the anchor day. This is the ONLY week-snap in
/// the app: every surface that turns (week, day) into a calendar date
/// must route through this (usually via `sessionDateString`) so the
/// plan grid, adherence math, patch guard, and headers can never
/// disagree about what day a session falls on.
func weekStart(of date: Date, anchor: Weekday) -> Date {
    let cal = Calendar.current
    let wd = cal.component(.weekday, from: date)   // Sun = 1, Mon = 2, ... Sat = 7
    let shiftBack = (wd - anchor.calendarWeekday + 7) % 7
    guard shiftBack != 0 else { return date }
    return cal.date(byAdding: .day, value: -shiftBack, to: date) ?? date
}

/// Day index (0…6) of `now` within a week anchored on `anchor`.
/// 0 = the anchor day itself. This is the index into
/// `WeeklyPlan.sessions` for "today's" DayPlan.
func todayDayIndex(anchor: Weekday, now: Date = Date()) -> Int {
    (Calendar.current.component(.weekday, from: now) - anchor.calendarWeekday + 7) % 7
}

/// `yyyy-MM-dd` local date for the session at (weekNum, dayIdx) in a plan.
/// Anchor-snapped: week N's day 0 is the `anchor` weekday of the week
/// containing `planStart + (weekNum-1)*7`, so plans whose `startDate`
/// drifted off the anchor still line up visually. Every surface that
/// needs a session's date routes through this helper so their "today"
/// decisions agree. Returns nil if the plan has no `startDate`.
func sessionDateString(planStartDate: String?, weekNumber: Int, dayIdx: Int, anchor: Weekday) -> String? {
    guard let startStr = planStartDate else { return nil }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let planStart = formatter.date(from: startStr) else { return nil }
    let cal = Calendar.current
    let raw = cal.date(byAdding: .day, value: (weekNumber - 1) * 7, to: planStart) ?? planStart
    let start = weekStart(of: raw, anchor: anchor)
    guard let date = cal.date(byAdding: .day, value: dayIdx, to: start) else { return nil }
    return formatter.string(from: date)
}

/// First-to-last-day date range for a plan week, formatted as
/// "MMM d — MMM d" (e.g. "Apr 13 — Apr 19"). Uses the same anchor snap
/// as `sessionDateString` so the header text over a week strip agrees
/// with the per-day labels below it. Returns nil when the plan has no
/// `startDate` or the string can't be parsed.
func weekRangeLabel(planStartDate: String?, weekNumber: Int, anchor: Weekday) -> String? {
    guard let startStr = planStartDate else { return nil }
    let input = DateFormatter()
    input.dateFormat = "yyyy-MM-dd"
    guard let planStart = input.date(from: startStr) else { return nil }
    let cal = Calendar.current
    let raw = cal.date(byAdding: .day, value: (weekNumber - 1) * 7, to: planStart) ?? planStart
    let first = weekStart(of: raw, anchor: anchor)
    guard let last = cal.date(byAdding: .day, value: 6, to: first) else { return nil }
    let output = DateFormatter()
    output.dateFormat = "MMM d"
    return "\(output.string(from: first)) \u{2014} \(output.string(from: last))"
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
