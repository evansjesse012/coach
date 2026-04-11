import Foundation

struct CustomExercise: Codable, Identifiable {
    let id: Int?
    var name: String
    var bodyPart: String?
    var category: String?
    var exerciseType: ExerciseType

    enum CodingKeys: String, CodingKey {
        case id, name
        case bodyPart = "body_part"
        case category
        case exerciseType = "exercise_type"
    }
}
