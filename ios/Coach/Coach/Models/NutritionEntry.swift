import Foundation

struct NutritionEntry: Codable, Identifiable {
    let id: String
    var meal: String
    var timing: NutritionTiming
    var relatedWorkout: String?
    var date: String

    enum CodingKeys: String, CodingKey {
        case id, meal, timing
        case relatedWorkout = "related_workout"
        case date
    }

    static func create(meal: String, timing: NutritionTiming, relatedWorkout: String? = nil, date: String? = nil) -> NutritionEntry {
        NutritionEntry(
            id: UUID().uuidString,
            meal: meal,
            timing: timing,
            relatedWorkout: relatedWorkout,
            date: date ?? ISO8601DateFormatter.dateOnly.string(from: Date())
        )
    }
}
