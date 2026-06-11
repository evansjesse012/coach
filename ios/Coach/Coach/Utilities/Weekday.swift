import Foundation

// MARK: - Weekday

/// A day of the week, used as the anchor that defines where a training
/// week starts. Raw values are lowercase English day names ("monday") —
/// the same convention the plan generator's JSON and the coach tools use —
/// so the value round-trips cleanly through Codable, Supabase TEXT
/// columns, and LLM tool inputs.
///
/// The athlete's preferred anchor lives in `UserSettings.weekStartDay`;
/// each `TrainingPlan` freezes the anchor it was created with in
/// `TrainingPlan.weekStartDay`. Both default to Monday when absent so
/// every row written before this type existed keeps its original
/// behavior.
enum Weekday: String, Codable, CaseIterable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    /// `Calendar.component(.weekday, from:)` value: 1 = Sunday … 7 = Saturday.
    var calendarWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }

    init?(calendarWeekday: Int) {
        switch calendarWeekday {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        case 7: self = .saturday
        default: return nil
        }
    }

    /// "Monday", "Tuesday", …
    var displayName: String { rawValue.capitalized }

    /// Single-letter label for week strips ("M", "T", "W"…).
    var shortLetter: String {
        switch self {
        case .monday, .tuesday, .thursday: return String(displayName.prefix(1))
        case .wednesday: return "W"
        case .friday: return "F"
        case .saturday, .sunday: return "S"
        }
    }

    /// The weekday `days` after this one (wraps around the week).
    func advanced(by days: Int) -> Weekday {
        let idx = ((calendarWeekday - 1 + days) % 7 + 7) % 7 + 1
        return Weekday(calendarWeekday: idx)!
    }

    /// The day before this one — i.e. the *last* day of a week anchored
    /// on `self` (Sunday for a Monday-start week).
    var previous: Weekday { advanced(by: -1) }

    /// All 7 weekdays in week order starting from `self`. Index in this
    /// array == the `dayIdx` used throughout plan storage.
    var weekOrder: [Weekday] { (0..<7).map { advanced(by: $0) } }

    /// Single-letter labels in week order starting from `self`.
    var weekLetters: [String] { weekOrder.map(\.shortLetter) }
}
