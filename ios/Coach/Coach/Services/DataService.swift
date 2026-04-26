import Foundation
import Supabase

/// Record of a HealthKit auto-match waiting to be acknowledged in chat.
/// Used by the manual-link path (`applyManualMatch`) to queue a coach
/// reply. Auto-matches now go through `PendingWatchMatch` instead.
struct AutoMatchRecord {
    let session: PrescribedSession
    let actualDuration: Int
    let actualDistance: Double?
    let needsReview: Bool
    var detectedStatus: CompletionStatus = .completed
}

/// HealthKit-imported workout that the matcher tied to a prescribed
/// session, awaiting the athlete's confirmation. Holds everything the
/// confirmation UI needs (the workout, the matched session, the
/// coordinates to write back, and the matcher's suggested status) so
/// the sheet can render and commit without re-running the matcher.
struct PendingWatchMatch: Identifiable, Hashable {
    let id: String                           // workout.id — unique
    let workout: CardioWorkout
    let session: PrescribedSession
    let coords: SessionCoordinates
    let suggestedStatus: CompletionStatus    // matcher's classification
    let confidence: MatchConfidence

    static func == (lhs: PendingWatchMatch, rhs: PendingWatchMatch) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Domain errors raised by `DataService` when a session's timing invariant
/// is violated. Currently only one case, but typed as an enum so the
/// pattern-match site can distinguish "can't mark future session" from
/// a generic persistence error.
enum SessionTimingError: Error, LocalizedError {
    /// The session's scheduled date is strictly after today, so it cannot
    /// yet be marked done / modified / swapped / skipped.
    case cannotMarkFutureSession(weekNum: Int, dayIdx: Int)

    var errorDescription: String? {
        switch self {
        case .cannotMarkFutureSession:
            return "This session is in the future and can't be marked yet."
        }
    }
}

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

    /// Auto-matched HealthKit workouts that haven't been acknowledged in
    /// chat yet. ChatTab drains this on appear to generate coach reactions.
    var unacknowledgedAutoMatches: [AutoMatchRecord] = []

    /// HealthKit workouts that the matcher tied to a prescribed session
    /// at high or medium confidence — but which haven't yet been
    /// confirmed by the athlete. Surfaced on Today as a banner; the
    /// athlete confirms or changes the suggested status from a sheet.
    /// Replaces the old silent auto-apply behavior — nothing is written
    /// to the prescribed session until the athlete confirms.
    var pendingWatchMatches: [PendingWatchMatch] = []

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

    /// Timestamp of the last `preGenerateOnForeground` call, used to
    /// debounce so we don't re-run on every foreground event.
    private var lastForegroundPreGenAt: Date?

    /// Pre-seeded prompt for the chat tab set by other tabs (e.g. Plan tab's
    /// "Build with your coach" button). Consumed on next chat appear.
    var pendingChatPrompt: String?

    /// Flip this to ask the shell (MainTabView) to present the coach
    /// chat sheet. Used by flows that have already sent a user message
    /// via `sendUserMessage` and just want the UI to pop so the athlete
    /// can see the reply stream in. MainTabView resets it back to false
    /// on each observation so subsequent toggles re-fire.
    var shouldOpenChat: Bool = false

    // showCoachSheet removed — coach is now a primary tab, not a sheet.

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
    var selectedTab: String = "coach"

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
    private let lastSeenChatAtKey = "coach.lastSeenChatAt.v1"

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
        case .high, .medium:
            // Don't write to the prescribed session yet — surface the
            // match as a pending confirmation on Today instead. The
            // athlete confirms or changes the suggested status; we
            // commit only after that. The old silent auto-apply caused
            // status to mysteriously change without notice.
            if let coords = result.session,
               let session = sessionAt(weekNum: coords.weekNum, dayIdx: coords.dayIdx, sessionIdx: coords.sessionIdx) {
                let suggested = classifyCompletion(workout: workout, prescribed: session)
                let pending = PendingWatchMatch(
                    id: workout.id,
                    workout: workout,
                    session: session,
                    coords: coords,
                    suggestedStatus: suggested,
                    confidence: result.confidence
                )
                if !pendingWatchMatches.contains(where: { $0.id == pending.id }) {
                    pendingWatchMatches.append(pending)
                }
            } else {
                pendingHealthKitImports.append(workout)
            }
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
    /// Athlete-driven link: the user picked a CardioWorkout to fulfill a
    /// prescribed session. Reuses the auto-match classifier and write path so
    /// downstream UI (status pills, coach review prompts) behaves identically.
    /// needsReview is always false — the athlete already confirmed by picking.
    func applyManualMatch(session: PrescribedSession, on dateString: String?, workout: CardioWorkout) async {
        guard let coords = locateSession(session, on: dateString) else { return }
        let status = classifyCompletion(workout: workout, prescribed: session)

        try? await updateSessionCompletion(
            weekNum: coords.weekNum,
            dayIdx: coords.dayIdx,
            sessionIdx: coords.sessionIdx
        ) { s in
            s.completionStatus = status
            s.completed = true
            s.completionResolvedAt = ISO8601DateFormatter().string(from: Date())
            s.actualDuration = workout.duration
            if let distanceStr = workout.distance, let miles = parseMiles(distanceStr) {
                s.actualDistance = miles
            }
            if status == .swapped {
                s.actualSport = workout.sport.rawValue
            }
            s.completionNeedsReview = false
            s.completionNote = manualMatchNote(status: status, workout: workout, prescribed: session)
            s.linkedWorkoutId = workout.id
        }

        let distanceMiles: Double? = workout.distance.flatMap { parseMiles($0) }
        unacknowledgedAutoMatches.append(AutoMatchRecord(
            session: session,
            actualDuration: workout.duration,
            actualDistance: distanceMiles,
            needsReview: false,
            detectedStatus: status
        ))
    }

    /// Confirm a pending HealthKit match. Writes the link + completion
    /// to the prescribed session and removes it from the pending queue.
    /// `chosenStatus` is what the athlete picked (defaults to the
    /// matcher's suggestion in the UI). Calling this is the only way
    /// an auto-match becomes a real completion now — nothing gets
    /// written silently anymore.
    func confirmPendingMatch(_ match: PendingWatchMatch, status: CompletionStatus) async {
        do {
            try await updateSessionCompletion(
                weekNum: match.coords.weekNum,
                dayIdx: match.coords.dayIdx,
                sessionIdx: match.coords.sessionIdx
            ) { s in
                s.completionStatus = status
                s.completed = (status != .skipped)
                s.completionResolvedAt = ISO8601DateFormatter().string(from: Date())
                s.actualDuration = match.workout.duration
                if let distanceStr = match.workout.distance, let miles = parseMiles(distanceStr) {
                    s.actualDistance = miles
                }
                if status == .swapped {
                    s.actualSport = match.workout.sport.rawValue
                }
                s.completionNeedsReview = false
                s.completionNote = "Linked from Apple Watch"
                s.linkedWorkoutId = match.workout.id
            }
            pendingWatchMatches.removeAll { $0.id == match.id }
        } catch {
            print("confirmPendingMatch failed (\(match.coords.weekNum)/\(match.coords.dayIdx)/\(match.coords.sessionIdx)): \(error)")
        }
    }

    /// Athlete declined to link this watch workout to the suggested
    /// session — usually because the matcher guessed wrong. Removes the
    /// pending match and routes the workout to the standard unmatched
    /// imports list (visible on the Log tab) so it isn't lost.
    func dismissPendingMatch(_ match: PendingWatchMatch) {
        pendingWatchMatches.removeAll { $0.id == match.id }
        if !pendingHealthKitImports.contains(where: { $0.id == match.workout.id }) {
            pendingHealthKitImports.append(match.workout)
        }
    }

    /// Clears a manual (or auto) match. Used when the athlete re-picks a
    /// different workout or explicitly unlinks.
    func clearSessionMatch(session: PrescribedSession, on dateString: String?) async {
        guard let coords = locateSession(session, on: dateString) else { return }
        try? await updateSessionCompletion(
            weekNum: coords.weekNum,
            dayIdx: coords.dayIdx,
            sessionIdx: coords.sessionIdx
        ) { s in
            s.completionStatus = nil
            s.completed = false
            s.completionResolvedAt = nil
            s.actualDuration = nil
            s.actualDistance = nil
            s.actualSport = nil
            s.completionNeedsReview = nil
            s.completionNote = nil
            s.linkedWorkoutId = nil
        }
    }

    /// Finds the (weekNum, dayIdx, sessionIdx) for a given prescribed session.
    /// When dateString is supplied and the plan has a startDate, derives the
    /// exact (weekNum, dayIdx) from calendar math — disambiguating sessions
    /// whose id ("type-label") appears in more than one week. Otherwise
    /// scans all weeks and returns the first session with matching id.
    func locateSession(_ session: PrescribedSession, on dateString: String?) -> SessionCoordinates? {
        guard let plan = trainingPlan else { return nil }

        if let dateString, let coords = dateDrivenCoords(plan: plan, dateString: dateString, session: session) {
            return coords
        }

        for (weekKey, wp) in plan.weeklyPlans {
            guard let weekNum = Int(weekKey) else { continue }
            for (dayIdx, dayPlan) in wp.sessions.enumerated() {
                for (sessionIdx, s) in dayPlan.sessions.enumerated() where s.id == session.id {
                    return SessionCoordinates(weekNum: weekNum, dayIdx: dayIdx, sessionIdx: sessionIdx)
                }
            }
        }
        return nil
    }

    private func dateDrivenCoords(plan: TrainingPlan, dateString: String, session: PrescribedSession) -> SessionCoordinates? {
        guard let startStr = plan.startDate else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let start = f.date(from: startStr), let target = f.date(from: dateString) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: start, to: target).day ?? -1
        guard days >= 0 else { return nil }
        let weekNum = days / 7 + 1
        let dayIdx = days % 7
        guard let wp = plan.weeklyPlans[String(weekNum)], dayIdx < wp.sessions.count else { return nil }
        if let sessionIdx = wp.sessions[dayIdx].sessions.firstIndex(where: { $0.id == session.id }) {
            return SessionCoordinates(weekNum: weekNum, dayIdx: dayIdx, sessionIdx: sessionIdx)
        }
        return nil
    }

    private func manualMatchNote(status: CompletionStatus, workout: CardioWorkout, prescribed: PrescribedSession) -> String {
        switch status {
        case .completed:
            return "Manually linked from Apple Watch"
        case .modified:
            let presDur = prescribed.duration ?? prescribed.estimatedDurationMin ?? 0
            return "Manually linked — \(workout.duration) min vs \(presDur) min prescribed"
        case .swapped:
            return "Manually linked — did \(workout.sport.label) instead of \(prescribed.type)"
        case .skipped:
            return "Manually linked from Apple Watch"
        }
    }

    /// Compares an incoming workout against the prescribed session to
    /// classify it as completed, modified, or swapped.
    private func classifyCompletion(workout: CardioWorkout, prescribed: PrescribedSession?) -> CompletionStatus {
        guard let prescribed else { return .completed }

        // Different sport → swapped
        let prescribedSport = prescribed.type.lowercased()
        let actualSport = workout.sport.rawValue
        if prescribedSport != actualSport {
            return .swapped
        }

        // Same sport — check duration deviation
        let prescribedDuration = prescribed.duration
            ?? prescribed.estimatedDurationMin
            ?? 0
        guard prescribedDuration > 0 else { return .completed }

        let deviation = abs(workout.duration - prescribedDuration)
        let threshold = max(10, Int(Double(prescribedDuration) * 0.2)) // 20% or 10 min, whichever is larger

        if deviation > threshold {
            return .modified
        }

        return .completed
    }

    private func sessionAt(weekNum: Int, dayIdx: Int, sessionIdx: Int) -> PrescribedSession? {
        guard let plan = trainingPlan,
              let wp = plan.weeklyPlans[String(weekNum)],
              dayIdx >= 0, dayIdx < wp.sessions.count,
              sessionIdx >= 0, sessionIdx < wp.sessions[dayIdx].sessions.count else { return nil }
        return wp.sessions[dayIdx].sessions[sessionIdx]
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
        // Snapshot the prescribed-vs-logged comparison BEFORE we prune
        // uncompleted sets off `session` below. Using the pre-prune
        // `activeStrengthSession` preserves the prescribed set count for
        // the `completed vs prescribed` ratio; the post-prune `session`
        // is what we save to history.
        let prePruneSession = activeStrengthSession
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

        // Link back to the prescribed session (if any) and mark it
        // complete / modified based on how much of the prescription was
        // actually logged. Uses the pre-prune snapshot so we have both
        // sides of the comparison (prescribed sets vs. completed sets).
        if let pre = prePruneSession {
            await markPrescribedSessionForFinishedStrength(finished: session, preprune: pre)
        }

        activeStrengthSession = nil
        activeWorkoutStartedAt = nil
        clearPersistedActiveSession()
    }

    // MARK: - Strength → prescribed session auto-link

    /// Finds the prescribed session that matches a just-finished strength
    /// workout (by scheduled date + template) and marks it `.completed`
    /// or `.modified` depending on how much of the prescription was
    /// actually logged.
    @MainActor
    private func markPrescribedSessionForFinishedStrength(
        finished: StrengthSession,
        preprune: StrengthSession
    ) async {
        guard let coords = findPrescribedStrengthMatch(for: finished) else { return }
        guard let plan = trainingPlan,
              let wp = plan.weeklyPlans[String(coords.weekNum)],
              coords.dayIdx < wp.sessions.count,
              coords.sessionIdx < wp.sessions[coords.dayIdx].sessions.count
        else { return }

        let prescribed = wp.sessions[coords.dayIdx].sessions[coords.sessionIdx]
        let status = completionStatusForStrength(prescribed: prescribed, preprune: preprune)

        do {
            try await updateSessionCompletion(
                weekNum: coords.weekNum,
                dayIdx: coords.dayIdx,
                sessionIdx: coords.sessionIdx
            ) { s in
                s.completionStatus = status
                s.completed = (status != .skipped)
                s.actualDuration = finished.duration ?? s.actualDuration
                s.completionResolvedAt = ISO8601DateFormatter().string(from: Date())
                if status == .modified && (s.completionNote ?? "").isEmpty {
                    s.completionNote = "Logged via workout — some prescribed sets not completed."
                }
            }
        } catch {
            // `updateSessionCompletion`'s future-session guard shouldn't
            // trip here (the workout was logged today), but log just in
            // case so the failure is visible during dev instead of
            // silently skipped.
            print("markPrescribedSessionForFinishedStrength: \(error)")
        }
    }

    /// Walks the plan for a strength session scheduled on the same date
    /// as the finished workout. Prefers a `templateId` match (exact same
    /// prescribed workout) and falls back to the first strength session
    /// scheduled that day if the template doesn't line up (e.g. quick-
    /// start + no template).
    private func findPrescribedStrengthMatch(
        for finished: StrengthSession
    ) -> (weekNum: Int, dayIdx: Int, sessionIdx: Int)? {
        guard let plan = trainingPlan else { return nil }
        let targetDate = finished.date

        var fallback: (Int, Int, Int)?
        for (weekKey, wp) in plan.weeklyPlans {
            guard let weekNum = Int(weekKey) else { continue }
            for (dayIdx, dayPlan) in wp.sessions.enumerated() {
                guard let scheduled = sessionDateString(
                    planStartDate: plan.startDate,
                    weekNumber: weekNum,
                    dayIdx: dayIdx
                ), scheduled == targetDate else { continue }

                for (sessionIdx, session) in dayPlan.sessions.enumerated() where session.type == "strength" {
                    if let ft = finished.templateId, let st = session.templateId, ft == st {
                        return (weekNum, dayIdx, sessionIdx)
                    }
                    if fallback == nil {
                        fallback = (weekNum, dayIdx, sessionIdx)
                    }
                }
            }
        }
        return fallback
    }

    /// "Done" when every prescribed exercise was touched and ≥90% of the
    /// prescribed sets were completed — that allows for small misses
    /// (skipped last set, tweaked form) without flipping to `modified`.
    /// Otherwise `.modified`. If absolutely nothing was logged, `.skipped`.
    private func completionStatusForStrength(
        prescribed: PrescribedSession,
        preprune: StrengthSession
    ) -> CompletionStatus {
        let loggedCompletedCount = preprune.exercises.reduce(0) {
            $0 + $1.sets.filter(\.completed).count
        }
        if loggedCompletedCount == 0 { return .skipped }

        guard let prescribedExercises = prescribed.exercises, !prescribedExercises.isEmpty else {
            // No prescription to compare against — anything logged is done.
            return .completed
        }

        let prescribedSetCount = prescribedExercises.reduce(0) { $0 + ($1.sets ?? 0) }
        guard prescribedSetCount > 0 else { return .completed }

        let allExercisesTouched = prescribedExercises.allSatisfy { pe in
            preprune.exercises.contains { fe in
                fe.name.caseInsensitiveCompare(pe.name) == .orderedSame
                    && fe.sets.contains(where: \.completed)
            }
        }
        let ratio = Double(loggedCompletedCount) / Double(prescribedSetCount)
        return (allExercisesTouched && ratio >= 0.9) ? .completed : .modified
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

    // MARK: - Chat read state (CoachBar)
    //
    // Tracks the wall-clock instant the athlete last opened the chat sheet.
    // The CoachBar uses this + the latest assistant message timestamp to
    // decide whether to render the "new message" treatment. Stored locally
    // in UserDefaults — single-user app, no cross-device sync needed.

    /// Most recent assistant message across the active conversation. Used
    /// by CoachBar both for the preview text and for the unread check.
    var latestAssistantMessage: ChatMessage? {
        currentMessages.last(where: { $0.role == "assistant" })
            ?? messages.last(where: { $0.role == "assistant" })
    }

    /// True when the latest assistant message arrived after the last time
    /// the athlete opened chat. Returns false when there is no message
    /// yet, or when the message has no createdAt (legacy row).
    var hasUnreadCoachMessage: Bool {
        guard let msg = latestAssistantMessage,
              let createdStr = msg.createdAt,
              let created = Self.parseISO(createdStr) else {
            return false
        }
        let lastSeenTs = UserDefaults.standard.double(forKey: lastSeenChatAtKey)
        let lastSeen = lastSeenTs > 0 ? Date(timeIntervalSince1970: lastSeenTs) : .distantPast
        return created > lastSeen
    }

    /// Called by MainTabView when the chat sheet opens, marking every
    /// existing assistant message as seen.
    func markChatAsSeen() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastSeenChatAtKey)
    }

    /// Tolerant ISO8601 parser — Supabase emits both fractional-second and
    /// whole-second timestamps depending on the column. Try both.
    private static func parseISO(_ s: String) -> Date? {
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: s) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: s)
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
    /// Debounced wrapper for `ensurePlanPreGenerated` — safe to call on
    /// every app foreground. Skips if called within the last 30 minutes.
    func preGenerateOnForeground() async {
        if let last = lastForegroundPreGenAt,
           Date().timeIntervalSince(last) < 1800 { return }
        lastForegroundPreGenAt = Date()
        await ensurePlanPreGenerated()
    }

    func ensurePlanPreGenerated() async {
        guard var plan = trainingPlan else { return }

        // Calendar math. Both dates at day granularity. We anchor to the
        // *Monday* of the plan's start week — not `startDate` itself —
        // because every other surface (sessionDateString, weekRangeLabel,
        // computeWeekAdherence, WeekStripCell's grid) does the same. A
        // plan whose startDate lands on, say, Sunday would otherwise
        // compute currentWeek a full week behind those surfaces, and
        // the Home card would render last week's grid.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let startStr = plan.startDate,
              let start = formatter.date(from: startStr) else { return }

        let calendar = Calendar.current
        let planMonday = mondayOf(start)
        let startDay = calendar.startOfDay(for: planMonday)
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
        guard dayWithinWeek >= 2 else { return }

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
                session.linkedWorkoutId = nil
            }
        }
    }

    /// Applies an arbitrary mutation to a single prescribed session and persists the plan.
    /// Used by the completion flow (mark completed / modified / swapped / skipped),
    /// manual workout match, auto-match, and clear-match.
    ///
    /// **Invariant:** a session whose scheduled date is strictly after today
    /// cannot have a completion marker set (`completionStatus != nil` or
    /// `completed == true`). Clearing an existing mark is always allowed.
    /// Callers don't need to pre-check the date — this method is the single
    /// chokepoint that enforces the rule and throws
    /// `SessionTimingError.cannotMarkFutureSession` on violation.
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

        // Guard: prescribed sessions scheduled after today cannot carry a
        // completion mark. The mutation happens on a local copy above; if
        // the check fails we throw before assigning back, so in-memory
        // `trainingPlan` stays consistent.
        //
        // Permissive when plan.startDate is absent (can't compute date).
        // Clearing a mark (end state has no completion fields set) is fine.
        let endStateIsMarked = session.completionStatus != nil || session.completed == true
        if endStateIsMarked,
           let sessionDateStr = scheduledDate(plan: plan, weekNum: weekNum, dayIdx: dayIdx),
           sessionDateStr > todayString() {
            throw SessionTimingError.cannotMarkFutureSession(weekNum: weekNum, dayIdx: dayIdx)
        }

        dayPlan.sessions[sessionIdx] = session
        wp.sessions[dayIdx] = dayPlan
        plan.weeklyPlans[key] = wp
        try await savePlan(plan)
    }

    /// Computes the `yyyy-MM-dd` date for a session at the given plan
    /// coordinates. Delegates to `sessionDateString`, which applies the
    /// same `mondayOf` snap every display surface uses. Without the
    /// snap, a plan whose `startDate` is not a Monday produced a date
    /// up to 6 days off — the future-session guard below was wrongly
    /// rejecting today's sessions as "scheduled in the future" and
    /// silently throwing, which is why status marks and workout links
    /// weren't persisting.
    private func scheduledDate(plan: TrainingPlan, weekNum: Int, dayIdx: Int) -> String? {
        sessionDateString(planStartDate: plan.startDate, weekNumber: weekNum, dayIdx: dayIdx)
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

    /// Full send-and-reply path used by both ChatTab (athlete types in
    /// the chat) and PostStatusChatSheet (post-session check-in). Posts
    /// the athlete's message into the active conversation immediately,
    /// then runs the agent loop and lands the assistant reply in the
    /// same thread. Any tool side-effects get applied via
    /// `applyAgentEffects`.
    ///
    /// Callers that need a loading indicator should `await` this (the
    /// full round-trip). Callers that need to dismiss a sheet fast
    /// (PostStatusChatSheet) can kick this in a detached `Task` — the
    /// reply lands in the chat thread in the background.
    @MainActor
    func sendUserMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        await ensureActiveConversation()
        let userMsg = ChatMessage.user(trimmed, conversationId: currentConversation?.id)
        try? await addMessage(userMsg)

        do {
            let recentSummaries = archivedConversations.prefix(3).compactMap(\.summary)
            let result = try await runAgentLoop(
                personality: settings.personality,
                customText: settings.customPrompt,
                messages: currentMessages,
                dataService: self,
                recentConversationSummaries: recentSummaries
            )
            let assistantMsg = ChatMessage.assistant(
                result.response,
                metadata: ChatMessageMetadata(
                    logged: result.hasWorkoutLogs,
                    nutritionLogged: result.hasNutritionLogs,
                    planChanged: result.hasPlanChanges,
                    appActionTaken: result.hasAppActions
                ),
                conversationId: currentConversation?.id,
                suggestedReplies: result.suggestedReplies.isEmpty ? nil : result.suggestedReplies
            )
            try? await addMessage(assistantMsg)
            await applyAgentEffects(result.effects)
            // Memory extraction is fire-and-forget so the reply returns
            // as soon as possible.
            Task { [weak self] in
                guard let self else { return }
                await extractMemory(
                    messages: self.currentMessages,
                    existingMemory: self.memory,
                    dataService: self
                )
            }
        } catch {
            NSLog("[chat] sendUserMessage failed: \(error)")
            let errorMsg = ChatMessage.assistant(
                "Sorry, I ran into an error. Please try again.\n\n\(error.localizedDescription)",
                metadata: ChatMessageMetadata(isError: true),
                conversationId: currentConversation?.id
            )
            try? await addMessage(errorMsg)
        }
    }

    /// Applies the agent's tool side-effects to DataService. Moved off
    /// of `CoachTab` so `sendUserMessage` above can be called from any
    /// surface (chat, post-status sheet) and the effects still land.
    @MainActor
    func applyAgentEffects(_ effects: [ToolEffect]) async {
        for effect in effects {
            switch effect {
            case .workoutLogged(let w):   try? await addCardio(w)
            case .cardioUpdated(let w):   try? await updateCardio(w)
            case .cardioDeleted(let id):  try? await deleteCardio(id)
            case .strengthDeleted(let id): try? await deleteStrength(id)
            case .nutritionLogged(let e): try? await addNutrition(e)
            case .planCreated(let p), .planUpdated(let p): try? await savePlan(p)
            case .planDeleted(let id, let h): try? await deletePlan(id, archiveTo: h)
            case .weekUpdated(let n, let wp):
                if var c = trainingPlan {
                    c.weeklyPlans[String(n)] = wp
                    try? await savePlan(c)
                }
            case .progressUpdated(let w, let p):
                if var c = trainingPlan {
                    c.currentWeek = w
                    c.currentPhase = p
                    try? await savePlan(c)
                }
            case .eventCreated(let e):    try? await addEvent(e)
            case .eventUpdated(let e):    try? await updateEvent(e)
            case .eventDeleted(let id):   try? await deleteEvent(id)
            case .memoryUpdated(let m):   try? await saveMemory(m)
            case .settingsUpdated(let s): try? await saveSettings(s)
            case .tabChanged(let t):      selectedTab = t
            }
        }
    }

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
