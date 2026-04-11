import Foundation

struct HRZones: Codable {
    var z1: Int?
    var z2: Int?
    var z3: Int?
    var z4: Int?
    var z5: Int?

    enum CodingKeys: String, CodingKey {
        case z1 = "Z1"
        case z2 = "Z2"
        case z3 = "Z3"
        case z4 = "Z4"
        case z5 = "Z5"
    }
}

struct CardioWorkout: Codable, Identifiable {
    let id: String
    var sport: Sport
    var duration: Int
    var distance: String?
    var pace: String?
    var avgHR: Int?
    var maxHR: Int?
    var calories: Int?
    var avgPower: Int?
    var hrZones: HRZones?
    var notes: String?
    var date: String
    var startTime: String?
    var endTime: String?
    var location: String?
    var source: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sport
        case duration
        case distance
        case pace
        case avgHR = "avg_hr"
        case maxHR = "max_hr"
        case calories
        case avgPower = "avg_power"
        case hrZones = "hr_zones"
        case notes
        case date
        case startTime = "start_time"
        case endTime = "end_time"
        case location
        case source
    }

    static func create(sport: Sport, duration: Int, notes: String? = nil, date: String? = nil) -> CardioWorkout {
        CardioWorkout(
            id: UUID().uuidString,
            sport: sport,
            duration: duration,
            notes: notes,
            date: date ?? ISO8601DateFormatter.dateOnly.string(from: Date()),
            source: "manual"
        )
    }
}
