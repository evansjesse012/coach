import Foundation
import Supabase

/// Centralized data access layer wrapping all Supabase CRUD operations.
/// Loads all data into memory on launch; writes go to Supabase async with optimistic local updates.
@MainActor
@Observable
final class DataService {
    // MARK: - Published State
    var cardio: [CardioWorkout] = []
    var strength: [StrengthSession] = []
    var prs: [String: PersonalRecord] = [:]
    var events: [Event] = []
    var nutrition: [NutritionEntry] = []
    var bricks: [Brick] = []
    var trainingPlan: TrainingPlan?
    var planHistory: [PlanHistory] = []
    var memory: CoachingMemory = .empty()
    var messages: [ChatMessage] = []
    var settings: UserSettings = .defaults()
    var templates: [Template] = []
    var customExercises: [CustomExercise] = []

    var isLoading = false
    var error: String?

    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Load All Data

    func loadAll() async {
        isLoading = true
        error = nil
        do {
            async let c: [CardioWorkout] = client.from("cardio_workouts").select().execute().value
            async let s: [StrengthSession] = client.from("strength_sessions").select().execute().value
            async let e: [Event] = client.from("events").select().execute().value
            async let n: [NutritionEntry] = client.from("nutrition").select().execute().value
            async let b: [Brick] = client.from("bricks").select().execute().value
            async let tp: [TrainingPlan] = client.from("training_plans").select().execute().value
            async let ph: [PlanHistory] = client.from("plan_history").select().execute().value
            async let cm: [CoachingMemory] = client.from("coaching_memory").select().execute().value
            async let msg: [ChatMessage] = client.from("chat_messages").select().order("created_at").execute().value
            async let st: [UserSettings] = client.from("settings").select().execute().value
            async let t: [Template] = client.from("templates").select().execute().value
            async let ce: [CustomExercise] = client.from("custom_exercises").select().execute().value
            async let pr: [PersonalRecord] = client.from("personal_records").select().execute().value

            cardio = try await c
            strength = try await s
            events = try await e
            nutrition = try await n
            bricks = try await b
            trainingPlan = try await tp.first
            planHistory = try await ph
            memory = try await cm.first ?? .empty()
            messages = try await msg
            settings = try await st.first ?? .defaults()
            templates = try await t
            customExercises = try await ce

            // Build PRs dictionary keyed by exercise slug
            let prList = try await pr
            prs = Dictionary(uniqueKeysWithValues: prList.map { ($0.exerciseSlug, $0) })
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Cardio CRUD

    func addCardio(_ workout: CardioWorkout) async throws {
        cardio.insert(workout, at: 0)
        try await client.from("cardio_workouts").insert(workout).execute()
    }

    func deleteCardio(_ id: String) async throws {
        cardio.removeAll { $0.id == id }
        try await client.from("cardio_workouts").delete().eq("id", value: id).execute()
    }

    // MARK: - Strength CRUD

    func addStrength(_ session: StrengthSession) async throws {
        strength.insert(session, at: 0)
        try await client.from("strength_sessions").insert(session).execute()
    }

    func deleteStrength(_ id: String) async throws {
        strength.removeAll { $0.id == id }
        try await client.from("strength_sessions").delete().eq("id", value: id).execute()
    }

    // MARK: - Events CRUD

    func addEvent(_ event: Event) async throws {
        events.append(event)
        try await client.from("events").insert(event).execute()
    }

    func updateEvent(_ event: Event) async throws {
        if let idx = events.firstIndex(where: { $0.id == event.id }) {
            events[idx] = event
        }
        try await client.from("events").update(event).eq("id", value: event.id).execute()
    }

    func deleteEvent(_ id: String) async throws {
        events.removeAll { $0.id == id }
        try await client.from("events").delete().eq("id", value: id).execute()
    }

    // MARK: - Nutrition CRUD

    func addNutrition(_ entry: NutritionEntry) async throws {
        nutrition.insert(entry, at: 0)
        try await client.from("nutrition").insert(entry).execute()
    }

    // MARK: - Training Plan

    func savePlan(_ plan: TrainingPlan) async throws {
        trainingPlan = plan
        try await client.from("training_plans").upsert(plan).execute()
    }

    func deletePlan(_ id: String, archiveTo history: PlanHistory) async throws {
        trainingPlan = nil
        planHistory.append(history)
        try await client.from("training_plans").delete().eq("id", value: id).execute()
        try await client.from("plan_history").insert(history).execute()
    }

    // MARK: - Coaching Memory

    func saveMemory(_ mem: CoachingMemory) async throws {
        memory = mem
        try await client.from("coaching_memory").upsert(mem, onConflict: "user_id").execute()
    }

    // MARK: - Chat Messages

    func addMessage(_ message: ChatMessage) async throws {
        messages.append(message)
        try await client.from("chat_messages").insert(message).execute()
    }

    // MARK: - Settings

    func saveSettings(_ s: UserSettings) async throws {
        settings = s
        try await client.from("settings").upsert(s, onConflict: "user_id").execute()
    }

    // MARK: - Personal Records

    func savePR(_ pr: PersonalRecord) async throws {
        prs[pr.exerciseSlug] = pr
        try await client.from("personal_records").upsert(pr).execute()
    }

    // MARK: - Bricks

    func addBrick(_ brick: Brick) async throws {
        bricks.append(brick)
        try await client.from("bricks").insert(brick).execute()
    }

    func deleteBrick(_ id: String) async throws {
        bricks.removeAll { $0.id == id }
        try await client.from("bricks").delete().eq("id", value: id).execute()
    }

    // MARK: - Templates

    func saveTemplate(_ template: Template) async throws {
        if let idx = templates.firstIndex(where: { $0.id == template.id }) {
            templates[idx] = template
        } else {
            templates.append(template)
        }
        try await client.from("templates").upsert(template).execute()
    }

    func deleteTemplate(_ id: String) async throws {
        templates.removeAll { $0.id == id }
        try await client.from("templates").delete().eq("id", value: id).execute()
    }
}
