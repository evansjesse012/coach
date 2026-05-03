import Foundation

/// Helpers for the Mon–Sun week window the weekly review and preview
/// artifacts are keyed by. All conversions use `Calendar.current` (device
/// locale) — single-user app, athlete's device is the source of truth
/// for "what day is it." If the athlete travels across time zones during
/// a week, `weekStartDate` follows whatever device they're using when
/// the review starts. Acceptable simplification per W1_PLAN.md.
enum WeekBoundary {

    /// `yyyy-MM-dd` of the Monday of the week containing `date`. If
    /// `date` is itself a Monday, returns that date.
    static func mondayString(of date: Date) -> String {
        Self.formatter.string(from: monday(of: date))
    }

    /// `yyyy-MM-dd` of the Sunday of the week containing `date`. Always
    /// `monday + 6 days`.
    static func sundayString(of date: Date) -> String {
        let sunday = Calendar.current.date(byAdding: .day, value: 6, to: monday(of: date))!
        return Self.formatter.string(from: sunday)
    }

    /// Monday of the prior week relative to `date`, as `yyyy-MM-dd`.
    /// Used when the trigger fires on Monday looking back at the week
    /// that just ended.
    static func priorMondayString(of date: Date) -> String {
        let priorMonday = Calendar.current.date(byAdding: .day, value: -7, to: monday(of: date))!
        return Self.formatter.string(from: priorMonday)
    }

    /// `yyyy-MM-dd` of the Monday of the week the weekly review/preview
    /// ritual considers "the week being reviewed" relative to `date`.
    /// Sundays review the week that just ended (today's Monday); any
    /// other day reviews the prior week. Used by
    /// `start_weekly_review_check_in` to default the review window.
    static func reviewWeekStartString(of date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date) // 1=Sun..7=Sat
        return weekday == 1 ? mondayString(of: date) : priorMondayString(of: date)
    }

    /// Date object for the Monday of the week containing `date`.
    static func monday(of date: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday — overrides the locale default (Sunday in en_US).
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: components)!
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()
}
