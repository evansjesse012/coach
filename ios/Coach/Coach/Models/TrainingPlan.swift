import Foundation

// MARK: - Phase Sub-Types

struct VolumeRange: Codable {
    var min: Double
    var max: Double
    var unit: String   // "hours" | "miles" | "km"
}

struct IntensityDistribution: Codable {
    var easy: Int       // % of weekly volume
    var tempo: Int
    var threshold: Int
    var vo2max: Int

    enum CodingKeys: String, CodingKey {
        case easy, tempo, threshold
        case vo2max = "vo2_max"
    }
}

struct KeyWorkout: Codable, Identifiable {
    var id: String { name }
    var name: String
    var description: String
}

// MARK: - Phase
struct TrainingPhase: Codable, Identifiable {
    var id: Int { number }
    var number: Int
    var name: String
    var startDate: String?
    var endDate: String?
    var weeks: Int
    var deloadWeek: Int?

    // Expert coach specifications (added after the model overhaul)
    var philosophy: String?
    var weeklyVolumeRange: VolumeRange?
    var sessionsPerWeek: Int?
    var intensityDistribution: IntensityDistribution?
    var keyWorkouts: [KeyWorkout]?
    var strengthFocus: String?
    var physiologicalGoals: [String]?
    var progressionRules: String?
    var raceSpecificNotes: String?

    // Legacy fields kept nullable so historical plan_history rows still decode
    var weeklyVolume: String?
    var intensityCeiling: String?
    var intensityMix: String?
    var strengthFreq: String?
    var focus: String?
    var keySessionTypes: [String]?

    // Legacy keys (startDate/endDate/etc.) stay in camelCase to remain
    // backward-compatible with seed data already in the DB. New fields
    // use snake_case to match the rest of our model conventions.
    enum CodingKeys: String, CodingKey {
        case number, name
        case startDate
        case endDate
        case weeks
        case deloadWeek
        case philosophy
        case weeklyVolumeRange = "weekly_volume_range"
        case sessionsPerWeek = "sessions_per_week"
        case intensityDistribution = "intensity_distribution"
        case keyWorkouts = "key_workouts"
        case strengthFocus = "strength_focus"
        case physiologicalGoals = "physiological_goals"
        case progressionRules = "progression_rules"
        case raceSpecificNotes = "race_specific_notes"
        case weeklyVolume
        case intensityCeiling
        case intensityMix
        case strengthFreq
        case focus
        case keySessionTypes
    }
}

// MARK: - Session Fuel
struct SessionFuel: Codable {
    var pre: String?
    var during: String?
    var post: String?
}

// MARK: - Prescribed Exercise
struct PrescribedExercise: Codable {
    var name: String
    var exerciseType: ExerciseType
    var sets: Int?
    var reps: Int?
    var weight: Double?
    var duration: Double?
    var band: String?
    var rest: Int?
    var notes: String?
}

// MARK: - Brick Leg
struct PrescribedBrickLeg: Codable {
    var sport: Sport
    var duration: Int?
    var zone: String?
}

// MARK: - Session
struct PrescribedSession: Codable, Identifiable {
    var id: String { "\(type)-\(label)" }
    var type: String       // sport name or "strength" or "brick"
    var label: String
    var duration: Int?
    var distanceMiles: Double?
    var effortCategory: EffortCategory?
    var zone: String?
    var targetIntensity: String?
    var purpose: String?
    var workout: String?
    var fuel: SessionFuel?
    var priority: SessionPriority?
    var notes: String?
    var exercises: [PrescribedExercise]?
    var legs: [PrescribedBrickLeg]?
    var templateId: String?

    // Legacy keys stay in camelCase for backward compat with existing JSONB.
    enum CodingKeys: String, CodingKey {
        case type, label, duration
        case distanceMiles = "distance_miles"
        case effortCategory = "effort_category"
        case zone
        case targetIntensity
        case purpose, workout, fuel, priority, notes, exercises, legs
        case templateId
    }
}

// MARK: - Day Plan
struct DayPlan: Codable, Identifiable {
    var id: String { day }
    var day: String
    var isRest: Bool?
    var sessions: [PrescribedSession]
}

// MARK: - Weekly Plan
struct WeeklyPlan: Codable, Identifiable {
    var id: Int { weekNumber }
    var weekNumber: Int
    var phase: Int?
    var focusOfWeek: String?
    var sessions: [DayPlan]
}

// MARK: - Training Plan
struct TrainingPlan: Codable, Identifiable {
    let id: String
    var goalId: String?
    var raceName: String?
    var raceDate: String?
    var startDate: String?
    var totalWeeks: Int
    var currentWeek: Int
    var currentPhase: Int
    var trainingDaysPerWeek: Int?
    var phases: [TrainingPhase]
    var weeklyPlans: [String: WeeklyPlan]

    enum CodingKeys: String, CodingKey {
        case id
        case goalId = "goal_id"
        case raceName = "race_name"
        case raceDate = "race_date"
        case startDate = "start_date"
        case totalWeeks = "total_weeks"
        case currentWeek = "current_week"
        case currentPhase = "current_phase"
        case trainingDaysPerWeek = "training_days_per_week"
        case phases
        case weeklyPlans = "weekly_plans"
    }

    static func create(
        goalId: String,
        raceName: String,
        raceDate: String,
        startDate: String,
        totalWeeks: Int,
        phases: [TrainingPhase]
    ) -> TrainingPlan {
        TrainingPlan(
            id: UUID().uuidString,
            goalId: goalId,
            raceName: raceName,
            raceDate: raceDate,
            startDate: startDate,
            totalWeeks: totalWeeks,
            currentWeek: 1,
            currentPhase: 1,
            phases: phases,
            weeklyPlans: [:]
        )
    }
}
