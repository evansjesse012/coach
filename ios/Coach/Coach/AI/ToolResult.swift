import Foundation

/// What a tool execution produces. `summary` is what goes back to the model
/// (stringly-typed JSON, same as before). `effects` is a typed list of
/// side effects that `ChatTab` should persist via `DataService` after the
/// agent loop returns.
struct ToolResult {
    let summary: String
    let effects: [ToolEffect]

    init(summary: String, effects: [ToolEffect] = []) {
        self.summary = summary
        self.effects = effects
    }
}

/// Persistable side effects produced by a tool call. The agent loop
/// collects these across rounds; the UI layer (ChatTab) dispatches them
/// to DataService after the loop completes.
enum ToolEffect {
    case planCreated(TrainingPlan)
    case planUpdated(TrainingPlan)
    case weekUpdated(weekNumber: Int, weekPlan: WeeklyPlan)
    case progressUpdated(currentWeek: Int, currentPhase: Int)
    case workoutLogged(CardioWorkout)
    case nutritionLogged(NutritionEntry)
    case eventCreated(Event)
    case eventUpdated(Event)
    case eventDeleted(id: String)
}
