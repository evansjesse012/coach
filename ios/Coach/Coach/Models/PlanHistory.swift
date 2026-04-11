import Foundation

struct PlanHistory: Codable, Identifiable {
    let id: String
    var raceName: String?
    var goalId: String?
    var raceDate: String?
    var startDate: String?
    var endedDate: String?
    var totalWeeks: Int?
    var completedWeeks: Int?
    var totalPhases: Int?
    var phasesCompleted: Int?
    var phases: [TrainingPhase]?
    var endReason: String?
    var endNotes: String?
    var adherence: String?
    var weeklyAdherence: [String: Int]?

    enum CodingKeys: String, CodingKey {
        case id
        case raceName = "race_name"
        case goalId = "goal_id"
        case raceDate = "race_date"
        case startDate = "start_date"
        case endedDate = "ended_date"
        case totalWeeks = "total_weeks"
        case completedWeeks = "completed_weeks"
        case totalPhases = "total_phases"
        case phasesCompleted = "phases_completed"
        case phases
        case endReason = "end_reason"
        case endNotes = "end_notes"
        case adherence
        case weeklyAdherence = "weekly_adherence"
    }
}
