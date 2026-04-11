import Foundation

struct ExerciseSet: Codable {
    var setNum: Int
    var completed: Bool
    var weight: Double?
    var reps: Int?
    var duration: Double?
    var band: String?
}

struct Exercise: Codable, Identifiable {
    var id: String { name.slugified }
    var name: String
    var exerciseType: ExerciseType
    var sets: [ExerciseSet]
    var rest: Int?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case name, exerciseType, sets, rest, notes
    }
}

struct StrengthSession: Codable, Identifiable {
    let id: String
    var name: String
    var date: String
    var duration: Int?
    var exercises: [Exercise]
    var templateId: String?

    enum CodingKeys: String, CodingKey {
        case id, name, date, duration, exercises
        case templateId = "template_id"
    }

    static func create(name: String, exercises: [Exercise], date: String? = nil) -> StrengthSession {
        StrengthSession(
            id: UUID().uuidString,
            name: name,
            date: date ?? ISO8601DateFormatter.dateOnly.string(from: Date()),
            exercises: exercises
        )
    }
}
