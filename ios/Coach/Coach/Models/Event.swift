import Foundation

struct EventSplits: Codable {
    var swim: String?
    var t1: String?
    var bike: String?
    var t2: String?
    var run: String?
    var total: String?
}

struct RacePlanSections: Codable {
    var strategy: String?
    var nutrition: String?
    var pacing: String?
    var gear: String?
    var mentalPlan: String?
}

struct AIConditions: Codable {
    var summary: String?
    var terrain: String?
    var elevation: String?
    var climate: String?
    var tips: [String]?
}

struct Event: Codable, Identifiable {
    let id: String
    var presetId: String
    var name: String
    var date: String?
    var location: String?
    var distance: String?
    var mode: EventMode
    var goal: String?
    var stretchGoal: String?
    var baseline: String?
    var result: String?
    var completed: Bool
    var notes: [String]
    var splits: EventSplits?
    var bibNumber: String?
    var ageGroup: String?
    var placement: String?
    var genderPlacement: String?
    var ageGroupPlacement: String?
    var planSections: RacePlanSections?
    var aiConditions: AIConditions?
    var linkedRaceId: String?
    var url: String?

    enum CodingKeys: String, CodingKey {
        case id
        case presetId = "preset_id"
        case name, date, location, distance, mode, goal
        case stretchGoal = "stretch_goal"
        case baseline, result, completed, notes, splits
        case bibNumber = "bib_number"
        case ageGroup = "age_group"
        case placement
        case genderPlacement = "gender_placement"
        case ageGroupPlacement = "age_group_placement"
        case planSections = "plan_sections"
        case aiConditions = "ai_conditions"
        case linkedRaceId = "linked_race_id"
        case url
    }

    static func create(presetId: String, name: String, mode: EventMode = .goal) -> Event {
        Event(
            id: UUID().uuidString,
            presetId: presetId,
            name: name,
            mode: mode,
            completed: false,
            notes: []
        )
    }
}
