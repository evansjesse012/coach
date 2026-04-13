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

/// A chip-style stat value (terrain/elevation/climate). Can decode from
/// either a plain string (legacy) or a {short, detail} object (current).
struct StatValue: Codable, Hashable {
    var short: String
    var detail: String?

    init(short: String, detail: String? = nil) {
        self.short = short
        self.detail = detail
    }

    init(from decoder: Decoder) throws {
        // Legacy path: plain string — treat the full string as detail,
        // compact it into a short summary for display.
        if let s = try? decoder.singleValueContainer().decode(String.self) {
            self.short = StatValue.compactShort(from: s)
            self.detail = s
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.short = try c.decode(String.self, forKey: .short)
        self.detail = try c.decodeIfPresent(String.self, forKey: .detail)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(short, forKey: .short)
        try c.encodeIfPresent(detail, forKey: .detail)
    }

    private enum CodingKeys: String, CodingKey {
        case short, detail
    }

    /// First sentence or 40-char truncation, for legacy plain-string values.
    static func compactShort(from fullText: String) -> String {
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstPeriod = trimmed.firstIndex(of: ".") {
            let candidate = String(trimmed[..<firstPeriod])
            if candidate.count <= 60 { return candidate }
        }
        if trimmed.count <= 40 { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: 40)
        return String(trimmed[..<end]) + "…"
    }
}

/// A ranked coach tip. Can decode from either a plain string (legacy) or
/// a {headline, detail} object (current).
struct TipValue: Codable, Hashable {
    var headline: String?
    var detail: String

    init(headline: String? = nil, detail: String) {
        self.headline = headline
        self.detail = detail
    }

    init(from decoder: Decoder) throws {
        if let s = try? decoder.singleValueContainer().decode(String.self) {
            self.headline = nil
            self.detail = s
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.headline = try c.decodeIfPresent(String.self, forKey: .headline)
        self.detail = try c.decode(String.self, forKey: .detail)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(headline, forKey: .headline)
        try c.encode(detail, forKey: .detail)
    }

    private enum CodingKeys: String, CodingKey {
        case headline, detail
    }
}

struct AIConditions: Codable {
    var summary: String?
    var terrain: StatValue?
    var elevation: StatValue?
    var climate: StatValue?
    var tips: [TipValue]?
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
    var weatherData: WeatherData?
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
        case weatherData = "weather_data"
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
