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
