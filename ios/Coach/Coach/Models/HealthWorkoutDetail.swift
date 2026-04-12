import Foundation

// MARK: - Top-level rich workout payload

struct HealthWorkoutDetail: Codable {
    var startTime: String      // ISO8601
    var endTime: String
    var indoor: Bool?

    var stats: WorkoutStats
    var hrSamples: [TimedSample]?
    var powerSamples: [TimedSample]?
    var cadenceSamples: [TimedSample]?
    var speedSamples: [TimedSample]?

    var hrZones: HRZoneBreakdown?
    var laps: [LapSplit]?
    var events: [WorkoutEvent]?
    var subActivities: [SubActivity]?

    var source: SourceInfo?
    var weather: WeatherSnapshot?
    var metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case indoor, stats
        case hrSamples = "hr_samples"
        case powerSamples = "power_samples"
        case cadenceSamples = "cadence_samples"
        case speedSamples = "speed_samples"
        case hrZones = "hr_zones"
        case laps, events
        case subActivities = "sub_activities"
        case source, weather, metadata
    }
}

// MARK: - Stats

struct WorkoutStats: Codable {
    var avgHR: Int?
    var maxHR: Int?
    var minHR: Int?
    var totalEnergy: Int?      // kcal
    var totalDistance: Double? // meters
    var avgPower: Int?
    var maxPower: Int?
    var avgCadence: Int?
    var avgSpeed: Double?      // m/s
    var elevationGain: Double? // meters
    var swimStrokes: Int?
    var flightsClimbed: Int?

    enum CodingKeys: String, CodingKey {
        case avgHR = "avg_hr"
        case maxHR = "max_hr"
        case minHR = "min_hr"
        case totalEnergy = "total_energy"
        case totalDistance = "total_distance"
        case avgPower = "avg_power"
        case maxPower = "max_power"
        case avgCadence = "avg_cadence"
        case avgSpeed = "avg_speed"
        case elevationGain = "elevation_gain"
        case swimStrokes = "swim_strokes"
        case flightsClimbed = "flights_climbed"
    }
}

// MARK: - Time series sample

/// Compact timed sample: `t` is unix epoch seconds, `v` is the value.
struct TimedSample: Codable {
    var t: Double
    var v: Double
}

// MARK: - HR Zones (time-in-zone, seconds)

struct HRZoneBreakdown: Codable {
    var z1: Int
    var z2: Int
    var z3: Int
    var z4: Int
    var z5: Int
}

// MARK: - Laps

struct LapSplit: Codable, Identifiable {
    var id: Int { index }
    var index: Int
    var startTime: String
    var duration: Double      // seconds
    var distance: Double?     // meters
    var avgHR: Int?
    var avgPace: Double?      // seconds per km

    enum CodingKeys: String, CodingKey {
        case index
        case startTime = "start_time"
        case duration, distance
        case avgHR = "avg_hr"
        case avgPace = "avg_pace"
    }
}

// MARK: - Workout events (pause, resume, segment marker, etc.)

struct WorkoutEvent: Codable {
    var type: String
    var time: String          // ISO8601
    var duration: Double?
}

// MARK: - Multi-sport sub-activity

struct SubActivity: Codable {
    var sport: String
    var startTime: String
    var endTime: String
    var stats: WorkoutStats

    enum CodingKeys: String, CodingKey {
        case sport
        case startTime = "start_time"
        case endTime = "end_time"
        case stats
    }
}

// MARK: - Source

struct SourceInfo: Codable {
    var app: String?
    var device: String?
    var version: String?
}

// MARK: - Weather

struct WeatherSnapshot: Codable {
    var tempC: Double?
    var humidity: Double?
    var conditions: String?

    enum CodingKeys: String, CodingKey {
        case tempC = "temp_c"
        case humidity, conditions
    }
}

// MARK: - Route summary (lives in cardio_workouts.route_summary JSONB)

struct RouteSummary: Codable {
    var points: [RoutePoint]    // downsampled (~100 points)
    var bbox: BoundingBox
    var pointCount: Int         // total in full route stored in Storage
    var distance: Double?       // meters
    var elevationGain: Double?  // meters

    struct BoundingBox: Codable {
        var minLat: Double
        var minLng: Double
        var maxLat: Double
        var maxLng: Double

        enum CodingKeys: String, CodingKey {
            case minLat = "min_lat"
            case minLng = "min_lng"
            case maxLat = "max_lat"
            case maxLng = "max_lng"
        }
    }

    enum CodingKeys: String, CodingKey {
        case points, bbox
        case pointCount = "point_count"
        case distance
        case elevationGain = "elevation_gain"
    }
}

// MARK: - Route point (used in summary and full GeoJSON)

struct RoutePoint: Codable {
    var lat: Double
    var lng: Double
    var alt: Double?     // meters
    var t: Double?       // unix epoch seconds
    var speed: Double?   // m/s
}
