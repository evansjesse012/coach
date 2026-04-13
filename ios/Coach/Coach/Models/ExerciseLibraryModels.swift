import Foundation

/// Merged display row unifying catalog exercises, user customs, and exercises
/// that only appear in historical strength sessions. Not persisted.
struct ExerciseLibraryItem: Identifiable, Hashable {
    var id: String { slug }
    let slug: String
    let name: String
    let bodyPart: String
    let category: String
    let exerciseType: ExerciseType
    let isCustom: Bool
    let isFromHistory: Bool
    let customId: Int?  // populated only when isCustom, used for delete
}

/// Everything needed to render the detail screen for one slug.
struct ExerciseHistory {
    let slug: String
    let entries: [ExerciseHistoryEntry]  // reverse chronological
    let personalRecord: PersonalRecord?
}

/// One session's appearance of a given exercise slug.
struct ExerciseHistoryEntry: Identifiable {
    var id: String { "\(session.id)-\(slug)" }
    let session: StrengthSession
    let slug: String
    let displayName: String     // name as typed in that session — may differ from catalog canonical
    let exerciseType: ExerciseType
    let sets: [ExerciseSet]
    let wasPR: Bool             // precomputed — do not recompute in the view
}

/// Errors thrown by DataService.addCustomExercise / deleteCustomExercise.
enum CustomExerciseError: LocalizedError {
    case duplicateSlug
    case invalidName

    var errorDescription: String? {
        switch self {
        case .duplicateSlug:
            return "An exercise with this name already exists."
        case .invalidName:
            return "Please enter a valid exercise name."
        }
    }
}
