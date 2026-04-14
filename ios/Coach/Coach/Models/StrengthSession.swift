import Foundation

struct ExerciseSet: Codable {
    var setNum: Int
    var completed: Bool
    var weight: Double?
    var reps: Int?
    var duration: Double?
    var band: String?
}

struct Exercise: Codable, Identifiable {
    var id: String { name.slugified }
    var name: String
    var exerciseType: ExerciseType
    var sets: [ExerciseSet]
    var rest: Int?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case name, exerciseType, sets, rest, notes
    }
}

struct StrengthSession: Codable, Identifiable {
    let id: String
    var name: String
    var date: String
    var duration: Int?
    var exercises: [Exercise]
    var templateId: String?

    enum CodingKeys: String, CodingKey {
        case id, name, date, duration, exercises
        case templateId = "template_id"
    }

    static func create(name: String, exercises: [Exercise], date: String? = nil) -> StrengthSession {
        StrengthSession(
            id: UUID().uuidString,
            name: name,
            date: date ?? ISO8601DateFormatter.dateOnly.string(from: Date()),
            exercises: exercises
        )
    }

    /// Build a loggable session from a plan-prescribed strength session.
    /// Each PrescribedExercise's `sets: Int?` gets expanded into that many
    /// empty ExerciseSet rows pre-filled with the prescribed targets, ready
    /// for the athlete to check off during the workout.
    static func fromPrescribed(
        _ prescribed: PrescribedSession,
        date: String? = nil,
        templateId: String? = nil
    ) -> StrengthSession {
        let exercises = (prescribed.exercises ?? []).map { Exercise.fromPrescribed($0) }
        return StrengthSession(
            id: UUID().uuidString,
            name: prescribed.label,
            date: date ?? todayString(),
            duration: nil,
            exercises: exercises,
            templateId: templateId ?? prescribed.templateId
        )
    }

    /// Build a loggable session from a saved Template, cloning its exercises.
    static func fromTemplate(_ template: Template, date: String? = nil) -> StrengthSession {
        let exercises = template.exercises.map { ex -> Exercise in
            var copy = ex
            // Reset any completion state that may have been copied over, but
            // keep the prescribed weights/reps as placeholders for the athlete.
            copy.sets = copy.sets.enumerated().map { idx, s in
                ExerciseSet(
                    setNum: idx + 1,
                    completed: false,
                    weight: s.weight,
                    reps: s.reps,
                    duration: s.duration,
                    band: s.band
                )
            }
            return copy
        }
        return StrengthSession(
            id: UUID().uuidString,
            name: template.name,
            date: date ?? todayString(),
            duration: nil,
            exercises: exercises,
            templateId: template.id
        )
    }

    /// Blank quick-start session with no exercises. The athlete adds them
    /// from the picker mid-workout.
    static func quickStart(name: String = "Quick Workout", date: String? = nil) -> StrengthSession {
        StrengthSession(
            id: UUID().uuidString,
            name: name,
            date: date ?? todayString(),
            duration: nil,
            exercises: [],
            templateId: nil
        )
    }

    /// Clones a completed session as a new in-progress session so the
    /// athlete can repeat a previous workout, keeping the structure but
    /// clearing completion state.
    func cloneForRepeat() -> StrengthSession {
        let cleared = exercises.map { ex -> Exercise in
            var copy = ex
            copy.sets = copy.sets.enumerated().map { idx, s in
                ExerciseSet(
                    setNum: idx + 1,
                    completed: false,
                    weight: s.weight,
                    reps: s.reps,
                    duration: s.duration,
                    band: s.band
                )
            }
            return copy
        }
        return StrengthSession(
            id: UUID().uuidString,
            name: name,
            date: todayString(),
            duration: nil,
            exercises: cleared,
            templateId: templateId
        )
    }

    var completedSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
    }

    var totalSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }
}

extension Exercise {
    /// Expand a plan-prescribed exercise into a loggable one by materializing
    /// its prescribed set count as concrete ExerciseSet rows.
    static func fromPrescribed(_ p: PrescribedExercise) -> Exercise {
        let setCount = max(1, p.sets ?? 3)
        let sets: [ExerciseSet] = (1...setCount).map { idx in
            ExerciseSet(
                setNum: idx,
                completed: false,
                weight: p.weight,
                reps: p.reps,
                duration: p.duration,
                band: p.band
            )
        }
        return Exercise(
            name: p.name,
            exerciseType: p.exerciseType,
            sets: sets,
            rest: p.rest,
            notes: p.notes
        )
    }

    /// Template for a fresh empty set for a given exercise type.
    static func blankSet(setNum: Int, type: ExerciseType, previous: ExerciseSet? = nil) -> ExerciseSet {
        ExerciseSet(
            setNum: setNum,
            completed: false,
            weight: previous?.weight,
            reps: previous?.reps,
            duration: previous?.duration,
            band: previous?.band
        )
    }
}
