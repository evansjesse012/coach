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
    var estimatedDurationMin: Int?
    var estimatedDurationMax: Int?
    var distanceMiles: Double?
    var effortCategory: EffortCategory?
    var completed: Bool?
    var zone: String?
    var targetIntensity: String?
    var paceRange: String?         // e.g. "10:30-11:00/mi" — AI-computed from athlete benchmarks + zone
    var purpose: String?
    var workout: String?
    var fuel: SessionFuel?
    var priority: SessionPriority?
    var notes: String?
    var warning: String?           // yellow callout for injury-driven modifications
    var exercises: [PrescribedExercise]?
    var legs: [PrescribedBrickLeg]?
    var templateId: String?

    // Legacy keys stay in camelCase for backward compat with existing JSONB.
    enum CodingKeys: String, CodingKey {
        case type, label, duration
        case estimatedDurationMin = "estimated_duration_min"
        case estimatedDurationMax = "estimated_duration_max"
        case distanceMiles = "distance_miles"
        case effortCategory = "effort_category"
        case completed
        case zone
        case targetIntensity
        case paceRange = "pace_range"
        case purpose, workout, fuel, priority, notes, warning, exercises, legs
        case templateId
    }
}

// MARK: - Day Plan
struct DayPlan: Codable, Identifiable {
    var id: String { day }
    var day: String
    var isRest: Bool?
    var sessions: [PrescribedSession]
    var restNote: String?   // Personalized coach note for rest days (AI-generated)

    enum CodingKeys: String, CodingKey {
        case day, sessions
        case isRest
        case restNote = "rest_note"
    }
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

    // MARK: - Phase navigation helpers

    var current: TrainingPhase? {
        phases.first { $0.number == currentPhase }
    }

    func startWeek(for phase: TrainingPhase) -> Int {
        var sum = 1
        for p in phases.sorted(by: { $0.number < $1.number }) where p.number < phase.number {
            sum += p.weeks
        }
        return sum
    }

    func endWeek(for phase: TrainingPhase) -> Int {
        startWeek(for: phase) + phase.weeks - 1
    }

    /// 1-based position in the phase ("week 3 of 6").
    func weekIndexInPhase(_ phase: TrainingPhase) -> Int {
        max(1, currentWeek - startWeek(for: phase) + 1)
    }

    /// Days remaining until the phase's endDate, or nil if unknown.
    func daysRemainingInPhase(_ phase: TrainingPhase) -> Int? {
        guard let endStr = phase.endDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let endDate = formatter.date(from: endStr) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
        return max(0, days)
    }

    /// Weeks until race day from today, or nil if no raceDate.
    func weeksUntilRace() -> Int? {
        guard let raceStr = raceDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let raceDate = formatter.date(from: raceStr) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: raceDate).day ?? 0
        return max(0, Int((Double(days) / 7.0).rounded()))
    }

    /// Returns each phase paired with its proportional fraction of the total plan length.
    func phaseSegmentFractions() -> [(phase: TrainingPhase, fraction: Double)] {
        let total = phases.reduce(0) { $0 + $1.weeks }
        guard total > 0 else { return [] }
        return phases.sorted(by: { $0.number < $1.number }).map {
            ($0, Double($0.weeks) / Double(total))
        }
    }

    /// Counts weeks in a phase that have at least one explicitly-completed session.
    func completedWeeks(in phase: TrainingPhase) -> Int {
        let start = startWeek(for: phase)
        let end = endWeek(for: phase)
        return (start...end).filter { weekNum in
            guard let wp = weeklyPlans[String(weekNum)] else { return false }
            return wp.sessions.flatMap(\.sessions).contains(where: { $0.completed == true })
        }.count
    }
}
