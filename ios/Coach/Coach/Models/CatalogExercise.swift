import Foundation

/// A row from the global `exercises` catalog table (read-only, seeded).
struct CatalogExercise: Codable, Identifiable, Hashable {
    var id: String { slug }
    var slug: String
    var name: String
    var bodyPart: String
    var category: String
    var exerciseType: ExerciseType
    var primaryMuscles: [String]
    var secondaryMuscles: [String]
    var isBuiltIn: Bool
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case slug, name, category
        case bodyPart = "body_part"
        case exerciseType = "exercise_type"
        case primaryMuscles = "primary_muscles"
        case secondaryMuscles = "secondary_muscles"
        case isBuiltIn = "is_built_in"
        case sortOrder = "sort_order"
    }
}
