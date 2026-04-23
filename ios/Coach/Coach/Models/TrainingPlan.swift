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

    init(easy: Int, tempo: Int, threshold: Int, vo2max: Int) {
        self.easy = easy
        self.tempo = tempo
        self.threshold = threshold
        self.vo2max = vo2max
    }

    /// Tolerant decoder: accepts vo2_max / vo2max / vo2Max and defaults any
    /// missing field to 0 so a slightly-miscased field from the model doesn't
    /// kill the whole plan generation. Encoding still uses the CodingKeys
    /// (`vo2_max`) via the auto-synthesized encoder.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode([String: Int].self)
        easy = raw["easy"] ?? 0
        tempo = raw["tempo"] ?? 0
        threshold = raw["threshold"] ?? 0
        vo2max = raw["vo2_max"] ?? raw["vo2max"] ?? raw["vo2Max"] ?? 0
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

    /// Human-readable, athlete-facing phrasing of the phase, rendered on the
    /// Home screen week card in place of the technical `name`. Optional on
    /// the wire so the plan generator / coach can override per-phase; when
    /// absent the client falls back to `Self.plainLanguageFallbacks`.
    var plainLanguageDescription: String?

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
        case plainLanguageDescription = "plain_language_description"
        case weeklyVolume
        case intensityCeiling
        case intensityMix
        case strengthFreq
        case focus
        case keySessionTypes
    }
}

// MARK: - Plain-language phase labels

extension TrainingPhase {
    /// Client-side fallback mapping from technical phase `name` to athlete-facing
    /// description. Used when the server hasn't supplied `plainLanguageDescription`.
    /// Keys are lowercased for case-insensitive match. Add new phase types here.
    static let plainLanguageFallbacks: [String: String] = [
        "aerobic foundation":  "Building your aerobic base",
        "base":                "Building your aerobic base",
        "base development":    "Growing your weekly volume",
        "build":               "Introducing race-intensity work",
        "build 1":             "Introducing race-intensity work",
        "build 2":             "Race-specific peak training",
        "peak":                "Race-specific peak training",
        "race-specific peak":  "Race-specific peak training",
        "taper":               "Tapering for race day",
        "recovery":            "Recovering and rebuilding",
        "transition":          "Between training cycles",
    ]

    /// Athlete-facing phase label for the Home screen. Prefers the server-supplied
    /// override, then the fallback table, then the technical name as a last resort
    /// so we never show an empty line.
    var plainLanguageLabel: String {
        if let override = plainLanguageDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            return override
        }
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return Self.plainLanguageFallbacks[key] ?? name
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

    init(
        name: String,
        exerciseType: ExerciseType,
        sets: Int? = nil,
        reps: Int? = nil,
        weight: Double? = nil,
        duration: Double? = nil,
        band: String? = nil,
        rest: Int? = nil,
        notes: String? = nil
    ) {
        self.name = name
        self.exerciseType = exerciseType
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.duration = duration
        self.band = band
        self.rest = rest
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case name, exerciseType, sets, reps, weight, duration, band, rest, notes
    }

    /// Tolerant decoder: the plan generator's model sometimes emits numeric
    /// fields as strings ("35" or "35 lb" instead of 35). Accept either and
    /// parse as best we can. encode(to:) stays auto-synthesized so we keep
    /// writing numbers as numbers.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        exerciseType = try c.decode(ExerciseType.self, forKey: .exerciseType)
        sets = c.decodeTolerantInt(forKey: .sets)
        reps = c.decodeTolerantInt(forKey: .reps)
        weight = c.decodeTolerantDouble(forKey: .weight)
        duration = c.decodeTolerantDouble(forKey: .duration)
        band = try c.decodeIfPresent(String.self, forKey: .band)
        rest = c.decodeTolerantInt(forKey: .rest)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
    }
}

// MARK: - Brick Leg
struct PrescribedBrickLeg: Codable {
    var sport: Sport
    var duration: Int?
    var zone: String?
}

// MARK: - Completion Status

/// Richer completion state than the legacy `completed: Bool?`.
/// `nil` means pending (the session exists but hasn't been resolved yet).
enum CompletionStatus: String, Codable {
    case completed
    case modified
    case swapped
    case skipped
}

enum SkipReason: String, Codable {
    case fatigue
    case time
    case soreness
    case life
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
    var completed: Bool?           // Legacy boolean flag. New code uses completionStatus.
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

    // Completion record. Phase 1 added manual marking; Phase 2 adds
    // HealthKit-driven auto-matching which can mark a session as completed
    // with a needsReview flag for medium-confidence matches.
    var completionStatus: CompletionStatus?
    var actualDuration: Int?
    var actualDistance: Double?
    var actualSport: String?           // For swapped: what the athlete actually did
    var skipReason: SkipReason?
    var completionNote: String?
    var completionResolvedAt: String?  // ISO timestamp when marked
    var completionNeedsReview: Bool?   // true for medium-confidence HK auto-matches
    var linkedWorkoutId: String?       // Explicit CardioWorkout.id link, set by auto- or manual-match

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
        case completionStatus = "completion_status"
        case actualDuration = "actual_duration"
        case actualDistance = "actual_distance"
        case actualSport = "actual_sport"
        case skipReason = "skip_reason"
        case completionNote = "completion_note"
        case completionResolvedAt = "completion_resolved_at"
        case completionNeedsReview = "completion_needs_review"
        case linkedWorkoutId = "linked_workout_id"
    }
}

// MARK: - Display State

/// Collapses completionStatus + legacy `completed` + needsReview into a single
/// value the UI can switch on when drawing a session row/card.
enum PrescribedSessionDisplayState {
    case upcoming
    case completed
    case needsReview
    case modified
    case swapped
    case skipped
}

extension PrescribedSession {
    var displayState: PrescribedSessionDisplayState {
        if let status = completionStatus {
            switch status {
            case .completed:
                return completionNeedsReview == true ? .needsReview : .completed
            case .modified:
                return .modified
            case .swapped:
                return .swapped
            case .skipped:
                return .skipped
            }
        }
        // Legacy flag fallback for plans saved before Phase 1.
        if completed == true { return .completed }
        return .upcoming
    }

    var isResolved: Bool {
        completionStatus != nil || completed == true
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

    /// A stub week has only a focus + phase recorded — no actual daily
    /// sessions yet. Created by plan generation for every week past the
    /// current one, then filled in lazily via TrainingPlanGenerator.generateWeek.
    var isStub: Bool {
        sessions.isEmpty
    }
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

    /// Whole weeks remaining after the current week in the given phase. The
    /// current week is the last week when this returns 0 ("last week of phase").
    func weeksLeftInPhase(_ phase: TrainingPhase) -> Int {
        max(0, phase.weeks - weekIndexInPhase(phase))
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

    /// Phase number that contains the given 1-based plan week, walking
    /// phases in `number` order and summing `weeks`. Returns nil when the
    /// week is outside the plan's range.
    func phaseNumber(forWeek weekNumber: Int) -> Int? {
        guard weekNumber >= 1 else { return nil }
        var cursor = 0
        for phase in phases.sorted(by: { $0.number < $1.number }) {
            let phaseStart = cursor + 1
            let phaseEnd = cursor + phase.weeks
            if weekNumber >= phaseStart && weekNumber <= phaseEnd {
                return phase.number
            }
            cursor = phaseEnd
        }
        return nil
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

// MARK: - Tolerant decoders for model-generated numeric fields

/// When Claude generates plan JSON it occasionally wraps numeric fields in
/// quotes (e.g. `"weight": "35"` or `"weight": "35 lb"` instead of
/// `"weight": 35`). These helpers accept both shapes so a single field slip
/// doesn't blow up the whole decode and force a retry.
extension KeyedDecodingContainer {
    /// Decode a Double-valued optional field, tolerating:
    ///   - `"weight": 35` (number)
    ///   - `"weight": 35.5` (fractional number)
    ///   - `"weight": "35"` (quoted number)
    ///   - `"weight": "35 lb"` (number with trailing unit)
    ///   - key missing / null / wrong type → `nil`
    func decodeTolerantDouble(forKey key: Key) -> Double? {
        if let d = try? decode(Double.self, forKey: key) { return d }
        if let i = try? decode(Int.self, forKey: key) { return Double(i) }
        if let s = try? decode(String.self, forKey: key) {
            let cleaned = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty { return nil }
            if let d = Double(cleaned) { return d }
            // Strip trailing units like " lb" / "kg".
            let numericPart = cleaned.prefix { $0.isNumber || $0 == "." || $0 == "-" }
            return Double(numericPart)
        }
        return nil
    }

    /// Decode an Int-valued optional field with the same tolerance rules.
    /// Fractional numbers are truncated toward zero.
    func decodeTolerantInt(forKey key: Key) -> Int? {
        if let i = try? decode(Int.self, forKey: key) { return i }
        if let d = try? decode(Double.self, forKey: key) { return Int(d) }
        if let s = try? decode(String.self, forKey: key) {
            let cleaned = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty { return nil }
            if let i = Int(cleaned) { return i }
            if let d = Double(cleaned) { return Int(d) }
            let numericPart = cleaned.prefix { $0.isNumber || $0 == "-" }
            return Int(numericPart)
        }
        return nil
    }
}
