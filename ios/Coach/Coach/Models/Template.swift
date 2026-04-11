import Foundation

struct Template: Codable, Identifiable {
    let id: String
    var name: String
    var exercises: [Exercise]
    var lastUsed: String?

    enum CodingKeys: String, CodingKey {
        case id, name, exercises
        case lastUsed = "last_used"
    }

    static func create(name: String, exercises: [Exercise]) -> Template {
        Template(
            id: UUID().uuidString,
            name: name,
            exercises: exercises
        )
    }
}
