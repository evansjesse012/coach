import Foundation

struct BrickLeg: Codable {
    var workoutId: String
}

struct Brick: Codable, Identifiable {
    let id: String
    var date: String
    var legs: [BrickLeg]
    var transitionTime: Int?
    var transitionNotes: String?

    enum CodingKeys: String, CodingKey {
        case id, date, legs
        case transitionTime = "transition_time"
        case transitionNotes = "transition_notes"
    }

    static func create(date: String, legs: [BrickLeg], transitionTime: Int? = nil) -> Brick {
        Brick(
            id: UUID().uuidString,
            date: date,
            legs: legs,
            transitionTime: transitionTime
        )
    }
}
