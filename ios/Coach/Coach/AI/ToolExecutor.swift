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
        ]

        if includeDetail {
            result["phases"] = plan.phases.map { p in
                ["number": p.number, "name": p.name, "weeks": p.weeks, "focus": p.focus ?? ""] as [String: Any]
            }
        }

        if let wp = plan.weeklyPlans[String(weekNum)] {
            result["weekPlan"] = ["weekNumber": wp.weekNumber, "focusOfWeek": wp.focusOfWeek ?? ""]
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
                "coachingNotes": mem.observations.coachingNotes,
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
              let duration = input["duration"] as? Int else {
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

        let totalWeeks = input["total_weeks"] as? Int ?? 12
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
                notes: planNotes
            )
            let phasesSummary = plan.phases.map { "\($0.name) (\($0.weeks)w)" }.joined(separator: ", ")
            return ToolResult(
                summary: jsonString([
                    "created": true,
                    "totalWeeks": plan.totalWeeks,
                    "phases": phasesSummary,
                    "currentWeek": plan.currentWeek,
                    "weeksPopulated": plan.weeklyPlans.count,
                ]),
                effects: [.planCreated(plan)]
            )
        } catch {
            return ToolResult(summary: jsonString(["error": "Plan generation failed: \(error.localizedDescription)"]))
        }

    // MARK: save_training_plan (legacy — kept for compat, no-op effect)
    case "save_training_plan":
        return ToolResult(summary: jsonString(["saved": true, "plan": input]))

    // MARK: save_weekly_plan
    case "save_weekly_plan":
        return ToolResult(summary: jsonString(["saved": true, "weekPlan": input]))

    // MARK: update_plan_progress
    case "update_plan_progress":
        let week = input["currentWeek"] as? Int ?? 1
        let phase = input["currentPhase"] as? Int ?? 1
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

    // MARK: app_action
    case "app_action":
        let action = input["action"] as? String ?? ""
        let target = input["target"] as? String ?? ""
        return ToolResult(summary: jsonString(["success": true, "action": action, "target": target, "data": input["data"] ?? [:]]))

    default:
        return ToolResult(summary: #"{"error":"Unknown tool: \#(name)"}"#)
    }
}

// MARK: - JSON Helper

private func jsonString(_ value: Any) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
          let str = String(data: data, encoding: .utf8) else {
        return "{}"
    }
    return str
}
