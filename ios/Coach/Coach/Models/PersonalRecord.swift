import Foundation

struct PRHistoryEntry: Codable {
    var weight: Double?
    var reps: Int?
    var estimated1RM: Double?
    var duration: Double?
    var band: String?
    var date: String
}

struct PersonalRecord: Codable, Identifiable {
    var id: String { exerciseSlug }
    var exerciseSlug: String
    var exerciseType: ExerciseType
    var weight: Double?
    var reps: Int?
    var estimated1RM: Double?
    var bestReps: Int?
    var bestDuration: Double?
    var band: String?
    var date: String?
    var history: [PRHistoryEntry]

    enum CodingKeys: String, CodingKey {
        case exerciseSlug = "exercise_slug"
        case exerciseType = "exercise_type"
        case weight, reps
        case estimated1RM = "estimated_1rm"
        case bestReps = "best_reps"
        case bestDuration = "best_duration"
        case band, date, history
    }
}
