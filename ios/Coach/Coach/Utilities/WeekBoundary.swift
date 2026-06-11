import Foundation

/// Helpers for the week window the weekly review and preview artifacts
/// are keyed by. The window is anchored on the athlete's chosen
/// week-start day (`UserSettings.weekAnchor`; Monday by default) — pass
/// that anchor explicitly so review keys, the check-in trigger window,
/// and the plan-week math all agree. All conversions use
/// `Calendar.current` (device locale) — single-user app, athlete's
/// device is the source of truth for "what day is it." If the athlete
/// travels across time zones during a week, `weekStartDate` follows
/// whatever device they're using when the review starts. Acceptable
/// simplification per W1_PLAN.md.
enum WeekBoundary {

    /// `yyyy-MM-dd` of the first day of the week containing `date`. If
    /// `date` is itself on the anchor day, returns that date.
    static func weekStartString(of date: Date, anchor: Weekday) -> String {
        Self.formatter.string(from: weekStart(of: date, anchor: anchor))
    }

    /// `yyyy-MM-dd` of the last day of the week containing `date`.
    /// Always `weekStart + 6 days`.
    static func weekEndString(of date: Date, anchor: Weekday) -> String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: weekStart(of: date, anchor: anchor))!
        return Self.formatter.string(from: end)
    }

    /// First day of the prior week relative to `date`, as `yyyy-MM-dd`.
    /// Used when the trigger fires on the first day of a new week
    /// looking back at the week that just ended.
    static func priorWeekStartString(of date: Date, anchor: Weekday) -> String {
        let prior = Calendar.current.date(byAdding: .day, value: -7, to: weekStart(of: date, anchor: anchor))!
        return Self.formatter.string(from: prior)
    }

    /// `yyyy-MM-dd` of the first day of the week the weekly
    /// review/preview ritual considers "the week being reviewed"
    /// relative to `date`. On the LAST day of the athlete's week
    /// (Sunday for a Monday anchor) we review the week that's ending
    /// today; any other day reviews the prior week. Used by
    /// `start_weekly_review_check_in` to default the review window.
    static func reviewWeekStartString(of date: Date, anchor: Weekday) -> String {
        let weekday = Calendar.current.component(.weekday, from: date) // 1=Sun..7=Sat
        return weekday == anchor.previous.calendarWeekday
            ? weekStartString(of: date, anchor: anchor)
            : priorWeekStartString(of: date, anchor: anchor)
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()
}
