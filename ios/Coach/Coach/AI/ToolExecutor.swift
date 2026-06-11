import Foundation

// MARK: - Tool Executor

/// Executes a tool call locally using in-memory data from DataService.
/// Returns a ToolResult: `summary` goes back to the model, `effects` are
/// persisted by the caller after the agent loop completes.
@MainActor
func executeTool(name: String, input: [String: Any], dataService: DataService) async -> ToolResult {
    let today = todayString()

    switch name {

    // MARK: get_workouts
    case "get_workouts":
        let sport = input["sport"] as? String ?? "all"
        let days = input["days"] as? Int ?? 30
        let limit = input["limit"] as? Int ?? 20
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var brickIds: [String: [String: Any]] = [:]
        for b in dataService.bricks {
            for leg in b.legs {
                brickIds[leg.workoutId] = ["brickId": b.id, "transitionTime": b.transitionTime ?? 0]
            }
        }

        var all: [[String: Any]] = []

        for w in dataService.cardio {
            guard let d = formatter.date(from: w.date), d >= cutoff else { continue }
            guard sport == "all" || w.sport.rawValue == sport else { continue }
            var entry: [String: Any] = ["date": w.date, "sport": w.sport.rawValue, "duration": w.duration, "id": w.id]
            if let notes = w.notes { entry["notes"] = notes }
            if let brick = brickIds[w.id] { entry["brick"] = brick }
            all.append(entry)
        }

        if sport == "all" || sport == "strength" {
            for s in dataService.strength {
                guard let d = formatter.date(from: s.date), d >= cutoff else { continue }
                let sets = s.exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
                all.append(["date": s.date, "sport": "strength", "name": s.name, "duration": s.duration ?? 0, "sets": sets])
            }
        }

        all.sort { ($0["date"] as? String ?? "") > ($1["date"] as? String ?? "") }
        let limited = Array(all.prefix(limit))

        if limited.isEmpty {
            return ToolResult(summary: "No \(sport == "all" ? "" : sport + " ")workouts in last \(days) days.")
        }
        return ToolResult(summary: jsonString(["count": limited.count, "workouts": limited]))

    // MARK: get_training_plan
    case "get_training_plan":
        guard let plan = dataService.trainingPlan else {
            return ToolResult(summary: "No training plan set.")
        }
        let includeDetail = input["includePhaseDetail"] as? Bool ?? false
        let weekNum = input["weekNumber"] as? Int ?? plan.currentWeek

        var result: [String: Any] = [
            "raceName": plan.raceName ?? "",
            "raceDate": plan.raceDate ?? "",
            "totalWeeks": plan.totalWeeks,
            "currentWeek": plan.currentWeek,
            "currentPhase": plan.currentPhase,
            // Day indices in weekPlan.sessions are positional relative to
            // this anchor: dayOrder[i] is the weekday at index i. Spelled
            // out so the model never has to assume Monday-first.
            "weekStartDay": plan.weekAnchor.rawValue,
            "dayOrder": plan.weekAnchor.weekOrder.map(\.rawValue),
        ]

        if includeDetail {
            result["phases"] = plan.phases.map { p in
                ["number": p.number, "name": p.name, "weeks": p.weeks, "focus": p.focus ?? ""] as [String: Any]
            }
        }

        // Encode the WeeklyPlan via JSONEncoder so the LLM receives the exact
        // Codable shape it must send back to save_weekly_plan. Read/write are
        // symmetric — the LLM can read, edit, and write without format churn.
        if let wp = plan.weeklyPlans[String(weekNum)],
           let data = try? JSONEncoder().encode(wp),
           let obj = try? JSONSerialization.jsonObject(with: data),
           let dict = obj as? [String: Any] {
            result["weekPlan"] = dict
        }

        return ToolResult(summary: jsonString(result))

    // MARK: get_training_stats
    case "get_training_stats":
        let weeks = input["weeks"] as? Int ?? 4
        let cutoff = Calendar.current.date(byAdding: .day, value: -weeks * 7, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var weeklyVolume: [String: Int] = [:]
        for w in dataService.cardio {
            guard let d = formatter.date(from: w.date), d >= cutoff else { continue }
            weeklyVolume[w.sport.rawValue, default: 0] += w.duration
        }
        for s in dataService.strength {
            guard let d = formatter.date(from: s.date), d >= cutoff else { continue }
            weeklyVolume["strength", default: 0] += s.duration ?? 0
        }

        let totalMinutes = weeklyVolume.values.reduce(0, +)
        return ToolResult(summary: jsonString([
            "period": "\(weeks) weeks",
            "totalMinutes": totalMinutes,
            "totalHours": String(format: "%.1f", Double(totalMinutes) / 60.0),
            "bySport": weeklyVolume,
            "sessionsCount": dataService.cardio.filter { formatter.date(from: $0.date)! >= cutoff }.count + dataService.strength.filter { formatter.date(from: $0.date)! >= cutoff }.count,
        ]))

    // MARK: get_personal_records
    case "get_personal_records":
        let exercise = input["exercise"] as? String
        if let exercise, !exercise.isEmpty {
            let slug = exercise.slugified
            if let pr = dataService.prs[slug] {
                return ToolResult(summary: jsonString(["exercise": exercise, "pr": formatPR(pr)]))
            }
            return ToolResult(summary: "No PR found for '\(exercise)'.")
        }
        let allPRs = dataService.prs.mapValues { formatPR($0) }
        return ToolResult(summary: allPRs.isEmpty ? "No personal records yet." : jsonString(allPRs))

    // MARK: get_goals
    case "get_goals":
        let includeCompleted = input["include_completed"] as? Bool ?? false
        let filtered = includeCompleted ? dataService.events : dataService.events.filter { !$0.completed }
        if filtered.isEmpty { return ToolResult(summary: "No active goals.") }

        let goals = filtered.map { e -> [String: Any] in
            var g: [String: Any] = ["id": e.id, "name": e.name, "mode": e.mode.rawValue]
            if let date = e.date {
                g["date"] = date
                if let days = daysUntil(date) { g["daysUntil"] = days }
            }
            if let goal = e.goal { g["goal"] = goal }
            if let baseline = e.baseline { g["baseline"] = baseline }
            g["completed"] = e.completed
            return g
        }
        return ToolResult(summary: jsonString(["count": goals.count, "goals": goals]))

    // MARK: get_athlete_profile
    case "get_athlete_profile":
        let mem = dataService.memory
        return ToolResult(summary: jsonString([
            "permanent": [
                "equipment": mem.permanent.equipment,
                "facilities": mem.permanent.facilities,
                "schedule": [
                    "availableDays": mem.permanent.schedule.availableDays,
                    "preferredTimes": mem.permanent.schedule.preferredTimes,
                    "constraints": mem.permanent.schedule.constraints,
                ] as [String: Any],
                "medicalHistory": mem.permanent.medicalHistory,
                "dietaryConstraints": mem.permanent.dietaryConstraints,
                "communicationPrefs": mem.permanent.communicationPrefs,
                "safetyRules": mem.permanent.safetyRules.map { ["rule": $0.rule, "reason": $0.reason] },
            ] as [String: Any],
            "benchmarks": mem.benchmarks.map { ["metric": $0.metric, "value": $0.value, "testDate": $0.testDate ?? ""] as [String: Any] },
            "injuries": mem.injuries.map { ["area": $0.area, "status": $0.status, "severity": $0.severity, "triggers": $0.triggers, "safeActivities": $0.safeActivities, "modifications": $0.modifications] as [String: Any] },
            "observations": [
                "patterns": mem.observations.patterns,
                "motivators": mem.observations.motivators,
                "consistency": mem.observations.consistency,
                "currentFocus": mem.observations.currentFocus,
                // Structured shape so the LLM can read status / topic /
                // timestamp metadata when reasoning about which tracked
                // notes are still relevant. Only `tracking` notes are
                // surfaced — `resolved` ones stay hidden so they don't
                // clutter the agent's working context.
                "coachingNotes": mem.observations.coachingNotes
                    .filter { $0.status == .tracking }
                    .map { entry -> [String: Any] in
                        var dict: [String: Any] = [
                            "id": entry.id,
                            "text": entry.text,
                            "createdAt": entry.createdAt,
                            "status": entry.status.rawValue,
                        ]
                        if let topic = entry.relatedTopic { dict["relatedTopic"] = topic }
                        if let last = entry.lastReviewedAt { dict["lastReviewedAt"] = last }
                        return dict
                    },
            ] as [String: Any],
            "responseProfile": [
                "volumeVsIntensity": mem.responseProfile.volumeVsIntensity,
                "recoveryRate": mem.responseProfile.recoveryRate,
                "easyDayDiscipline": mem.responseProfile.easyDayDiscipline,
                "sessionPreferences": mem.responseProfile.sessionPreferences,
                "skipPatterns": mem.responseProfile.skipPatterns,
                "communicationNeeds": mem.responseProfile.communicationNeeds,
            ] as [String: Any],
        ]))

    // MARK: log_workout
    case "log_workout":
        guard let sportStr = input["sport"] as? String,
              let sport = Sport(rawValue: sportStr),
              let duration = intFrom(input["duration"]) else {
            print("⚠️ log_workout rejected — missing/unparseable sport or duration. input=\(input)")
            return ToolResult(summary: #"{"error":"Missing sport or duration"}"#)
        }
        let notes = input["notes"] as? String
        let date = input["date"] as? String ?? today
        let workout = CardioWorkout.create(sport: sport, duration: duration, notes: notes, date: date)
        return ToolResult(
            summary: jsonString(["logged": true, "workout": ["id": workout.id, "sport": sport.rawValue, "duration": duration, "date": date]]),
            effects: [.workoutLogged(workout)]
        )

    // MARK: log_nutrition
    case "log_nutrition":
        guard let meal = input["meal"] as? String,
              let timingStr = input["timing"] as? String,
              let timing = NutritionTiming(rawValue: timingStr) else {
            return ToolResult(summary: #"{"error":"Missing meal or timing"}"#)
        }
        let relatedWorkout = input["relatedWorkout"] as? String
        let date = input["date"] as? String ?? today
        let entry = NutritionEntry.create(meal: meal, timing: timing, relatedWorkout: relatedWorkout, date: date)
        return ToolResult(
            summary: jsonString(["logged": true, "nutrition": ["id": entry.id, "meal": meal, "timing": timingStr, "date": date]]),
            effects: [.nutritionLogged(entry)]
        )

    // MARK: get_nutrition
    case "get_nutrition":
        let days = input["days"] as? Int ?? 7
        let timing = input["timing"] as? String ?? "all"
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let filtered = dataService.nutrition.filter { entry in
            guard let d = formatter.date(from: entry.date), d >= cutoff else { return false }
            return timing == "all" || entry.timing.rawValue == timing
        }
        if filtered.isEmpty { return ToolResult(summary: "No nutrition entries in last \(days) days.") }
        let entries = filtered.map { ["meal": $0.meal, "timing": $0.timing.rawValue, "date": $0.date] as [String: Any] }
        return ToolResult(summary: jsonString(["count": entries.count, "entries": entries]))

    // MARK: create_training_plan (NEW — calls TrainingPlanGenerator)
    case "create_training_plan":
        guard let raceEventId = input["race_event_id"] as? String,
              let event = dataService.events.first(where: { $0.id == raceEventId }) else {
            return ToolResult(summary: #"{"error":"Event not found. Call get_goals first to find the race_event_id."}"#)
        }

        // Refuse to overwrite unless confirm_overwrite is true
        let confirmOverwrite = input["confirm_overwrite"] as? Bool ?? false
        if dataService.trainingPlan != nil, !confirmOverwrite {
            return ToolResult(summary: #"{"error":"A training plan already exists. Ask the athlete to confirm replacement, then call again with confirm_overwrite: true."}"#)
        }

        // Prefer an explicit total_weeks from the model (if the athlete asked
        // for a specific length). Otherwise compute it from today → race date.
        // No upper cap — a far-out race still gets a plan. The coach will
        // spend the early weeks in base building and shape specific prep
        // later, just like a real coach would.
        let computedWeeks = weeksBetweenTodayAnd(event.date)
        let totalWeeks: Int
        if let explicit = input["total_weeks"] as? Int, explicit > 0 {
            totalWeeks = explicit
        } else if let weeks = computedWeeks {
            totalWeeks = max(4, weeks)
        } else {
            // No race date on the event — last-resort fallback.
            totalWeeks = 12
        }
        let trainingDays = input["training_days_per_week"] as? Int
        let volumeHours = input["weekly_volume_hours"] as? Double
        let longRunDay = input["long_run_day"] as? String
        let strengthDays = input["strength_days"] as? [String]
        let planNotes = input["notes"] as? String

        do {
            let plan = try await TrainingPlanGenerator.generate(
                for: event,
                athleteMemory: dataService.memory,
                totalWeeks: totalWeeks,
                trainingDaysPerWeek: trainingDays,
                weeklyVolumeHours: volumeHours,
                longRunDay: longRunDay,
                strengthDays: strengthDays,
                notes: planNotes,
                dataService: dataService
            )
            let phasesSummary = plan.phases.map { "\($0.name) (\($0.weeks)w)" }.joined(separator: ", ")

            // Snapshot every week the generator actually populated (stubs —
            // weeks with all-empty `sessions` arrays — get snapshotted later
            // when `generate_week_plan` fills them).
            var effects: [ToolEffect] = [.planCreated(plan)]
            for (weekKey, wp) in plan.weeklyPlans {
                guard let weekNum = Int(weekKey),
                      wp.sessions.contains(where: { !$0.sessions.isEmpty }) else { continue }
                effects.append(.planSnapshotCreated(PlanSnapshot(
                    id: UUID(),
                    userId: nil,
                    planId: plan.id,
                    weekNumber: weekNum,
                    frozenAt: nil,
                    source: .createPlan,
                    sessions: wp.sessions,
                    phase: wp.phase,
                    focusOfWeek: wp.focusOfWeek
                )))
            }

            return ToolResult(
                summary: jsonString([
                    "created": true,
                    "totalWeeks": plan.totalWeeks,
                    "phases": phasesSummary,
                    "currentWeek": plan.currentWeek,
                    "weeksPopulated": plan.weeklyPlans.count,
                ]),
                effects: effects
            )
        } catch {
            return ToolResult(summary: jsonString(["error": "Plan generation failed: \(error.localizedDescription)"]))
        }

    // MARK: generate_week_plan (NEW — lazy per-week generation)
    case "generate_week_plan":
        guard let plan = dataService.trainingPlan else {
            return ToolResult(summary: jsonString(["error": "No training plan to generate a week for. Create one first with create_training_plan."]))
        }
        guard let weekNum = intFrom(input["weekNumber"]), weekNum >= 1, weekNum <= plan.totalWeeks else {
            print("⚠️ generate_week_plan rejected — missing/out-of-range weekNumber. input=\(input)")
            return ToolResult(summary: jsonString(["error": "weekNumber must be between 1 and \(plan.totalWeeks)."]))
        }
        guard let goalId = plan.goalId,
              let event = dataService.events.first(where: { $0.id == goalId }) else {
            return ToolResult(summary: jsonString(["error": "Couldn't find the race event this plan is anchored to."]))
        }

        // Determine snapshot source before the generator runs. A week
        // whose existing sessions are all empty is a stub being filled
        // for the first time (source=generate_week); any pre-existing
        // session content means we're overwriting a real prescription
        // (source=regenerate_week) and want the prior snapshot kept as
        // history.
        let priorWasStub: Bool = {
            guard let prior = plan.weeklyPlans[String(weekNum)] else { return true }
            return prior.sessions.allSatisfy { $0.sessions.isEmpty }
        }()

        do {
            let week = try await TrainingPlanGenerator.generateWeek(
                weekNumber: weekNum,
                in: plan,
                event: event,
                athleteMemory: dataService.memory,
                dataService: dataService
            )
            let dayCount = week.sessions.count
            let snapshot = PlanSnapshot(
                id: UUID(),
                userId: nil,
                planId: plan.id,
                weekNumber: weekNum,
                frozenAt: nil,
                source: priorWasStub ? .generateWeek : .regenerateWeek,
                sessions: week.sessions,
                phase: week.phase,
                focusOfWeek: week.focusOfWeek
            )
            return ToolResult(
                summary: jsonString([
                    "generated": true,
                    "weekNumber": weekNum,
                    "focusOfWeek": week.focusOfWeek ?? "",
                    "daysPopulated": dayCount,
                ]),
                effects: [
                    .weekUpdated(weekNumber: weekNum, weekPlan: week),
                    .planSnapshotCreated(snapshot),
                ]
            )
        } catch {
            return ToolResult(summary: jsonString(["error": "Week generation failed: \(error.localizedDescription)"]))
        }

    // MARK: save_training_plan (legacy — kept for compat, no-op effect)
    case "save_training_plan":
        return ToolResult(summary: jsonString(["saved": true, "plan": input]))

    // MARK: save_weekly_plan
    case "save_weekly_plan":
        // Wholesale replacement — prefer patch_weekly_plan for surgical edits.
        // Input must match the WeeklyPlan Codable shape (same as what
        // get_training_plan returns under "weekPlan").
        guard dataService.trainingPlan != nil else {
            return ToolResult(summary: #"{"error":"No training plan to modify. Create one first with create_training_plan."}"#)
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: input)
            let wp = try JSONDecoder().decode(WeeklyPlan.self, from: data)
            if let err = firstFutureCompletionMark(
                in: wp,
                planStartDate: dataService.trainingPlan?.startDate,
                anchor: dataService.trainingPlan?.weekAnchor ?? .monday
            ) {
                return ToolResult(summary: jsonString(["error": err]))
            }
            return ToolResult(
                summary: jsonString([
                    "saved": true,
                    "weekNumber": wp.weekNumber,
                    "dayCount": wp.sessions.count,
                ]),
                effects: [.weekUpdated(weekNumber: wp.weekNumber, weekPlan: wp)]
            )
        } catch {
            return ToolResult(summary: jsonString([
                "error": "Invalid weekPlan shape: \(error.localizedDescription). Expected the same shape returned by get_training_plan under weekPlan.",
            ]))
        }

    // MARK: patch_weekly_plan
    case "patch_weekly_plan":
        // Surgical, op-based edits to a single week. Applies a list of
        // operations atomically: if any op fails, none are applied and we
        // return an error. On success, emits .weekUpdated with the mutated
        // WeeklyPlan — ChatTab handles persistence via DataService.savePlan.
        guard let plan = dataService.trainingPlan else {
            return ToolResult(summary: #"{"error":"No training plan to patch. Create one first with create_training_plan."}"#)
        }
        guard let weekNum = intFrom(input["weekNumber"]) else {
            print("⚠️ patch_weekly_plan rejected — missing/unparseable weekNumber. input=\(input)")
            return ToolResult(summary: #"{"error":"patch_weekly_plan requires weekNumber."}"#)
        }
        guard var wp = plan.weeklyPlans[String(weekNum)] else {
            return ToolResult(summary: jsonString(["error": "Week \(weekNum) not found in plan. Call get_training_plan first to see available weeks."]))
        }
        guard let operations = input["operations"] as? [[String: Any]], !operations.isEmpty else {
            print("⚠️ patch_weekly_plan rejected — missing/empty operations array. input=\(input)")
            return ToolResult(summary: #"{"error":"patch_weekly_plan requires a non-empty operations array."}"#)
        }

        // Carry the athlete's stated reason onto every edit row in this
        // batch (Section 10 prompt asks the model to forward it). Treat
        // empty/whitespace as nil so retrospective rendering doesn't
        // get bogus blank rows.
        let rawReason = (input["reason"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let reason: String? = (rawReason?.isEmpty == false) ? rawReason : nil

        do {
            var pendingEdits: [PlanEdit] = []
            for (i, op) in operations.enumerated() {
                let beforeSlice = captureAffectedSlice(op, in: wp)
                do {
                    try applyPatchOperation(op, to: &wp)
                } catch let PatchError.invalidOp(msg) {
                    throw PatchError.invalidOp("op #\(i): \(msg)")
                }
                let afterSlice = captureAffectedSlice(op, in: wp)

                if let edit = buildPlanEdit(
                    op: op,
                    planId: plan.id,
                    weekNumber: wp.weekNumber,
                    before: beforeSlice,
                    after: afterSlice,
                    reason: reason
                ) {
                    pendingEdits.append(edit)
                }
            }
            if let err = firstFutureCompletionMark(in: wp, planStartDate: plan.startDate, anchor: plan.weekAnchor) {
                return ToolResult(summary: jsonString(["error": err]))
            }
            var effects: [ToolEffect] = [.weekUpdated(weekNumber: wp.weekNumber, weekPlan: wp)]
            if !pendingEdits.isEmpty {
                effects.append(.planEditsLogged(pendingEdits))
            }
            return ToolResult(
                summary: jsonString([
                    "applied": operations.count,
                    "weekNumber": wp.weekNumber,
                ]),
                effects: effects
            )
        } catch let PatchError.invalidOp(msg) {
            return ToolResult(summary: jsonString(["error": "patch rejected — \(msg)"]))
        } catch {
            return ToolResult(summary: jsonString(["error": "patch rejected: \(error.localizedDescription)"]))
        }

    // MARK: update_plan_progress
    case "update_plan_progress":
        // Previously defaulted both to 1 on cast failure — silently
        // corrupted plan progress when the cast failed (always, before
        // the AnyCodable fix). Now we require both and surface a clear
        // error so the LLM can retry rather than blindly resetting the
        // athlete to week 1, phase 1.
        guard let week = intFrom(input["currentWeek"]),
              let phase = intFrom(input["currentPhase"]) else {
            print("⚠️ update_plan_progress rejected — missing/unparseable currentWeek or currentPhase. input=\(input)")
            return ToolResult(summary: #"{"error":"update_plan_progress requires currentWeek and currentPhase as integers."}"#)
        }
        return ToolResult(
            summary: jsonString(["updated": true, "currentWeek": week, "currentPhase": phase]),
            effects: [.progressUpdated(currentWeek: week, currentPhase: phase)]
        )

    // MARK: get_week_review
    case "get_week_review":
        guard let plan = dataService.trainingPlan else { return ToolResult(summary: "No training plan.") }
        let weekNum = input["weekNumber"] as? Int ?? max(1, plan.currentWeek - 1)
        let includeMultiWeek = input["includeMultiWeek"] as? Bool ?? false

        guard let review = computeWeekAdherence(plan: plan, weekNum: weekNum, cardio: dataService.cardio, strength: dataService.strength) else {
            return ToolResult(summary: "No data for week \(weekNum).")
        }

        var result: [String: Any] = [
            "weekNumber": review.weekNumber,
            "adherence": "\(review.adherence)%",
            "prescribed": review.prescribed,
            "completed": review.completed,
            "shortened": review.shortened,
            "missed": review.missed,
            "substituted": review.substituted,
        ]
        if !review.missedByType.isEmpty { result["missedByType"] = review.missedByType }

        if includeMultiWeek {
            let patterns = computeMultiWeekPatterns(plan: plan, currentWeek: plan.currentWeek, cardio: dataService.cardio, strength: dataService.strength)
            if !patterns.isEmpty { result["multiWeekPatterns"] = patterns }
        }

        return ToolResult(summary: jsonString(result))

    // MARK: get_plan_history
    case "get_plan_history":
        if dataService.planHistory.isEmpty { return ToolResult(summary: "No past plans.") }
        let plans = dataService.planHistory.map { p in
            [
                "raceName": p.raceName ?? "",
                "endReason": p.endReason ?? "",
                "adherence": p.adherence ?? "",
                "totalWeeks": p.totalWeeks ?? 0,
                "completedWeeks": p.completedWeeks ?? 0,
            ] as [String: Any]
        }
        return ToolResult(summary: jsonString(["count": plans.count, "plans": plans]))

    // MARK: start_weekly_review_check_in
    case "start_weekly_review_check_in":
        let reviewAnchor = dataService.settings.weekAnchor
        let weekStartStr = (input["week_start_date"] as? String)
            ?? WeekBoundary.reviewWeekStartString(of: Date(), anchor: reviewAnchor)
        let weekStart = parseDate(weekStartStr) ?? Date()

        do {
            let review = try await WeeklyArtifactsService.createInProgressReview(weekStart: weekStart, anchor: reviewAnchor)

            // Build a compact adherence summary to seed the agent's
            // framing of the conversation. If no plan exists or the
            // week isn't part of it, return what we can without
            // fabricating numbers.
            var adherenceLine: String?
            if let plan = dataService.trainingPlan,
               let weekNumber = weekNumberFor(weekStartDate: weekStartStr, plan: plan),
               let adherence = computeWeekAdherence(
                    plan: plan, weekNum: weekNumber,
                    cardio: dataService.cardio, strength: dataService.strength
               ) {
                adherenceLine = "Adherence \(adherence.adherence)% — \(adherence.completed) completed, \(adherence.shortened) shortened, \(adherence.missed) missed, \(adherence.substituted) substituted of \(adherence.prescribed) prescribed."
            }

            var summary: [String: Any] = [
                "review_id": review.id.uuidString,
                "week_start_date": review.weekStartDate,
                "week_end_date": review.weekEndDate,
                "resumed": review.completedAt == nil && hasAnyPopulatedField(review),
            ]
            if let adherenceLine { summary["adherence_summary"] = adherenceLine }
            return ToolResult(
                summary: jsonString(summary),
                effects: [.reviewUpdated(review)]
            )
        } catch {
            return ToolResult(summary: jsonString(["error": "Failed to start check-in: \(error.localizedDescription)"]))
        }

    // MARK: populate_review_field
    case "populate_review_field":
        guard let idStr = input["review_id"] as? String,
              let reviewId = UUID(uuidString: idStr) else {
            return ToolResult(summary: jsonString(["error": "review_id required"]))
        }
        guard let fields = input["fields"] as? [String: Any], !fields.isEmpty else {
            return ToolResult(summary: jsonString(["error": "fields object required (non-empty)"]))
        }

        let patch = ReviewFieldPatch(
            sleep_avg_hours:     doubleFrom(fields["sleep_avg_hours"]),
            energy_rating:       intFrom(fields["energy_rating"]),
            motivation_rating:   intFrom(fields["motivation_rating"]),
            soreness_level:      fields["soreness_level"]  as? String,
            soreness_location:   fields["soreness_location"] as? String,
            pain_flag:           fields["pain_flag"]       as? Bool,
            pain_description:    fields["pain_description"] as? String,
            life_stress_rating:  intFrom(fields["life_stress_rating"]),
            body_weight:         doubleFrom(fields["body_weight"]),
            best_session_text:   fields["best_session_text"] as? String,
            best_session_id:     (fields["best_session_id"] as? String).flatMap(UUID.init(uuidString:)),
            worst_session_text:  fields["worst_session_text"] as? String,
            worst_session_id:    (fields["worst_session_id"] as? String).flatMap(UUID.init(uuidString:)),
            life_context:        fields["life_context"]    as? String,
            questions:           fields["questions"]       as? String,
            next_week_focus:     fields["next_week_focus"] as? String
        )

        do {
            let updated = try await WeeklyArtifactsService.updateReviewFields(id: reviewId, patch: patch)
            return ToolResult(
                summary: jsonString(["review_id": updated.id.uuidString, "ok": true]),
                effects: [.reviewUpdated(updated)]
            )
        } catch {
            return ToolResult(summary: jsonString(["error": "Failed to populate fields: \(error.localizedDescription)"]))
        }

    // MARK: complete_weekly_review
    case "complete_weekly_review":
        guard let idStr = input["review_id"] as? String,
              let reviewId = UUID(uuidString: idStr) else {
            return ToolResult(summary: jsonString(["error": "review_id required"]))
        }

        // Resolve the in-memory review (post any pending populate calls)
        // to find its week_start_date; needed for adherence computation.
        let weekStartDate: String? = dataService.weeklyReviews
            .first(where: { $0.id == reviewId })?.weekStartDate

        // Auto-computed adherence_pct: prefer the plan-based percentage
        // if we can find the matching plan-week, otherwise leave nil.
        var adherencePct: Double?
        if let weekStartDate,
           let plan = dataService.trainingPlan,
           let weekNumber = weekNumberFor(weekStartDate: weekStartDate, plan: plan),
           let adherence = computeWeekAdherence(
                plan: plan, weekNum: weekNumber,
                cardio: dataService.cardio, strength: dataService.strength
           ) {
            adherencePct = Double(adherence.adherence)
        }

        do {
            let finalized = try await WeeklyArtifactsService.markReviewComplete(
                id: reviewId, adherencePct: adherencePct
            )

            // PR 1.3: run the review-response generator and the preview
            // generator in parallel. Each takes ~5–10s; running them
            // concurrently roughly halves wall time. Both swallow their
            // own failures and return nil — a missing AI half doesn't
            // block the athlete-side completion, and the chat reply
            // surfaces what we got.
            let upcomingPlanWeek = upcomingWeekPlan(after: finalized, plan: dataService.trainingPlan)
            let previousPlanWeek = currentWeekPlan(for: finalized, plan: dataService.trainingPlan)
            let metrics = WeeklyPreviewMetrics.compute(
                upcoming: upcomingPlanWeek,
                previous: previousPlanWeek
            )

            async let reviewOut: WeeklyReviewResponseGenerator.Output? =
                WeeklyReviewResponseGenerator.generate(
                    review: finalized,
                    plan: dataService.trainingPlan,
                    memory: dataService.memory,
                    recentCardio: dataService.cardio,
                    recentStrength: dataService.strength
                )
            async let previewOut: WeeklyPreviewGenerator.Output? =
                WeeklyPreviewGenerator.generate(
                    review: finalized,
                    upcomingWeek: upcomingPlanWeek,
                    plan: dataService.trainingPlan,
                    memory: dataService.memory,
                    trainingLoad: dataService.trainingLoad.last.map {
                        TrainingLoadSnapshot(
                            asOf: $0.date,
                            ctl: $0.ctl, atl: $0.atl, tsb: $0.tsb,
                            ctlRamp7d: nil
                        )
                    },
                    metrics: metrics
                )

            let (review, preview) = await (reviewOut, previewOut)

            var effects: [ToolEffect] = [.reviewUpdated(finalized)]

            // Persist + dispatch the AI review response if we got one.
            var reviewWithAI = finalized
            if let review {
                if let attached = try? await WeeklyArtifactsService.attachAIResponse(
                    reviewId: finalized.id,
                    text: review.text,
                    components: review.components,
                    patternsDetected: review.patternsDetected
                ) {
                    reviewWithAI = attached
                    effects = [.reviewUpdated(attached)]
                }
            }

            // Build + persist the preview if generation succeeded.
            var savedPreview: WeeklyPreview?
            if let preview {
                let upcomingStart = nextWeekStartString(after: finalized.weekEndDate)
                let upcomingEnd   = weekEndString(after: upcomingStart)
                let weekly = WeeklyPreview(
                    id: UUID(),
                    userId: nil,
                    weekStartDate: upcomingStart,
                    weekEndDate: upcomingEnd,
                    createdAt: nil,
                    pairedReviewId: finalized.id,
                    theme: preview.theme,
                    themeCategory: preview.themeCategory,
                    macroPosition: preview.macroPosition,
                    totalPlannedHours: metrics.totalPlannedHours,
                    totalPlannedDistance: metrics.totalPlannedDistance,
                    totalPlannedTss: nil,
                    deltaFromPreviousWeekPct: metrics.deltaFromPreviousWeekPct,
                    numQualitySessions: metrics.numQualitySessions,
                    numEasySessions: metrics.numEasySessions,
                    keySessions: preview.keySessions,
                    watchOuts: preview.watchOuts,
                    tacticalNotes: preview.tacticalNotes,
                    lifeManagementNotes: preview.lifeManagementNotes,
                    renderedProse: preview.renderedProse,
                    closingQuestion: preview.closingQuestion,
                    readAt: nil,
                    rereadCount: 0,
                    respondedTo: false
                )
                if let saved = try? await WeeklyArtifactsService.savePreview(weekly) {
                    savedPreview = saved
                    effects.append(.previewSaved(saved))
                }
            }

            return ToolResult(
                summary: jsonString([
                    "review_id":          reviewWithAI.id.uuidString,
                    "completed_at":       reviewWithAI.completedAt as Any,
                    "adherence_pct":      reviewWithAI.adherencePct as Any,
                    "ai_response_text":   reviewWithAI.aiResponseText as Any,
                    "preview_id":         savedPreview?.id.uuidString as Any,
                    "preview_theme":      savedPreview?.theme as Any,
                    "ok":                 true,
                ]),
                effects: effects
            )
        } catch {
            return ToolResult(summary: jsonString(["error": "Failed to complete review: \(error.localizedDescription)"]))
        }

    // MARK: app_action
    case "app_action":
        let action = input["action"] as? String ?? ""
        let target = input["target"] as? String ?? ""
        let data = input["data"] as? [String: Any] ?? [:]

        switch (action, target) {

        case ("create", "goal"):
            guard let name = (data["name"] as? String).flatMap({ $0.isEmpty ? nil : $0 }) else {
                return ToolResult(summary: jsonString(["error": "Create goal requires data.name"]))
            }
            let validPresetIds = Set(EventPreset.all.map(\.id))
            let rawPresetId = data["presetId"] as? String ?? "custom"
            let presetId = validPresetIds.contains(rawPresetId) ? rawPresetId : "custom"
            let preset = EventPreset.all.first(where: { $0.id == presetId })
            let modeString = data["mode"] as? String
            let mode: EventMode = modeString.flatMap(EventMode.init(rawValue:)) ?? preset?.defaultMode ?? .goal

            var event = Event.create(presetId: presetId, name: name, mode: mode)

            if let date = (data["date"] as? String) ?? (data["raceDate"] as? String), !date.isEmpty {
                event.date = date
            }
            if let location = data["location"] as? String, !location.isEmpty {
                event.location = location
            }
            if let distance = data["distance"] as? String, !distance.isEmpty {
                event.distance = distance
            }
            if let goal = data["goal"] as? String, !goal.isEmpty {
                event.goal = goal
            }
            if let stretch = (data["stretchGoal"] as? String) ?? (data["stretch_goal"] as? String),
               !stretch.isEmpty {
                event.stretchGoal = stretch
            }
            if let baseline = data["baseline"] as? String, !baseline.isEmpty {
                event.baseline = baseline
            }
            if let url = (data["url"] as? String) ?? (data["officialUrl"] as? String), !url.isEmpty {
                event.url = url
            }
            if let bib = data["bibNumber"] as? String, !bib.isEmpty {
                event.bibNumber = bib
            }

            return ToolResult(
                summary: jsonString([
                    "success": true,
                    "event": [
                        "id": event.id,
                        "name": event.name,
                        "date": event.date ?? "",
                    ],
                ]),
                effects: [.eventCreated(event)]
            )

        case ("update", "goal"):
            guard let id = input["id"] as? String, !id.isEmpty else {
                return ToolResult(summary: jsonString(["error": "Update goal requires id"]))
            }
            guard var event = dataService.events.first(where: { $0.id == id }) else {
                return ToolResult(summary: jsonString(["error": "Goal with id \(id) not found. Call get_goals first."]))
            }

            if let name = data["name"] as? String, !name.isEmpty {
                event.name = name
            }
            if let rawPresetId = data["presetId"] as? String, !rawPresetId.isEmpty {
                let validPresetIds = Set(EventPreset.all.map(\.id))
                if validPresetIds.contains(rawPresetId) {
                    event.presetId = rawPresetId
                }
                // Silently ignore invalid presetId on update — don't destroy existing value.
            }
            if let modeStr = data["mode"] as? String, let mode = EventMode(rawValue: modeStr) {
                event.mode = mode
            }
            if let date = (data["date"] as? String) ?? (data["raceDate"] as? String) {
                event.date = date.isEmpty ? nil : date
            }
            if let location = data["location"] as? String {
                event.location = location.isEmpty ? nil : location
            }
            if let distance = data["distance"] as? String {
                event.distance = distance.isEmpty ? nil : distance
            }
            if let goal = data["goal"] as? String {
                event.goal = goal.isEmpty ? nil : goal
            }
            if let stretch = (data["stretchGoal"] as? String) ?? (data["stretch_goal"] as? String) {
                event.stretchGoal = stretch.isEmpty ? nil : stretch
            }
            if let baseline = data["baseline"] as? String {
                event.baseline = baseline.isEmpty ? nil : baseline
            }
            if let url = (data["url"] as? String) ?? (data["officialUrl"] as? String) {
                event.url = url.isEmpty ? nil : url
            }
            if let bib = data["bibNumber"] as? String {
                event.bibNumber = bib.isEmpty ? nil : bib
            }

            return ToolResult(
                summary: jsonString([
                    "success": true,
                    "event": [
                        "id": event.id,
                        "name": event.name,
                        "date": event.date ?? "",
                    ],
                ]),
                effects: [.eventUpdated(event)]
            )

        case ("delete", "goal"):
            guard let id = input["id"] as? String, !id.isEmpty else {
                return ToolResult(summary: jsonString(["error": "Delete goal requires id"]))
            }
            guard let event = dataService.events.first(where: { $0.id == id }) else {
                return ToolResult(summary: jsonString(["error": "Goal with id \(id) not found. Call get_goals first."]))
            }
            return ToolResult(
                summary: jsonString([
                    "success": true,
                    "deleted": ["id": event.id, "name": event.name],
                ]),
                effects: [.eventDeleted(id: event.id)]
            )

        case ("update", "workout"):
            guard let id = input["id"] as? String, !id.isEmpty else {
                return ToolResult(summary: jsonString(["error": "Update workout requires id"]))
            }
            guard var workout = dataService.cardio.first(where: { $0.id == id }) else {
                return ToolResult(summary: jsonString(["error": "Workout with id \(id) not found. Call get_workouts first."]))
            }

            if let dateStr = data["date"] as? String, !dateStr.isEmpty { workout.date = dateStr }
            if let sportStr = data["sport"] as? String, let sport = Sport(rawValue: sportStr) {
                workout.sport = sport
            }
            if let duration = intFrom(data["duration"]) { workout.duration = duration }
            if let distance = data["distance"] as? String {
                workout.distance = distance.isEmpty ? nil : distance
            }
            if let pace = data["pace"] as? String {
                workout.pace = pace.isEmpty ? nil : pace
            }
            if let notes = data["notes"] as? String {
                workout.notes = notes.isEmpty ? nil : notes
            }
            if let avgHR = intFrom(data["avgHR"]) { workout.avgHR = avgHR }
            if let maxHR = intFrom(data["maxHR"]) { workout.maxHR = maxHR }
            if let calories = intFrom(data["calories"]) { workout.calories = calories }
            if let location = data["location"] as? String {
                workout.location = location.isEmpty ? nil : location
            }

            return ToolResult(
                summary: jsonString([
                    "success": true,
                    "workout": [
                        "id": workout.id,
                        "sport": workout.sport.rawValue,
                        "duration": workout.duration,
                        "date": workout.date,
                    ],
                ]),
                effects: [.cardioUpdated(workout)]
            )

        case ("delete", "workout"):
            guard let id = input["id"] as? String, !id.isEmpty else {
                return ToolResult(summary: jsonString(["error": "Delete workout requires id"]))
            }
            guard let workout = dataService.cardio.first(where: { $0.id == id }) else {
                return ToolResult(summary: jsonString(["error": "Workout with id \(id) not found. Call get_workouts first."]))
            }
            return ToolResult(
                summary: jsonString([
                    "success": true,
                    "deleted": [
                        "id": workout.id,
                        "sport": workout.sport.rawValue,
                        "date": workout.date,
                    ],
                ]),
                effects: [.cardioDeleted(id: workout.id)]
            )

        case ("delete", "strength_workout"):
            guard let id = input["id"] as? String, !id.isEmpty else {
                return ToolResult(summary: jsonString(["error": "Delete strength workout requires id"]))
            }
            guard let session = dataService.strength.first(where: { $0.id == id }) else {
                return ToolResult(summary: jsonString(["error": "Strength session with id \(id) not found. Call get_workouts first."]))
            }
            return ToolResult(
                summary: jsonString([
                    "success": true,
                    "deleted": ["id": session.id, "name": session.name, "date": session.date],
                ]),
                effects: [.strengthDeleted(id: session.id)]
            )

        case ("delete", "plan"):
            guard let plan = dataService.trainingPlan else {
                return ToolResult(summary: jsonString(["error": "No training plan to delete."]))
            }
            let reason = data["reason"] as? String
            let notes = data["notes"] as? String

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let endedDate = formatter.string(from: Date())

            let history = PlanHistory(
                id: UUID().uuidString,
                raceName: plan.raceName,
                goalId: plan.goalId,
                raceDate: plan.raceDate,
                startDate: plan.startDate,
                endedDate: endedDate,
                totalWeeks: plan.totalWeeks,
                completedWeeks: max(0, plan.currentWeek - 1),
                totalPhases: plan.phases.count,
                phasesCompleted: max(0, plan.currentPhase - 1),
                phases: plan.phases,
                endReason: reason,
                endNotes: notes,
                adherence: nil,
                weeklyAdherence: nil
            )

            return ToolResult(
                summary: jsonString([
                    "success": true,
                    "deleted": ["id": plan.id, "raceName": plan.raceName ?? ""],
                    "archivedAs": history.id,
                ]),
                effects: [.planDeleted(id: plan.id, history: history)]
            )

        case ("update", "coaching_memory"):
            guard let category = data["category"] as? String, !category.isEmpty else {
                return ToolResult(summary: jsonString(["error": "Update memory requires data.category"]))
            }
            let operation = data["operation"] as? String ?? "add"
            var memory = dataService.memory
            do {
                try applyMemoryUpdate(
                    category: category,
                    operation: operation,
                    value: data["value"],
                    itemId: data["id"] as? String,
                    to: &memory
                )
                return ToolResult(
                    summary: jsonString([
                        "success": true,
                        "category": category,
                        "operation": operation,
                    ]),
                    effects: [.memoryUpdated(memory)]
                )
            } catch let MemoryUpdateError.invalid(msg) {
                return ToolResult(summary: jsonString(["error": "Memory update failed: \(msg)"]))
            } catch {
                return ToolResult(summary: jsonString(["error": "Memory update failed: \(error.localizedDescription)"]))
            }

        case ("update", "settings"), ("settings", "app"), ("update", "app"):
            var settings = dataService.settings
            if let personalityStr = data["personality"] as? String,
               let personality = Personality(rawValue: personalityStr) {
                settings.personality = personality
            }
            if let weekStartStr = data["weekStartDay"] as? String {
                guard let day = Weekday(rawValue: weekStartStr.lowercased()) else {
                    return ToolResult(summary: jsonString(["error": "Unknown weekStartDay '\(weekStartStr)'. Use a lowercase day name: monday, tuesday, wednesday, thursday, friday, saturday, sunday."]))
                }
                settings.weekStartDay = day
            }
            if let appearanceStr = data["appearance"] as? String,
               let appearance = Appearance(rawValue: appearanceStr) {
                settings.appearance = appearance
                settings.darkMode = (appearance == .dark)
            }
            // Legacy darkMode bool
            if let darkMode = data["darkMode"] as? Bool {
                settings.darkMode = darkMode
                if settings.appearance == nil || data["appearance"] == nil {
                    settings.appearance = darkMode ? .dark : .light
                }
            }
            if let customPrompt = data["customPrompt"] as? String {
                settings.customPrompt = customPrompt
            }
            return ToolResult(
                summary: jsonString([
                    "success": true,
                    "settings": [
                        "appearance": settings.effectiveAppearance.rawValue,
                        "personality": settings.personality.rawValue,
                        "weekStartDay": settings.weekAnchor.rawValue,
                    ],
                    "note": data["weekStartDay"] != nil
                        ? "weekStartDay applies to the weekly check-in rhythm, analytics, and the NEXT training plan. The current plan keeps the week anchor it was created with."
                        : "",
                ]),
                effects: [.settingsUpdated(settings)]
            )

        case ("navigate", "app"), ("navigate", "tab"):
            guard let tab = data["tab"] as? String, !tab.isEmpty else {
                return ToolResult(summary: jsonString(["error": "Navigate requires data.tab (one of: coach, goals, plan, analytics, log)"]))
            }
            let valid = Set(["coach", "goals", "plan", "analytics", "log"])
            guard valid.contains(tab) else {
                return ToolResult(summary: jsonString(["error": "Unknown tab '\(tab)'. Must be one of: coach, goals, plan, analytics, log."]))
            }
            return ToolResult(
                summary: jsonString(["success": true, "tab": tab]),
                effects: [.tabChanged(tab: tab)]
            )

        default:
            return ToolResult(summary: jsonString([
                "error": "Not yet implemented: \(action) \(target). Supported: create/update/delete goal, update/delete workout, delete strength_workout, delete plan, update coaching_memory, update settings, navigate app.",
            ]))
        }

    default:
        return ToolResult(summary: #"{"error":"Unknown tool: \#(name)"}"#)
    }
}

// MARK: - Weekly review helpers

/// Parse "yyyy-MM-dd" → Date in device-local TZ. nil for malformed input.
private func parseDate(_ s: String) -> Date? {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = .current
    return f.date(from: s)
}

/// Map a week-start date string (athlete's review anchor) to the
/// matching plan week number, or nil if the date doesn't fall inside any
/// week of the plan. Snaps the plan start to the PLAN's anchor (matching
/// sessionDateString) before the day math; floor division then absorbs
/// any partial offset when the review anchor differs from the plan's.
private func weekNumberFor(weekStartDate: String, plan: TrainingPlan) -> Int? {
    guard let planStartStr = plan.startDate,
          let rawPlanStart = parseDate(planStartStr),
          let target = parseDate(weekStartDate) else { return nil }
    let planStart = weekStart(of: rawPlanStart, anchor: plan.weekAnchor)
    let cal = Calendar.current
    let days = cal.dateComponents([.day], from: planStart, to: target).day ?? 0
    guard days >= 0 else { return nil }
    let weekIndex = days / 7
    let weekNumber = weekIndex + 1
    guard plan.weeklyPlans[String(weekNumber)] != nil else { return nil }
    return weekNumber
}

/// The plan-week for the week the review just covered. Used as the
/// baseline for the upcoming-week delta in `WeeklyPreviewMetrics`.
@MainActor
private func currentWeekPlan(for review: WeeklyReview, plan: TrainingPlan?) -> WeeklyPlan? {
    guard let plan,
          let n = weekNumberFor(weekStartDate: review.weekStartDate, plan: plan) else {
        return nil
    }
    return plan.weeklyPlans[String(n)]
}

/// The plan-week for the week we're about to preview (one after the
/// review's window). Returns nil if the plan has no week N+1.
@MainActor
private func upcomingWeekPlan(after review: WeeklyReview, plan: TrainingPlan?) -> WeeklyPlan? {
    guard let plan,
          let n = weekNumberFor(weekStartDate: review.weekStartDate, plan: plan) else {
        return nil
    }
    return plan.weeklyPlans[String(n + 1)]
}

/// Given the last day of the just-reviewed week, return the start of the
/// upcoming week (end + 1 day) as `yyyy-MM-dd`. Pure day arithmetic, so
/// it holds for any week anchor. Falls back to the input string if
/// parsing fails so we don't crash the executor on malformed data.
private func nextWeekStartString(after weekEndStr: String) -> String {
    guard let end = parseDate(weekEndStr) else { return weekEndStr }
    let next = Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end
    return formatYMD(next)
}

/// Given a week-start string, return the matching week end (start + 6 days).
private func weekEndString(after weekStartStr: String) -> String {
    guard let start = parseDate(weekStartStr) else { return weekStartStr }
    let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
    return formatYMD(end)
}

private func formatYMD(_ d: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = .current
    return f.string(from: d)
}

/// True if the in-progress review already has any non-default field set.
/// Lets the executor distinguish "fresh start" from "resumed after a
/// partial conversation" in the response summary.
@MainActor
private func hasAnyPopulatedField(_ r: WeeklyReview) -> Bool {
    r.sleepAvgHours != nil
        || r.energyRating != nil
        || r.motivationRating != nil
        || r.sorenessLevel != nil
        || r.painFlag
        || r.lifeStressRating != nil
        || (r.bestSessionText?.isEmpty == false)
        || (r.worstSessionText?.isEmpty == false)
        || (r.lifeContext?.isEmpty == false)
        || (r.questions?.isEmpty == false)
        || (r.nextWeekFocus?.isEmpty == false)
}

// MARK: - Tolerant numeric coercion
//
// AnyCodable's `init(from:)` (AgentLoop.swift) now tries `Int.self` before
// `Double.self` so integer-typed JSON values stay as Int. These helpers
// add a second layer of tolerance for the cases the type fix doesn't
// cover: the LLM occasionally emits `5.0` (decimal point) when the
// schema says `number`, and very occasionally `"5"` (string). Without
// them, a single stray format would silently reject the tool call.
//
// Use these instead of `as? Int` / `as? Double` at any strict-guard site
// in the executor — anywhere a missing value rejects the call.

/// Coerce a JSON-decoded value to `Int`. Accepts `Int`, integer-valued
/// `Double`, and numeric strings. Returns nil for fractional, NaN,
/// infinite, or overflowing values.
private func intFrom(_ value: Any?) -> Int? {
    if let i = value as? Int { return i }
    if let d = value as? Double, let i = Int(exactly: d) { return i }
    if let s = value as? String, let i = Int(s) { return i }
    return nil
}

/// Coerce a JSON-decoded value to `Double`. Accepts `Double`, `Int`
/// (widened), and numeric strings. Returns nil if no representation
/// parses cleanly.
private func doubleFrom(_ value: Any?) -> Double? {
    if let d = value as? Double { return d }
    if let i = value as? Int { return Double(i) }
    if let s = value as? String, let d = Double(s) { return d }
    return nil
}

// MARK: - JSON Helper

private func jsonString(_ value: Any) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
          let str = String(data: data, encoding: .utf8) else {
        return "{}"
    }
    return str
}

/// Whole weeks between today and a "yyyy-MM-dd" date string, rounded up so
/// race weeks are never shorted. Returns nil if the date string is missing or
/// malformed.
private func weeksBetweenTodayAnd(_ dateStr: String?) -> Int? {
    guard let dateStr, !dateStr.isEmpty else { return nil }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let target = formatter.date(from: dateStr) else { return nil }
    let days = Calendar.current.dateComponents([.day], from: Date(), to: target).day ?? 0
    guard days > 0 else { return nil }
    return Int(ceil(Double(days) / 7.0))
}

// MARK: - Future-mark guard

/// Scans a WeeklyPlan for any session whose scheduled date is strictly
/// after today AND carries a completion marker (`completionStatus != nil`
/// or `completed == true`). Returns a human-readable, AI-parroting error
/// message naming the offending session, or nil if the week is clean.
///
/// Used by `patch_weekly_plan`, `save_weekly_plan`, and any other tool
/// that can write completion markers into a WeeklyPlan payload — so the
/// agent loop sees the error as the tool's result in the same turn and
/// can self-correct in its response to the athlete.
///
/// Permissive when the plan has no `startDate` (can't compute dates;
/// an undated plan is a broken state anyway).
private func firstFutureCompletionMark(
    in wp: WeeklyPlan,
    planStartDate: String?,
    anchor: Weekday
) -> String? {
    guard planStartDate != nil else { return nil }
    let iso = DateFormatter()
    iso.dateFormat = "yyyy-MM-dd"
    let today = todayString()

    for (dayIdx, day) in wp.sessions.enumerated() {
        // Resolve each day's date through the same anchor-snapped helper the
        // rest of the app uses (sessionDateString → weekStart). Recomputing
        // the offset inline without that snap shifts every day by however far
        // the plan's startDate sits from its week anchor, which can push a
        // past/today session forward past `today` and trip a false "future
        // completion" rejection on plans with a drifted startDate.
        guard let dateStr = sessionDateString(
            planStartDate: planStartDate,
            weekNumber: wp.weekNumber,
            dayIdx: dayIdx,
            anchor: anchor
        ) else { continue }
        guard dateStr > today else { continue }   // past or today — marking is allowed
        for session in day.sessions {
            guard session.completionStatus != nil || session.completed == true else { continue }
            let when: String = {
                guard let date = iso.date(from: dateStr) else { return dateStr }
                let pretty = DateFormatter()
                pretty.dateFormat = "EEE, MMM d"
                return pretty.string(from: date)
            }()
            return "Rejected — '\(session.label)' on \(when) (week \(wp.weekNumber), day \(dayIdx)) is in the future, and the patch set a completion field on it (completion_status / actual_sport / actual_duration / skip_reason / completion_note). Completion fields describe what actually happened and only apply once the session's date has arrived. For a forward-looking prescription change (e.g. Friday swim → Friday run), use `update` with prescription fields (type, sport, label, workout, distance_miles, pace_range, fuel) — or `delete` + `add` — instead. This is not an app bug; re-issue as a prescription edit. If instead the athlete is reporting a session they already did differently, the date is wrong — confirm which day they actually meant before any edit."
        }
    }
    return nil
}

// MARK: - Patch support

private enum PatchError: Error {
    case invalidOp(String)
}

/// Applies a single patch_weekly_plan operation to a mutable WeeklyPlan.
/// Throws PatchError.invalidOp on any shape/bounds problem; callers are
/// expected to treat a thrown error as rejecting the whole patch batch.
private func applyPatchOperation(_ op: [String: Any], to wp: inout WeeklyPlan) throws {
    guard let type = op["op"] as? String else {
        throw PatchError.invalidOp("missing op type")
    }

    switch type {
    case "move":
        guard let fromDay = intFrom(op["fromDay"]),
              let fromIndex = intFrom(op["fromIndex"]),
              let toDay = intFrom(op["toDay"]) else {
            throw PatchError.invalidOp("move requires fromDay, fromIndex, toDay")
        }
        try validateDay(fromDay, in: wp)
        try validateDay(toDay, in: wp)
        guard fromIndex >= 0, fromIndex < wp.sessions[fromDay].sessions.count else {
            throw PatchError.invalidOp("move fromIndex \(fromIndex) out of bounds for day \(fromDay) (has \(wp.sessions[fromDay].sessions.count) sessions)")
        }
        let session = wp.sessions[fromDay].sessions.remove(at: fromIndex)
        // Moving a session into a rest day implicitly un-rests it.
        if wp.sessions[toDay].isRest == true {
            wp.sessions[toDay].isRest = false
        }
        let rawTo = intFrom(op["toIndex"]) ?? wp.sessions[toDay].sessions.count
        let toIndex = max(0, min(rawTo, wp.sessions[toDay].sessions.count))
        wp.sessions[toDay].sessions.insert(session, at: toIndex)

    case "update":
        guard let day = intFrom(op["day"]),
              let index = intFrom(op["index"]),
              let fields = op["fields"] as? [String: Any] else {
            throw PatchError.invalidOp("update requires day, index, fields")
        }
        try validateDay(day, in: wp)
        guard index >= 0, index < wp.sessions[day].sessions.count else {
            throw PatchError.invalidOp("update index \(index) out of bounds for day \(day) (has \(wp.sessions[day].sessions.count) sessions)")
        }
        // Shallow-merge fields onto a JSON round-trip of the existing session.
        // null fields become NSNull → re-decoded as nil, so the LLM can clear
        // a field by passing `null`.
        let existingData = try JSONEncoder().encode(wp.sessions[day].sessions[index])
        guard var existingDict = try JSONSerialization.jsonObject(with: existingData) as? [String: Any] else {
            throw PatchError.invalidOp("update: could not serialize existing session for merge")
        }
        for (k, v) in fields {
            existingDict[k] = v
        }
        let mergedData = try JSONSerialization.data(withJSONObject: existingDict)
        let updated: PrescribedSession
        do {
            updated = try JSONDecoder().decode(PrescribedSession.self, from: mergedData)
        } catch {
            throw PatchError.invalidOp("update merged session failed to decode: \(error.localizedDescription)")
        }
        wp.sessions[day].sessions[index] = updated

    case "set_rest":
        guard let day = intFrom(op["day"]),
              let isRest = op["isRest"] as? Bool else {
            throw PatchError.invalidOp("set_rest requires day, isRest")
        }
        try validateDay(day, in: wp)
        wp.sessions[day].isRest = isRest
        if isRest {
            wp.sessions[day].sessions = []
        }
        if let note = op["restNote"] as? String {
            wp.sessions[day].restNote = note.isEmpty ? nil : note
        }

    case "add":
        guard let day = intFrom(op["day"]),
              let sessionDict = op["session"] as? [String: Any] else {
            throw PatchError.invalidOp("add requires day, session")
        }
        try validateDay(day, in: wp)
        let sessionData = try JSONSerialization.data(withJSONObject: sessionDict)
        let newSession: PrescribedSession
        do {
            newSession = try JSONDecoder().decode(PrescribedSession.self, from: sessionData)
        } catch {
            throw PatchError.invalidOp("add session failed to decode: \(error.localizedDescription)")
        }
        let rawIdx = intFrom(op["index"]) ?? wp.sessions[day].sessions.count
        let idx = max(0, min(rawIdx, wp.sessions[day].sessions.count))
        if wp.sessions[day].isRest == true {
            wp.sessions[day].isRest = false
        }
        wp.sessions[day].sessions.insert(newSession, at: idx)

    case "delete":
        guard let day = intFrom(op["day"]),
              let index = intFrom(op["index"]) else {
            throw PatchError.invalidOp("delete requires day, index")
        }
        try validateDay(day, in: wp)
        guard index >= 0, index < wp.sessions[day].sessions.count else {
            throw PatchError.invalidOp("delete index \(index) out of bounds for day \(day) (has \(wp.sessions[day].sessions.count) sessions)")
        }
        wp.sessions[day].sessions.remove(at: index)

    default:
        throw PatchError.invalidOp("unknown op type: \(type) (expected move, update, set_rest, add, delete)")
    }
}

private func validateDay(_ day: Int, in wp: WeeklyPlan) throws {
    guard day >= 0, day < wp.sessions.count else {
        throw PatchError.invalidOp("day \(day) out of bounds (expected 0-\(wp.sessions.count - 1); day 0 = the plan's week start day, see get_training_plan weekStartDay/dayOrder)")
    }
}

// MARK: - Edit-log support

/// Snapshot the slice of the week that an op touches, as a JSON-serializable
/// dict, for the `plan_edits.before_state` / `after_state` columns. Called
/// twice per op (pre- and post-mutation); the retrospective UI diffs the
/// two to render "swim → run" cards.
///
/// For `move` the slice includes both the from- and to-day blobs (a move
/// touches two days), keyed under `from_day` and `to_day`. For all other
/// ops the slice is the single affected day blob keyed under `day`.
/// Returns nil if the op refers to a day outside the week — the op will
/// have failed validation anyway and we don't want a misleading row.
private func captureAffectedSlice(_ op: [String: Any], in wp: WeeklyPlan) -> [String: Any]? {
    let type = op["op"] as? String ?? ""
    let encoder = JSONEncoder()
    let asDict: (DayPlan) -> [String: Any] = { day in
        guard let data = try? encoder.encode(day),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }
    switch type {
    case "move":
        guard let fromDay = intFrom(op["fromDay"]),
              let toDay = intFrom(op["toDay"]),
              fromDay >= 0, fromDay < wp.sessions.count,
              toDay >= 0, toDay < wp.sessions.count else { return nil }
        return [
            "from_day_idx": fromDay,
            "from_day": asDict(wp.sessions[fromDay]),
            "to_day_idx": toDay,
            "to_day": asDict(wp.sessions[toDay]),
        ]
    case "update", "set_rest", "add", "delete":
        guard let day = intFrom(op["day"]),
              day >= 0, day < wp.sessions.count else { return nil }
        return [
            "day_idx": day,
            "day": asDict(wp.sessions[day]),
        ]
    default:
        return nil
    }
}

/// Build a `PlanEdit` row from an applied op + its before/after slices.
/// Returns nil if the op type or day/index can't be parsed cleanly; the
/// op already mutated the week successfully, so dropping the log row is
/// preferable to inserting a half-typed row that fails the table's
/// CHECK constraints.
private func buildPlanEdit(
    op: [String: Any],
    planId: String,
    weekNumber: Int,
    before: [String: Any]?,
    after: [String: Any]?,
    reason: String?
) -> PlanEdit? {
    guard let typeStr = op["op"] as? String,
          let opType = PlanEdit.OpType(rawValue: typeStr) else { return nil }
    let day = intFrom(op["day"]) ?? intFrom(op["fromDay"])
    let sessionIndex = intFrom(op["index"]) ?? intFrom(op["fromIndex"])
    return PlanEdit(
        id: UUID(),
        userId: nil,
        planId: planId,
        weekNumber: weekNumber,
        appliedAt: nil,
        snapshotId: nil,                     // DataService.recordPlanEdits fills this in
        opType: opType,
        day: day,
        sessionIndex: sessionIndex,
        payload: AnyCodable(op),
        beforeState: before.map(AnyCodable.init),
        afterState: after.map(AnyCodable.init),
        reason: reason,
        source: "chat"
    )
}

// MARK: - Memory update support

private enum MemoryUpdateError: Error {
    case invalid(String)
}

/// Apply add/update/remove/clear to the structured coaching-notes list.
/// Add: value is `{text, relatedTopic?, status?}` (text required).
/// Update: itemId or value.id required; shallow-merges text / topic /
/// status onto the matching entry; stamps `lastReviewedAt`.
/// Remove: itemId or value.id (or value as a bare id string for legacy
/// callers) required.
/// Clear: wipes the list.
private func applyCoachingNoteOp(
    operation: String,
    value: Any?,
    itemId: String?,
    list: inout [CoachingNoteEntry]
) throws {
    switch operation {
    case "add":
        // Accept either {text, relatedTopic?} object or a bare string
        // (legacy convenience — wraps as text-only tracking entry).
        let text: String
        let relatedTopic: String?
        if let s = value as? String {
            text = s
            relatedTopic = nil
        } else if let dict = value as? [String: Any], let t = dict["text"] as? String {
            text = t
            relatedTopic = dict["relatedTopic"] as? String
        } else {
            throw MemoryUpdateError.invalid("coachingNotes add requires a string OR {text, relatedTopic?} object")
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MemoryUpdateError.invalid("coachingNotes add: text is empty")
        }
        list.append(CoachingNoteEntry.newTracking(text: text, relatedTopic: relatedTopic))

    case "update":
        let entryId = itemId
            ?? (value as? [String: Any])?["id"] as? String
        guard let entryId,
              let idx = list.firstIndex(where: { $0.id == entryId })
        else {
            throw MemoryUpdateError.invalid("coachingNotes update needs an id matching an existing entry")
        }
        let fields = (value as? [String: Any]) ?? [:]
        if let text = fields["text"] as? String { list[idx].text = text }
        if let topic = fields["relatedTopic"] as? String { list[idx].relatedTopic = topic }
        if let statusStr = fields["status"] as? String,
           let status = CoachingNoteEntry.NoteStatus(rawValue: statusStr) {
            list[idx].status = status
        }
        list[idx].lastReviewedAt = ISO8601DateFormatter().string(from: Date())

    case "remove":
        let entryId = itemId
            ?? (value as? [String: Any])?["id"] as? String
            ?? (value as? String)
        guard let entryId else {
            throw MemoryUpdateError.invalid("coachingNotes remove needs an entry id")
        }
        list.removeAll { $0.id == entryId }

    case "clear":
        list = []

    default:
        throw MemoryUpdateError.invalid("coachingNotes only supports add/update/remove/clear")
    }
}

/// Applies a category/operation/value triple to a mutable CoachingMemory.
/// Stamps lastUpdated to today on success. Throws MemoryUpdateError.invalid
/// with a specific message on any shape problem.
private func applyMemoryUpdate(
    category: String,
    operation: String,
    value: Any?,
    itemId: String?,
    to memory: inout CoachingMemory
) throws {
    func applyStringListOp(_ list: inout [String]) throws {
        switch operation {
        case "add":
            guard let s = value as? String, !s.isEmpty else {
                throw MemoryUpdateError.invalid("add requires a non-empty string value")
            }
            if !list.contains(s) { list.append(s) }
        case "remove":
            guard let s = value as? String else {
                throw MemoryUpdateError.invalid("remove requires a string value")
            }
            list.removeAll { $0 == s }
        case "clear":
            list = []
        default:
            throw MemoryUpdateError.invalid("string-list category '\(category)' only supports add/remove/clear")
        }
    }

    func applySingletonOp(_ field: inout String) throws {
        switch operation {
        case "set":
            guard let s = value as? String else {
                throw MemoryUpdateError.invalid("set requires a string value")
            }
            field = s
        case "clear":
            field = ""
        default:
            throw MemoryUpdateError.invalid("singleton string '\(category)' only supports set/clear")
        }
    }

    switch category {
    // Permanent string lists
    case "equipment":          try applyStringListOp(&memory.permanent.equipment)
    case "facilities":         try applyStringListOp(&memory.permanent.facilities)
    case "medicalHistory":     try applyStringListOp(&memory.permanent.medicalHistory)
    case "dietaryConstraints": try applyStringListOp(&memory.permanent.dietaryConstraints)

    // Permanent singleton
    case "communicationPrefs": try applySingletonOp(&memory.permanent.communicationPrefs)

    // Observations string lists
    case "patterns":           try applyStringListOp(&memory.observations.patterns)
    case "motivators":         try applyStringListOp(&memory.observations.motivators)
    case "openItems":          try applyStringListOp(&memory.observations.openItems)

    // Hidden coaching scratchpad — structured entries with status,
    // related topic, timestamp metadata. Per Decision #6, the agent
    // should only add entries for patterns observed 3+ times, and
    // flip stale tracking entries to resolved when the pattern stops.
    case "coachingNotes":
        try applyCoachingNoteOp(
            operation: operation,
            value: value,
            itemId: itemId,
            list: &memory.observations.coachingNotes
        )

    // Observations singletons
    case "consistency":        try applySingletonOp(&memory.observations.consistency)
    case "currentFocus":       try applySingletonOp(&memory.observations.currentFocus)

    // Response profile singletons
    case "volumeVsIntensity":  try applySingletonOp(&memory.responseProfile.volumeVsIntensity)
    case "recoveryRate":       try applySingletonOp(&memory.responseProfile.recoveryRate)
    case "easyDayDiscipline":  try applySingletonOp(&memory.responseProfile.easyDayDiscipline)
    case "sessionPreferences": try applySingletonOp(&memory.responseProfile.sessionPreferences)
    case "communicationNeeds": try applySingletonOp(&memory.responseProfile.communicationNeeds)
    case "skipPatterns":       try applyStringListOp(&memory.responseProfile.skipPatterns)

    // Benchmarks — structured
    case "benchmarks":
        switch operation {
        case "add":
            guard let obj = value as? [String: Any],
                  let metric = obj["metric"] as? String,
                  let val = obj["value"] as? String else {
                throw MemoryUpdateError.invalid("benchmarks add requires value: {metric, value, testDate?, method?}")
            }
            memory.benchmarks.removeAll { $0.metric == metric }  // replace if same metric
            memory.benchmarks.append(Benchmark(
                metric: metric,
                value: val,
                testDate: obj["testDate"] as? String,
                method: obj["method"] as? String
            ))
        case "remove":
            let metric: String
            if let s = value as? String {
                metric = s
            } else if let obj = value as? [String: Any], let m = obj["metric"] as? String {
                metric = m
            } else {
                throw MemoryUpdateError.invalid("benchmarks remove requires metric name as value (string or {metric})")
            }
            memory.benchmarks.removeAll { $0.metric == metric }
        case "clear":
            memory.benchmarks = []
        default:
            throw MemoryUpdateError.invalid("benchmarks only supports add/remove/clear")
        }

    // Injuries — structured, with update support
    case "injuries":
        switch operation {
        case "add":
            guard let obj = value as? [String: Any],
                  let area = obj["area"] as? String, !area.isEmpty else {
                throw MemoryUpdateError.invalid("injuries add requires value.area")
            }
            let injury = InjuryRecord(
                id: obj["id"] as? String ?? UUID().uuidString,
                area: area,
                status: obj["status"] as? String ?? "active",
                severity: obj["severity"] as? String ?? "mild",
                firstReported: obj["firstReported"] as? String ?? todayString(),
                lastUpdated: todayString(),
                triggers: obj["triggers"] as? [String] ?? [],
                safeActivities: obj["safeActivities"] as? [String] ?? [],
                modifications: obj["modifications"] as? [String] ?? [],
                returnCriteria: obj["returnCriteria"] as? String,
                history: []
            )
            memory.injuries.append(injury)
        case "remove":
            let removeId = itemId
                ?? (value as? String)
                ?? (value as? [String: Any])?["id"] as? String
            guard let removeId else {
                throw MemoryUpdateError.invalid("injuries remove requires id (top-level or in value)")
            }
            memory.injuries.removeAll { $0.id == removeId }
        case "update":
            let updateId = itemId ?? (value as? [String: Any])?["id"] as? String
            guard let updateId,
                  let idx = memory.injuries.firstIndex(where: { $0.id == updateId }) else {
                throw MemoryUpdateError.invalid("injuries update requires id matching an existing injury")
            }
            guard let obj = value as? [String: Any] else {
                throw MemoryUpdateError.invalid("injuries update requires value object")
            }
            if let status = obj["status"] as? String { memory.injuries[idx].status = status }
            if let severity = obj["severity"] as? String { memory.injuries[idx].severity = severity }
            if let triggers = obj["triggers"] as? [String] { memory.injuries[idx].triggers = triggers }
            if let safeActivities = obj["safeActivities"] as? [String] { memory.injuries[idx].safeActivities = safeActivities }
            if let modifications = obj["modifications"] as? [String] { memory.injuries[idx].modifications = modifications }
            if let returnCriteria = obj["returnCriteria"] as? String {
                memory.injuries[idx].returnCriteria = returnCriteria.isEmpty ? nil : returnCriteria
            }
            if let note = obj["note"] as? String, !note.isEmpty {
                memory.injuries[idx].history.append(InjuryHistoryEntry(date: todayString(), note: note))
            }
            memory.injuries[idx].lastUpdated = todayString()
        case "clear":
            memory.injuries = []
        default:
            throw MemoryUpdateError.invalid("injuries supports add/remove/update/clear")
        }

    // Safety rules — structured
    case "safetyRules":
        switch operation {
        case "add":
            guard let obj = value as? [String: Any],
                  let rule = obj["rule"] as? String,
                  let reason = obj["reason"] as? String else {
                throw MemoryUpdateError.invalid("safetyRules add requires value: {rule, reason}")
            }
            memory.permanent.safetyRules.append(SafetyRule(
                rule: rule,
                reason: reason,
                addedDate: todayString()
            ))
        case "remove":
            let rule: String
            if let s = value as? String {
                rule = s
            } else if let obj = value as? [String: Any], let r = obj["rule"] as? String {
                rule = r
            } else {
                throw MemoryUpdateError.invalid("safetyRules remove requires rule text")
            }
            memory.permanent.safetyRules.removeAll { $0.rule == rule }
        case "clear":
            memory.permanent.safetyRules = []
        default:
            throw MemoryUpdateError.invalid("safetyRules only supports add/remove/clear")
        }

    default:
        throw MemoryUpdateError.invalid("unknown memory category: \(category)")
    }

    memory.lastUpdated = todayString()
}
