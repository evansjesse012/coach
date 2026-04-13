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

/// A single coach tip. Stored either as a plain string (legacy) or as
/// a structured `{headline, detail}` object going forward. The custom
/// Codable implementation decodes both forms transparently.
struct CoachTip: Codable, Equatable, Hashable {
    var headline: String?
    var detail: String

    init(headline: String? = nil, detail: String) {
        self.headline = headline
        self.detail = detail
    }

    enum CodingKeys: String, CodingKey {
        case headline, detail
    }

    init(from decoder: Decoder) throws {
        // Legacy form: a plain string.
        if let single = try? decoder.singleValueContainer(),
           let raw = try? single.decode(String.self) {
            self.headline = nil
            self.detail = raw
            return
        }
        // New form: { headline, detail }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.headline = try container.decodeIfPresent(String.self, forKey: .headline)
        self.detail = try container.decodeIfPresent(String.self, forKey: .detail) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(headline, forKey: .headline)
        try container.encode(detail, forKey: .detail)
    }
}

struct AIConditions: Codable {
    var summary: String?
    var terrain: String?
    var elevation: String?
    var climate: String?

    // Short, one-line display values (5-8 words). When missing, the UI
    // falls back to truncating the longer detail fields above.
    var terrainShort: String?
    var elevationShort: String?
    var climateShort: String?

    var tips: [CoachTip]?

    enum CodingKeys: String, CodingKey {
        case summary, terrain, elevation, climate
        case terrainShort = "terrain_short"
        case elevationShort = "elevation_short"
        case climateShort = "climate_short"
        case tips
    }
}

struct Event: Codable, Identifiable {
    let id: String
    var presetId: String
    var name: String
    var date: String?
    var location: String?
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
        case name, date, location, mode, goal
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
