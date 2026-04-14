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
    var catalogExercises: [CatalogExercise] = []

    var isLoading = false
    var error: String?

    /// Name of the tool currently being executed by the agent loop, or nil.
    /// Used by ChatTab to show custom loading states (e.g. "Building your plan…").
    var activeToolName: String?

    /// Pre-seeded prompt for the chat tab set by other tabs (e.g. Plan tab's
    /// "Build with your coach" button). Consumed on next chat appear.
    var pendingChatPrompt: String?

    /// Currently-selected tab. Kept here so any view can switch tabs
    /// programmatically (e.g. Plan tab routing to the coach).
    var selectedTab: String = "home"

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
            async let cat: [CatalogExercise] = client.from("exercises").select().execute().value
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
            catalogExercises = try await cat

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

    func updateCardio(_ workout: CardioWorkout) async throws {
        if let idx = cardio.firstIndex(where: { $0.id == workout.id }) {
            cardio[idx] = workout
        }
        try await client.from("cardio_workouts").upsert(workout).execute()
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

    /// Toggles the explicit `completed` flag on a single prescribed session and persists the plan.
    func toggleSessionCompleted(weekNum: Int, dayIdx: Int, sessionIdx: Int) async throws {
        guard var plan = trainingPlan else { return }
        let key = String(weekNum)
        guard var wp = plan.weeklyPlans[key],
              dayIdx >= 0, dayIdx < wp.sessions.count else { return }
        var dayPlan = wp.sessions[dayIdx]
        guard sessionIdx >= 0, sessionIdx < dayPlan.sessions.count else { return }
        var session = dayPlan.sessions[sessionIdx]
        session.completed = !(session.completed ?? false)
        dayPlan.sessions[sessionIdx] = session
        wp.sessions[dayIdx] = dayPlan
        plan.weeklyPlans[key] = wp
        try await savePlan(plan)
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

    // MARK: - Exercise Library

    /// Merged, deduped view of catalog + custom + from-history exercises.
    /// Catalog wins on slug collision; history-only slugs appear flagged.
    func allExercises() -> [ExerciseLibraryItem] {
        var items: [ExerciseLibraryItem] = catalogExercises.map { cat in
            ExerciseLibraryItem(
                slug: cat.slug,
                name: cat.name,
                bodyPart: cat.bodyPart,
                category: cat.category,
                exerciseType: cat.exerciseType,
                isCustom: false,
                isFromHistory: false,
                customId: nil
            )
        }
        var knownSlugs = Set(items.map(\.slug))

        for custom in customExercises where !knownSlugs.contains(custom.slug) {
            items.append(ExerciseLibraryItem(
                slug: custom.slug,
                name: custom.name,
                bodyPart: custom.bodyPart ?? "Other",
                category: custom.category ?? "Other",
                exerciseType: custom.exerciseType,
                isCustom: true,
                isFromHistory: false,
                customId: custom.id
            ))
            knownSlugs.insert(custom.slug)
        }

        var firstByHistorySlug: [String: Exercise] = [:]
        for session in strength {
            for exercise in session.exercises {
                let slug = exercise.name.slugified
                guard !slug.isEmpty, !knownSlugs.contains(slug) else { continue }
                if firstByHistorySlug[slug] == nil {
                    firstByHistorySlug[slug] = exercise
                }
            }
        }
        for (slug, ex) in firstByHistorySlug {
            items.append(ExerciseLibraryItem(
                slug: slug,
                name: ex.name,
                bodyPart: "Other",
                category: "Other",
                exerciseType: ex.exerciseType,
                isCustom: false,
                isFromHistory: true,
                customId: nil
            ))
        }

        return items.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Compute per-slug PRs by walking all strength sessions chronologically.
    /// Used by the library to render per-row PR summaries — the `personal_records`
    /// table is sparsely populated on real accounts, so we recompute from sessions.
    func sessionPRs() -> [String: PersonalRecord] {
        var result: [String: PersonalRecord] = [:]
        let chrono = strength.sorted { $0.date < $1.date }
        for session in chrono {
            for exercise in session.exercises {
                let slug = exercise.name.slugified
                guard !slug.isEmpty else { continue }
                for set in exercise.sets where set.completed {
                    if let updated = computeExercisePR(
                        existing: result[slug],
                        name: exercise.name,
                        set: set,
                        type: exercise.exerciseType
                    ) {
                        result[slug] = updated
                    }
                }
            }
        }
        return result
    }

    /// Scan strength sessions for a slug, compute per-session PR flags chronologically,
    /// and return the history in reverse chronological order with a computed PR snapshot.
    func exerciseHistory(slug: String) -> ExerciseHistory {
        let matching: [(StrengthSession, Exercise)] = strength.flatMap { session in
            session.exercises
                .filter { $0.name.slugified == slug }
                .map { exercise in (session, exercise) }
        }

        let chrono = matching.sorted { $0.0.date < $1.0.date }
        var runningPR: PersonalRecord? = nil
        var prBySessionId: [String: Bool] = [:]

        for (session, exercise) in chrono {
            var hit = false
            for set in exercise.sets where set.completed {
                if let updated = computeExercisePR(
                    existing: runningPR,
                    name: exercise.name,
                    set: set,
                    type: exercise.exerciseType
                ) {
                    hit = true
                    runningPR = updated
                }
            }
            prBySessionId[session.id, default: false] = prBySessionId[session.id, default: false] || hit
        }

        let displayOrder = matching.sorted { $0.0.date > $1.0.date }
        let entries = displayOrder.map { session, exercise in
            ExerciseHistoryEntry(
                session: session,
                slug: slug,
                displayName: exercise.name,
                exerciseType: exercise.exerciseType,
                sets: exercise.sets,
                wasPR: prBySessionId[session.id] ?? false
            )
        }

        return ExerciseHistory(
            slug: slug,
            entries: entries,
            personalRecord: runningPR ?? prs[slug]
        )
    }

    /// Insert a new custom exercise. Rejects duplicates against catalog or existing customs.
    func addCustomExercise(
        name: String,
        bodyPart: String?,
        category: String?,
        type: ExerciseType
    ) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CustomExerciseError.invalidName }
        let slug = trimmed.slugified
        guard !slug.isEmpty else { throw CustomExerciseError.invalidName }

        if catalogExercises.contains(where: { $0.slug == slug }) ||
            customExercises.contains(where: { $0.slug == slug }) {
            throw CustomExerciseError.duplicateSlug
        }

        let payload = CustomExerciseInsert(
            name: trimmed,
            slug: slug,
            bodyPart: bodyPart,
            category: category,
            exerciseType: type.rawValue
        )
        let inserted: CustomExercise = try await client
            .from("custom_exercises")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        customExercises.append(inserted)
    }

    func deleteCustomExercise(id: Int) async throws {
        customExercises.removeAll { $0.id == id }
        try await client.from("custom_exercises").delete().eq("id", value: id).execute()
    }
}

// MARK: - Insert Payload

/// Dedicated insert payload for custom_exercises that omits `id` (SERIAL, server-assigned)
/// and `user_id` (filled by `auth.uid()` default from migration 002). Using the read model
/// for insert would send `"id": null` and fail the NOT NULL SERIAL constraint.
private struct CustomExerciseInsert: Encodable {
    let name: String
    let slug: String
    let bodyPart: String?
    let category: String?
    let exerciseType: String

    enum CodingKeys: String, CodingKey {
        case name, slug, category
        case bodyPart = "body_part"
        case exerciseType = "exercise_type"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(slug, forKey: .slug)
        try c.encodeIfPresent(bodyPart, forKey: .bodyPart)
        try c.encodeIfPresent(category, forKey: .category)
        try c.encode(exerciseType, forKey: .exerciseType)
    }
}
