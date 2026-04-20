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

    /// HealthKit-imported workouts that the WorkoutMatcher couldn't pair to
    /// any prescribed session. In-memory only — repopulated on each sync.
    /// The UI shows these as "New workout detected" cards in Today's Focus.
    var pendingHealthKitImports: [CardioWorkout] = []

    /// True while a HealthKit sync is running, so the UI can show a spinner.
    var isHealthKitSyncing: Bool = false

    /// Last HealthKit sync error, or nil. Cleared on the next successful sync.
    var healthKitSyncError: String?

    var isLoading = false
    var error: String?

    /// Name of the tool currently being executed by the agent loop, or nil.
    /// Used by ChatTab to show custom loading states (e.g. "Building your plan…").
    var activeToolName: String?

    /// Free-form progress message for long-running tools that want to report
    /// stages (e.g. "Generating weeks 3–4 of 12…"). Takes precedence over the
    /// static activeToolName mapping in ChatTab's loading label when set.
    var activeToolProgress: String?

    /// Weeks currently being generated in the background by
    /// `ensurePlanPreGenerated`. Used as a de-dup set so a second trigger
    /// (e.g. app launch then Plan tab appear within a few seconds) doesn't
    /// kick off a second generation of the same week. In-memory only.
    var pregeneratingWeeks: Set<Int> = []

    /// The week number that was most recently pre-generated in the
    /// background. The Plan tab reads this to show a small "Your coach just
    /// wrote next week" banner, and clears it when the athlete taps through
    /// or navigates to the week.
    var recentlyPregeneratedWeek: Int?

    /// Pre-seeded prompt for the chat tab set by other tabs (e.g. Plan tab's
    /// "Build with your coach" button). Consumed on next chat appear.
    var pendingChatPrompt: String?

    /// Presents the coach chat as a sheet overlay from any tab. Set to true
    /// to open the chat; the sheet's dismiss resets it to false. Replaces
    /// the old `selectedTab = "coach"` routing.
    var showCoachSheet: Bool = false

    // MARK: - Conversations

    /// The active (non-archived) conversation. nil means we need to start
    /// one. Messages in `currentMessages` are scoped to this conversation.
    var currentConversation: Conversation?

    /// Archived conversations loaded on launch, newest first. Used by
    /// the chat History view.
    var archivedConversations: [Conversation] = []

    /// Messages belonging to the current conversation only. This is what
    /// ChatTab renders and what gets sent to the agent loop — NOT the
    /// full `messages` array which is now only used for legacy compat.
    var currentMessages: [ChatMessage] = []

    /// Currently-selected tab. Kept here so any view can switch tabs
    /// programmatically (e.g. Plan tab routing to the coach).
    var selectedTab: String = "home"

    // MARK: - Active Strength Workout

    /// The strength session the athlete is currently logging. Lives only in
    /// memory + UserDefaults until the workout is finished, at which point it
    /// is persisted to Supabase via addStrength. `nil` means no active workout.
    var activeStrengthSession: StrengthSession?

    /// Wall-clock timestamp when the athlete tapped "Start Workout". Used by
    /// WorkoutLoggingView's elapsed-time display and saved as the final
    /// `duration` (minutes) when the workout is finished.
    var activeWorkoutStartedAt: Date?

    /// Countdown state for the between-set rest timer. Both values are nil
    /// when no rest is running; otherwise remaining ticks down each second.
    var restTimerSecondsRemaining: Int?
    var restTimerTotalSeconds: Int?

    /// Background task running the rest-timer countdown. Cancelled whenever
    /// the timer is stopped, skipped, or restarted.
    private var restTimerTask: Task<Void, Never>?

    private let activeSessionKey = "coach.activeStrengthSession.v1"
    private let activeStartedAtKey = "coach.activeWorkoutStartedAt.v1"

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
            async let msg: [ChatMessage] = client.from("chat_messages").select().order("created_at").limit(200).execute().value
            async let convos: [Conversation] = client.from("conversations").select().order("last_message_at", ascending: false).execute().value
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
            let allConversations = try await convos
            archivedConversations = allConversations.filter(\.isArchived)
            currentConversation = allConversations.first(where: { !$0.isArchived })
            reloadCurrentMessages()
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

        // Fire-and-forget background tasks. Order matters:
        // 1. HealthKit sync — pulls latest workouts so everything downstream
        //    has fresh data.
        // 2. Plan auto-advance + pre-generation — advances currentWeek and
        //    pre-generates upcoming weeks on Thursday.
        // 3. Coach's note — generated AFTER sync and plan advance so it
        //    reflects the latest workout data and plan state.
        Task { [weak self] in
            guard let self else { return }
            await self.syncHealthKitWorkouts()
            await self.ensurePlanPreGenerated()
            await self.refreshCoachNoteIfNeeded()
        }
    }

    /// Generates a fresh coach's note if the current one is stale —
    /// either never generated, or generated 30+ minutes ago. This means
    /// the note refreshes on every meaningful app open (come back after
    /// a workout → note reflects the completed session) but not on quick
    /// app switches (30min cache prevents wasted API calls).
    private func refreshCoachNoteIfNeeded() async {
        if let existing = settings.pushMessage, let ts = existing.ts, !ts.isEmpty {
            let isoFmt = ISO8601DateFormatter()
            // Also try yyyy-MM-dd format (legacy notes stored date-only)
            let dateFmt = DateFormatter()
            dateFmt.dateFormat = "yyyy-MM-dd"
            if let generatedAt = isoFmt.date(from: ts) ?? dateFmt.date(from: ts) {
                let minutesSince = Date().timeIntervalSince(generatedAt) / 60
                if minutesSince < 30 {
                    return // still fresh
                }
            }
        }
        do {
            let note = try await CoachNoteGenerator.generate(
                plan: trainingPlan,
                memory: memory,
                settings: settings,
                events: events
            )
            var updated = settings
            updated.pushMessage = note
            try await saveSettings(updated)
        } catch {
            NSLog("[coach-note] refresh failed: \(error.localizedDescription)")
        }
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

    // MARK: - HealthKit Sync + Match

    /// Pulls recent workouts from HealthKit, dedupes, runs each new one
    /// through WorkoutMatcher, applies auto-completions for high/medium
    /// confidence matches, and surfaces the rest as pendingHealthKitImports.
    /// Requests HealthKit authorization on first run.
    func syncHealthKitWorkouts(days: Int = 3) async {
        isHealthKitSyncing = true
        healthKitSyncError = nil
        defer { isHealthKitSyncing = false }

        let service = HealthKitService.shared
        guard await service.isAvailable else {
            healthKitSyncError = "HealthKit isn't available on this device."
            return
        }

        do {
            try await service.requestAuthorization()
        } catch {
            healthKitSyncError = "HealthKit authorization failed: \(error.localizedDescription)"
            return
        }

        let fetched: [CardioWorkout]
        do {
            fetched = try await service.fetchWorkouts(days: days)
        } catch {
            healthKitSyncError = "Couldn't fetch HealthKit workouts: \(error.localizedDescription)"
            return
        }

        // Dedupe: skip workouts we've already imported (by id) or already
        // flagged as pending.
        let existingCardioIds = Set(cardio.map(\.id))
        let pendingIds = Set(pendingHealthKitImports.map(\.id))
        let newWorkouts = fetched.filter {
            !existingCardioIds.contains($0.id) && !pendingIds.contains($0.id)
        }

        guard !newWorkouts.isEmpty else { return }

        // Clear stale pending on a fresh sync; we'll rebuild from this pass.
        pendingHealthKitImports.removeAll()

        for workout in newWorkouts {
            await processIncomingHealthKitWorkout(workout)
        }
    }

    /// Runs the matcher on a single workout and applies the result. Shared
    /// between the live HealthKit path and the dev inject helper.
    private func processIncomingHealthKitWorkout(_ workout: CardioWorkout) async {
        // Persist the workout itself first so it appears in the Log tab and
        // history regardless of whether it matches a prescribed session.
        do {
            try await addCardio(workout)
        } catch {
            // Keep going even if persistence fails — the match pipeline
            // still operates on the in-memory workout.
            NSLog("[healthkit-sync] addCardio failed: \(error)")
        }

        guard let plan = trainingPlan else {
            pendingHealthKitImports.append(workout)
            return
        }

        let candidates = matchCandidatesForToday(plan: plan)
        let result = WorkoutMatcher.match(workout: workout, against: candidates)

        switch result.confidence {
        case .high:
            await applyAutoMatch(workout: workout, at: result.session, needsReview: false)
        case .medium:
            await applyAutoMatch(workout: workout, at: result.session, needsReview: true)
        case .low, .none:
            pendingHealthKitImports.append(workout)
        }
    }

    /// Injects a fake HealthKit workout into the same pipeline the real
    /// sync uses. For development testing without an Apple Watch.
    func injectMockHealthKitWorkout(_ workout: CardioWorkout) async {
        let existingCardioIds = Set(cardio.map(\.id))
        let pendingIds = Set(pendingHealthKitImports.map(\.id))
        guard !existingCardioIds.contains(workout.id), !pendingIds.contains(workout.id) else {
            return
        }
        await processIncomingHealthKitWorkout(workout)
    }

    /// Collects every unresolved prescribed session for today from the plan,
    /// with coordinates so the matcher result can be written back.
    private func matchCandidatesForToday(plan: TrainingPlan) -> [MatchCandidate] {
        let currentWeek = plan.currentWeek
        guard let wp = plan.weeklyPlans[String(currentWeek)] else { return [] }

        // Monday-indexed day: 0 = Monday .. 6 = Sunday.
        let dayIdx = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
        guard dayIdx < wp.sessions.count else { return [] }

        let dayPlan = wp.sessions[dayIdx]
        if dayPlan.isRest == true { return [] }

        var candidates: [MatchCandidate] = []
        for (idx, session) in dayPlan.sessions.enumerated() {
            // Skip already-resolved sessions.
            if session.completionStatus != nil || session.completed == true { continue }
            candidates.append(MatchCandidate(
                session: session,
                coords: SessionCoordinates(
                    weekNum: currentWeek,
                    dayIdx: dayIdx,
                    sessionIdx: idx
                )
            ))
        }
        return candidates
    }

    /// Writes a completion record back onto the prescribed session at the
    /// matcher-chosen coordinates. Populates actual fields from the imported
    /// workout and sets needsReview for medium-confidence matches.
    private func applyAutoMatch(
        workout: CardioWorkout,
        at coords: SessionCoordinates?,
        needsReview: Bool
    ) async {
        guard let coords else { return }
        try? await updateSessionCompletion(
            weekNum: coords.weekNum,
            dayIdx: coords.dayIdx,
            sessionIdx: coords.sessionIdx
        ) { session in
            session.completionStatus = .completed
            session.completed = true
            session.completionResolvedAt = ISO8601DateFormatter().string(from: Date())
            session.actualDuration = workout.duration
            if let distanceStr = workout.distance, let miles = parseMiles(distanceStr) {
                session.actualDistance = miles
            }
            session.completionNeedsReview = needsReview
            // Small note so Coach chat context can see provenance.
            session.completionNote = "Auto-matched from Apple Watch"
        }
    }

    /// Removes an unmatched pending import (after the user resolves it).
    func removePendingHealthKitImport(id: String) {
        pendingHealthKitImports.removeAll { $0.id == id }
    }

    private func parseMiles(_ s: String) -> Double? {
        // Accepts "4.80 mi" or "4.8mi" or "4.8".
        let trimmed = s.replacingOccurrences(of: "mi", with: "").trimmingCharacters(in: .whitespaces)
        return Double(trimmed)
    }

    // MARK: - Strength CRUD

    func addStrength(_ session: StrengthSession) async throws {
        strength.insert(session, at: 0)
        try await client.from("strength_sessions").insert(session).execute()
    }

    func updateStrength(_ session: StrengthSession) async throws {
        if let idx = strength.firstIndex(where: { $0.id == session.id }) {
            strength[idx] = session
        } else {
            strength.insert(session, at: 0)
        }
        try await client.from("strength_sessions").upsert(session).execute()
    }

    func deleteStrength(_ id: String) async throws {
        strength.removeAll { $0.id == id }
        try await client.from("strength_sessions").delete().eq("id", value: id).execute()
    }

    // MARK: - Active Workout (in-memory + UserDefaults)

    /// Start a new live strength workout. Persists to UserDefaults so a mid-
    /// workout app kill can be recovered. Cancels any already-running rest
    /// timer to avoid stale state from a previous session.
    func startStrengthWorkout(_ session: StrengthSession) {
        activeStrengthSession = session
        activeWorkoutStartedAt = Date()
        stopRestTimer()
        persistActiveSession()
    }

    /// Mutate the in-progress workout in place and re-persist. Callers pass
    /// an inout closure so SwiftUI sees one observable change per edit.
    func mutateActiveWorkout(_ mutate: (inout StrengthSession) -> Void) {
        guard var session = activeStrengthSession else { return }
        mutate(&session)
        activeStrengthSession = session
        persistActiveSession()
    }

    /// Finish the active workout: stamp duration, promote to Supabase, roll
    /// PRs, then clear the in-memory + UserDefaults active state.
    func finishActiveWorkout() async throws {
        guard var session = activeStrengthSession else { return }
        let duration: Int
        if let started = activeWorkoutStartedAt {
            let seconds = Date().timeIntervalSince(started)
            duration = max(1, Int((seconds / 60.0).rounded()))
        } else {
            duration = 0
        }
        session.duration = duration
        // Drop any exercises that had zero completed sets so the logged
        // history reflects what was actually done.
        session.exercises = session.exercises.filter { ex in
            ex.sets.contains(where: \.completed)
        }
        // Also drop any trailing non-completed sets so the saved session is
        // clean — Strong-app style.
        session.exercises = session.exercises.map { ex in
            var copy = ex
            copy.sets = copy.sets.filter(\.completed)
            for i in copy.sets.indices {
                copy.sets[i].setNum = i + 1
            }
            return copy
        }

        stopRestTimer()
        try await addStrength(session)
        await rollPRsForSession(session)

        activeStrengthSession = nil
        activeWorkoutStartedAt = nil
        clearPersistedActiveSession()
    }

    /// Abandon the active workout without saving anything.
    func cancelActiveWorkout() {
        stopRestTimer()
        activeStrengthSession = nil
        activeWorkoutStartedAt = nil
        clearPersistedActiveSession()
    }

    /// Walk the completed sets of a freshly-saved session and upsert any PRs
    /// it produced. Uses the existing computeExercisePR helper so the logic
    /// matches what the library's sessionPRs() computes.
    private func rollPRsForSession(_ session: StrengthSession) async {
        for exercise in session.exercises {
            let slug = exercise.name.slugified
            guard !slug.isEmpty else { continue }
            var existing = prs[slug]
            var hit = false
            for set in exercise.sets where set.completed {
                if let updated = computeExercisePR(
                    existing: existing,
                    name: exercise.name,
                    set: set,
                    type: exercise.exerciseType
                ) {
                    existing = updated
                    hit = true
                }
            }
            if hit, let newPR = existing {
                try? await savePR(newPR)
            }
        }
    }

    // MARK: - Rest Timer

    /// Kick off (or restart) a countdown for the given number of seconds.
    /// A running timer is implicitly cancelled so chaining sets works.
    func startRestTimer(seconds: Int) {
        guard seconds > 0 else { return }
        restTimerTotalSeconds = seconds
        restTimerSecondsRemaining = seconds
        restTimerTask?.cancel()
        restTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                await MainActor.run {
                    guard let self, let remaining = self.restTimerSecondsRemaining else { return }
                    if remaining <= 1 {
                        self.restTimerSecondsRemaining = nil
                        self.restTimerTotalSeconds = nil
                        self.restTimerTask = nil
                    } else {
                        self.restTimerSecondsRemaining = remaining - 1
                    }
                }
            }
        }
    }

    /// Shift the rest timer by a positive or negative number of seconds.
    /// Used by the +15 / -15 buttons in the overlay.
    func adjustRestTimer(by delta: Int) {
        guard var remaining = restTimerSecondsRemaining else { return }
        remaining = max(1, remaining + delta)
        restTimerSecondsRemaining = remaining
        if let total = restTimerTotalSeconds {
            restTimerTotalSeconds = max(total, remaining)
        }
    }

    /// Cancel and hide the rest timer immediately.
    func stopRestTimer() {
        restTimerTask?.cancel()
        restTimerTask = nil
        restTimerSecondsRemaining = nil
        restTimerTotalSeconds = nil
    }

    // MARK: - Active Workout persistence

    private func persistActiveSession() {
        let defaults = UserDefaults.standard
        if let session = activeStrengthSession,
           let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: activeSessionKey)
        } else {
            defaults.removeObject(forKey: activeSessionKey)
        }
        if let started = activeWorkoutStartedAt {
            defaults.set(started.timeIntervalSince1970, forKey: activeStartedAtKey)
        } else {
            defaults.removeObject(forKey: activeStartedAtKey)
        }
    }

    private func clearPersistedActiveSession() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: activeSessionKey)
        defaults.removeObject(forKey: activeStartedAtKey)
    }

    /// Called from CoachApp on launch (after loadAll) to restore an in-
    /// progress workout, if any. Silently no-ops on failure so a bad blob
    /// can't block the app.
    func restoreActiveWorkoutFromDisk() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: activeSessionKey),
              let session = try? JSONDecoder().decode(StrengthSession.self, from: data) else {
            return
        }
        activeStrengthSession = session
        let ts = defaults.double(forKey: activeStartedAtKey)
        if ts > 0 {
            activeWorkoutStartedAt = Date(timeIntervalSince1970: ts)
        } else {
            activeWorkoutStartedAt = Date()
        }
    }

    /// Look up the most recent completed set the athlete logged for an
    /// exercise (by slug). Used by WorkoutLoggingView to show "previous"
    /// targets in the set rows Strong-app style.
    func previousBest(forExerciseName name: String) -> ExerciseSet? {
        let slug = name.slugified
        guard !slug.isEmpty else { return nil }
        for session in strength.sorted(by: { $0.date > $1.date }) {
            for exercise in session.exercises where exercise.name.slugified == slug {
                if let last = exercise.sets.last(where: \.completed) {
                    return last
                }
            }
        }
        return nil
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

    /// Generate full daily detail for a stub week and splice it into the
    /// current plan. Thin wrapper around TrainingPlanGenerator.generateWeek
    /// so any view (not just the chat) can trigger lazy generation.
    func generateWeek(_ weekNum: Int) async throws {
        guard let plan = trainingPlan else { return }
        guard let goalId = plan.goalId,
              let event = events.first(where: { $0.id == goalId }) else {
            throw NSError(
                domain: "DataService", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "This plan isn't linked to a race event."]
            )
        }
        let week = try await TrainingPlanGenerator.generateWeek(
            weekNumber: weekNum,
            in: plan,
            event: event,
            athleteMemory: memory,
            dataService: self
        )
        var updated = plan
        updated.weeklyPlans[String(weekNum)] = week
        try await savePlan(updated)
    }

    // MARK: - Plan auto-progression & pre-generation

    /// Called on app launch and whenever the Plan tab appears. Does two
    /// things in order:
    ///
    ///   1. **Advances `currentWeek`** based on the calendar — computes
    ///      how many whole weeks have elapsed since `startDate` and moves
    ///      `currentWeek` / `currentPhase` forward if it's behind.
    ///   2. **Pre-generates upcoming weeks** the way a real coach would —
    ///      Thursday-ish of the current week (~50%+ through), if next
    ///      week is still a stub, kick off a silent background generation
    ///      so the athlete opens the app Monday to a ready-to-train week.
    ///      Also handles phase-transition lookahead: when next week begins
    ///      a new phase, the week after it is pre-generated too so the
    ///      athlete has mental runway for the transition.
    ///
    /// Safe to call multiple times — the `pregeneratingWeeks` de-dup set
    /// prevents duplicate work.
    func ensurePlanPreGenerated() async {
        guard var plan = trainingPlan else { return }

        // Calendar math. Both dates at day granularity.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let startStr = plan.startDate,
              let start = formatter.date(from: startStr) else { return }

        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let todayDay = calendar.startOfDay(for: Date())
        let daysSinceStart = calendar.dateComponents([.day], from: startDay, to: todayDay).day ?? 0
        guard daysSinceStart >= 0 else { return } // plan hasn't started yet

        let calendarWeek = min(plan.totalWeeks, (daysSinceStart / 7) + 1)

        // 1) Advance currentWeek / currentPhase if the calendar moved past us.
        if calendarWeek > plan.currentWeek {
            plan.currentWeek = calendarWeek
            if let phaseNum = plan.phaseNumber(forWeek: calendarWeek) {
                plan.currentPhase = phaseNum
            }
            try? await savePlan(plan)
        }

        // 2) Safety net: if the current week is somehow still a stub
        //    (e.g. initial creation failed mid-flight, or the athlete let
        //    a week pass without opening the app), generate it now so
        //    they have something to train with TODAY.
        if let currentWp = plan.weeklyPlans[String(calendarWeek)], currentWp.isStub {
            await pregenerateWeek(calendarWeek, surfaceInUI: false)
        }

        // 3) Pre-generate next week if we're past day 3 (Thursday) of the
        //    Mon-Sun week. Matches when a real coach sits down to write
        //    next week — see the design in the "what would an expert coach
        //    do" discussion.
        let dayWithinWeek = daysSinceStart % 7
        guard dayWithinWeek >= 3 else { return }

        let nextWeek = calendarWeek + 1
        guard nextWeek <= plan.totalWeeks else { return }

        // Reload plan — step 2 may have updated it in-memory already.
        guard let freshPlan = trainingPlan else { return }

        if let nextWp = freshPlan.weeklyPlans[String(nextWeek)], nextWp.isStub {
            await pregenerateWeek(nextWeek, surfaceInUI: true)
        }

        // 4) Phase-transition lookahead: if next week starts a new phase,
        //    also pre-generate the week after it so the athlete has mental
        //    runway for the transition. Silent — no UI banner for the
        //    lookahead week, only for the immediately-next week.
        if let nextPhase = freshPlan.phaseNumber(forWeek: nextWeek),
           let currentPhase = freshPlan.phaseNumber(forWeek: calendarWeek),
           nextPhase != currentPhase {
            let weekAfter = nextWeek + 1
            if weekAfter <= freshPlan.totalWeeks,
               let wpAfter = freshPlan.weeklyPlans[String(weekAfter)],
               wpAfter.isStub {
                await pregenerateWeek(weekAfter, surfaceInUI: false)
            }
        }
    }

    /// Generates a single week in the background with de-duplication via
    /// `pregeneratingWeeks`. Set `surfaceInUI: true` to poke
    /// `recentlyPregeneratedWeek` on success so the Plan tab can show the
    /// "your coach just wrote next week" banner.
    private func pregenerateWeek(_ weekNum: Int, surfaceInUI: Bool) async {
        guard !pregeneratingWeeks.contains(weekNum) else { return }
        pregeneratingWeeks.insert(weekNum)
        do {
            try await generateWeek(weekNum)
            if surfaceInUI {
                recentlyPregeneratedWeek = weekNum
            }
        } catch {
            NSLog("[plan-pregen] week \(weekNum) failed: \(error.localizedDescription)")
        }
        pregeneratingWeeks.remove(weekNum)
    }

    /// Toggles the explicit `completed` flag on a single prescribed session and persists the plan.
    func toggleSessionCompleted(weekNum: Int, dayIdx: Int, sessionIdx: Int) async throws {
        try await updateSessionCompletion(weekNum: weekNum, dayIdx: dayIdx, sessionIdx: sessionIdx) { session in
            let nowCompleted = !(session.completed ?? false)
            session.completed = nowCompleted
            // Keep the legacy bool in lockstep with the richer enum so both
            // code paths see the same state.
            if nowCompleted {
                session.completionStatus = .completed
                session.completionResolvedAt = ISO8601DateFormatter().string(from: Date())
            } else {
                session.completionStatus = nil
                session.completionResolvedAt = nil
                session.actualDuration = nil
                session.actualDistance = nil
                session.actualSport = nil
                session.skipReason = nil
                session.completionNote = nil
            }
        }
    }

    /// Applies an arbitrary mutation to a single prescribed session and persists the plan.
    /// Used by the completion flow (mark completed / modified / swapped / skipped).
    func updateSessionCompletion(
        weekNum: Int,
        dayIdx: Int,
        sessionIdx: Int,
        _ mutate: (inout PrescribedSession) -> Void
    ) async throws {
        guard var plan = trainingPlan else { return }
        let key = String(weekNum)
        guard var wp = plan.weeklyPlans[key],
              dayIdx >= 0, dayIdx < wp.sessions.count else { return }
        var dayPlan = wp.sessions[dayIdx]
        guard sessionIdx >= 0, sessionIdx < dayPlan.sessions.count else { return }
        var session = dayPlan.sessions[sessionIdx]
        mutate(&session)
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
        var msg = message
        msg.conversationId = currentConversation?.id
        messages.append(msg)
        currentMessages.append(msg)
        try await client.from("chat_messages").insert(msg).execute()
        // Keep the conversation's lastMessageAt fresh
        if var convo = currentConversation {
            convo.lastMessageAt = ISO8601DateFormatter().string(from: Date())
            currentConversation = convo
            _ = try? await client.from("conversations")
                .update(["last_message_at": convo.lastMessageAt])
                .eq("id", value: convo.id)
                .execute()
        }
    }

    // MARK: - Conversation lifecycle

    /// Filter `messages` to only those belonging to the current conversation.
    private func reloadCurrentMessages() {
        guard let convoId = currentConversation?.id else {
            currentMessages = []
            return
        }
        currentMessages = messages.filter { $0.conversationId == convoId }
    }

    /// Ensure a current (non-stale) conversation exists. If the current one
    /// is stale (>2 hours since last message) or nil, archive it and start
    /// fresh. Called when the chat sheet opens.
    func ensureActiveConversation() async {
        if let existing = currentConversation, !existing.isStale {
            return // still fresh
        }
        // Archive the old conversation (if any)
        if let old = currentConversation {
            await archiveConversation(old)
        }
        // Start a new one
        let fresh = Conversation.create()
        currentConversation = fresh
        currentMessages = []
        _ = try? await client.from("conversations").insert(fresh).execute()
    }

    /// Archive a conversation: generate a summary, mark as archived,
    /// move to the archived list.
    func archiveConversation(_ convo: Conversation) async {
        var archived = convo
        archived.isArchived = true
        // Generate a summary from the conversation's messages
        let convoMessages = messages.filter { $0.conversationId == convo.id }
        if !convoMessages.isEmpty {
            archived.summary = await generateConversationSummary(convoMessages)
        }
        // Persist
        _ = try? await client.from("conversations")
            .update(archived)
            .eq("id", value: archived.id)
            .execute()
        // Update local state
        archivedConversations.insert(archived, at: 0)
        if currentConversation?.id == convo.id {
            currentConversation = nil
            currentMessages = []
        }
    }

    /// Load messages for a specific archived conversation (for History view).
    func messagesForConversation(_ conversationId: String) -> [ChatMessage] {
        messages.filter { $0.conversationId == conversationId }
    }

    /// Small Claude call to produce a 1-2 sentence summary of a
    /// conversation for the History view and coach context.
    private func generateConversationSummary(_ msgs: [ChatMessage]) async -> String? {
        let transcript = msgs.map { "\($0.role): \($0.content)" }
            .joined(separator: "\n")
            .prefix(3000) // cap input size
        let prompt = """
        Summarize this coaching conversation in 1-2 sentences. Focus on what was discussed, \
        any decisions made, and any action items. Be specific — reference the actual topics, \
        not generic descriptions.

        \(transcript)
        """
        let body: [String: Any] = [
            "system": "Return only the summary text, no JSON, no markdown fences.",
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 200,
            "model": "claude-sonnet-4-6",
        ]
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            let response: SummaryResponse = try await client.functions.invoke(
                "chat",
                options: .init(body: bodyData)
            ) { data, response in
                guard 200..<300 ~= response.statusCode else {
                    throw NSError(domain: "ConversationSummary", code: response.statusCode)
                }
                return try JSONDecoder().decode(SummaryResponse.self, from: data)
            }
            return response.content.first(where: { $0.type == "text" })?.text?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            NSLog("[conversation-summary] failed: \(error.localizedDescription)")
            return nil
        }
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
