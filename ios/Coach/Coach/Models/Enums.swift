import Foundation

// MARK: - Sport Types
enum Sport: String, Codable, CaseIterable, Identifiable {
    case run, bike, swim, strength, brick, hike, other
    var id: String { rawValue }

    var label: String {
        switch self {
        case .run: return "Run"
        case .bike: return "Bike"
        case .swim: return "Swim"
        case .strength: return "Strength"
        case .brick: return "Brick"
        case .hike: return "Hike"
        case .other: return "Other"
        }
    }

    var sfSymbol: String {
        switch self {
        case .run: return "figure.run"
        case .bike: return "bicycle"
        case .swim: return "figure.pool.swim"
        case .strength: return "dumbbell.fill"
        case .brick: return "arrow.triangle.2.circlepath"
        case .hike: return "figure.hiking"
        case .other: return "heart.fill"
        }
    }

    var color: String {
        switch self {
        case .run: return "accent"
        case .bike: return "cyan"
        case .swim: return "purple"
        case .strength: return "yellow"
        case .brick: return "green"
        case .hike: return "green"
        case .other: return "muted"
        }
    }
}

// MARK: - Exercise Types
enum ExerciseType: String, Codable, CaseIterable, Identifiable {
    case weighted, bodyweight, banded, timed, cardioDrill = "cardio-drill"
    var id: String { rawValue }

    var label: String {
        switch self {
        case .weighted: return "Weighted"
        case .bodyweight: return "Bodyweight"
        case .banded: return "Banded"
        case .timed: return "Timed"
        case .cardioDrill: return "Cardio Drill"
        }
    }
}

// MARK: - Nutrition Timing
enum NutritionTiming: String, Codable, CaseIterable, Identifiable {
    case pre, during, post, general
    var id: String { rawValue }

    var label: String { rawValue.capitalized }
}

// MARK: - Event Mode
enum EventMode: String, Codable, CaseIterable, Identifiable {
    case goal, race, pr
    var id: String { rawValue }
}

// MARK: - Appearance
enum Appearance: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

// MARK: - Coaching Personality
enum Personality: String, Codable, CaseIterable, Identifiable {
    case normal, goggins, hype, custom
    var id: String { rawValue }

    var label: String {
        switch self {
        case .normal: return "Head Coach"
        case .goggins: return "Goggins"
        case .hype: return "Hype Coach"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Session Priority
enum SessionPriority: String, Codable {
    case red, yellow
}

// MARK: - Effort Category (drives session dot color in plan UI)
enum EffortCategory: String, Codable, CaseIterable {
    case easy
    case recovery
    case tempo
    case threshold
    case longEndurance = "long_endurance"
    case vo2max
    case strength
    case race
    case rest

    var label: String {
        switch self {
        case .easy: return "Easy"
        case .recovery: return "Recovery"
        case .tempo: return "Tempo"
        case .threshold: return "Threshold"
        case .longEndurance: return "Long Endurance"
        case .vo2max: return "VO2 Max"
        case .strength: return "Strength"
        case .race: return "Race"
        case .rest: return "Rest"
        }
    }
}

// MARK: - Injury Status
enum InjuryStatus: String, Codable {
    case active, monitoring, resolved
}

// MARK: - Injury Severity
enum InjurySeverity: String, Codable {
    case mild, moderate, severe
    case unknown = ""
}
