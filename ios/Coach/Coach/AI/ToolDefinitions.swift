import Foundation

// MARK: - Anthropic Tool Schema Types

/// Matches the Anthropic API tool definition format
struct ToolDefinition: Codable {
    let name: String
    let description: String
    let inputSchema: ToolInputSchema

    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
}

struct ToolInputSchema: Codable {
    let type: String
    let properties: [String: ToolProperty]?
    let required: [String]?
}

struct ToolProperty: Codable {
    let type: String
    let description: String?
    let `enum`: [String]?

    enum CodingKeys: String, CodingKey {
        case type, description
        case `enum` = "enum"
    }
}

// MARK: - Tool Definitions

/// All 18 tools available to the AI coach. Each tool's `description` is
/// the model's primary reference for when to call it; cross-tool
/// invariants live in `Section14_ToolAndAppContract`.
let coachToolDefinitions: [ToolDefinition] = [
    ToolDefinition(
        name: "get_workouts",
        description: "Get workout history filtered by sport and date range.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "sport": ToolProperty(type: "string", description: nil, enum: ["run", "bike", "swim", "strength", "brick", "hike", "other", "all"]),
                "days": ToolProperty(type: "number", description: nil, enum: nil),
                "limit": ToolProperty(type: "number", description: nil, enum: nil),
            ],
            required: ["sport"]
        )
    ),
    ToolDefinition(
        name: "get_training_plan",
        description: "Get the athlete's training plan. If a periodized plan exists, returns season overview with phases, current phase, and current week's sessions. Use includePhaseDetail=true to see all phase details. Use weekNumber to get a specific week's sessions.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "includePhaseDetail": ToolProperty(type: "boolean", description: "Include full details for all phases. Default false.", enum: nil),
                "weekNumber": ToolProperty(type: "number", description: "Get sessions for a specific week number. Default: current week.", enum: nil),
            ],
            required: nil
        )
    ),
    ToolDefinition(
        name: "get_training_stats",
        description: "Get computed training stats: weekly volume, trends, consistency.",
        inputSchema: ToolInputSchema(type: "object", properties: ["weeks": ToolProperty(type: "number", description: nil, enum: nil)], required: nil)
    ),
    ToolDefinition(
        name: "get_personal_records",
        description: "Get personal records for exercises.",
        inputSchema: ToolInputSchema(type: "object", properties: ["exercise": ToolProperty(type: "string", description: nil, enum: nil)], required: nil)
    ),
    ToolDefinition(
        name: "get_goals",
        description: "Get active training goals with days remaining.",
        inputSchema: ToolInputSchema(type: "object", properties: ["include_completed": ToolProperty(type: "boolean", description: nil, enum: nil)], required: nil)
    ),
    ToolDefinition(
        name: "get_athlete_profile",
        description: "Get coaching memory — accumulated facts about the athlete.",
        inputSchema: ToolInputSchema(type: "object", properties: nil, required: nil)
    ),
    ToolDefinition(
        name: "log_workout",
        description: "Log a completed workout. Only use when athlete explicitly describes something they just completed.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "sport": ToolProperty(type: "string", description: nil, enum: ["run", "bike", "swim", "strength", "brick", "hike", "other"]),
                "duration": ToolProperty(type: "number", description: nil, enum: nil),
                "notes": ToolProperty(type: "string", description: nil, enum: nil),
                "date": ToolProperty(type: "string", description: nil, enum: nil),
            ],
            required: ["sport", "duration"]
        )
    ),
    ToolDefinition(
        name: "log_nutrition",
        description: "Log what the athlete ate. Record what they ate, timing relative to training, and which workout it relates to.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "meal": ToolProperty(type: "string", description: "What they ate, in their words", enum: nil),
                "timing": ToolProperty(type: "string", description: "When relative to training", enum: ["pre", "during", "post", "general"]),
                "relatedWorkout": ToolProperty(type: "string", description: "Which workout this fueled", enum: nil),
                "date": ToolProperty(type: "string", description: "YYYY-MM-DD, default today", enum: nil),
            ],
            required: ["meal", "timing"]
        )
    ),
    ToolDefinition(
        name: "get_nutrition",
        description: "Get the athlete's recent nutrition log.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "days": ToolProperty(type: "number", description: "Look back this many days. Default 7.", enum: nil),
                "timing": ToolProperty(type: "string", description: "Filter by timing. Default all.", enum: ["pre", "during", "post", "general", "all"]),
            ],
            required: nil
        )
    ),
    ToolDefinition(
        name: "create_training_plan",
        description: "Generate and save a periodized training plan for a race the athlete has already added as a goal. Use this when the athlete asks you to build, create, or make them a plan. Call get_goals first to find the race_event_id. The plan length is auto-computed from today → race date unless the athlete specified otherwise. The generator produces the full season structure (phases + a weekly focus for every week) AND fully-detailed daily sessions for ONLY the first week — subsequent weeks start as stubs and are generated closer to their start date via generate_week_plan, so each week can adapt to how the athlete is actually doing. Call create_training_plan only after you've gathered enough context (race details, athlete constraints). If a plan already exists, the call will return an error asking you to confirm replacement — then call again with confirm_overwrite: true.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "race_event_id": ToolProperty(type: "string", description: "Event id from get_goals — the race this plan targets.", enum: nil),
                "total_weeks": ToolProperty(type: "number", description: "OPTIONAL. If omitted, the app auto-computes the plan length from today's date to the race date on the linked event. Only pass this if the athlete explicitly requested a different length.", enum: nil),
                "training_days_per_week": ToolProperty(type: "number", description: "How many days/week the athlete trains. Default 6.", enum: nil),
                "weekly_volume_hours": ToolProperty(type: "number", description: "Target peak weekly training volume in hours.", enum: nil),
                "long_run_day": ToolProperty(type: "string", description: "Preferred long run day.", enum: ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]),
                "strength_days": ToolProperty(type: "array", description: "Preferred strength training days.", enum: nil),
                "notes": ToolProperty(type: "string", description: "Freeform constraints, goals, or preferences the athlete mentioned that the plan should respect.", enum: nil),
                "confirm_overwrite": ToolProperty(type: "boolean", description: "Pass true only after the athlete confirms they want to replace an existing plan.", enum: nil),
            ],
            required: ["race_event_id"]
        )
    ),
    ToolDefinition(
        name: "generate_week_plan",
        description: "Generate full daily session detail for a single week of the current training plan. Use this when the athlete asks you to build or shape the upcoming week, when they ask what's coming next, or when you notice the current/next week is still a stub (sessions array empty). The generator pulls in recent adherence history automatically so it adapts to how the athlete is actually doing — progressing if they're nailing sessions, pulling back if they're missing key workouts or flagging fatigue. Don't call for weeks that already have a populated sessions array unless the athlete explicitly asks to regenerate.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "weekNumber": ToolProperty(type: "number", description: "1-based week number to generate. Must be within the plan's total_weeks range.", enum: nil),
            ],
            required: ["weekNumber"]
        )
    ),
    ToolDefinition(
        name: "save_training_plan",
        description: "Save a full periodized training plan.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "goalId": ToolProperty(type: "string", description: nil, enum: nil),
                "raceName": ToolProperty(type: "string", description: nil, enum: nil),
                "raceDate": ToolProperty(type: "string", description: nil, enum: nil),
                "startDate": ToolProperty(type: "string", description: nil, enum: nil),
                "totalWeeks": ToolProperty(type: "number", description: nil, enum: nil),
                "trainingDaysPerWeek": ToolProperty(type: "number", description: nil, enum: nil),
                "phases": ToolProperty(type: "array", description: "Phase definitions", enum: nil),
            ],
            required: ["goalId", "raceName", "raceDate", "startDate", "totalWeeks", "phases"]
        )
    ),
    ToolDefinition(
        name: "save_weekly_plan",
        description: "Wholesale replacement of an entire week's plan. Prefer patch_weekly_plan for common edits (move, update, rest, add, delete) — only use this when the user wants to rewrite most of the week at once. This REPLACES the whole week; any field you omit is lost. Call get_training_plan first, edit the returned weekPlan object, then pass it back here as the full input.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "weekNumber": ToolProperty(type: "number", description: "Week index to save (1-based).", enum: nil),
                "phase": ToolProperty(type: "number", description: "Phase number this week belongs to.", enum: nil),
                "focusOfWeek": ToolProperty(type: "string", description: "Human-readable focus for the week.", enum: nil),
                "sessions": ToolProperty(type: "array", description: "Array of 7 day objects in Monday-Sunday order. Same shape get_training_plan returns under weekPlan.sessions.", enum: nil),
            ],
            required: ["weekNumber", "phase", "focusOfWeek", "sessions"]
        )
    ),
    ToolDefinition(
        name: "patch_weekly_plan",
        description: "Surgical edits to a single week's plan. Apply one or more operations — move a session between days, update a session's fields, toggle rest, add a session, delete a session. All operations are applied atomically: if any op is invalid, none are applied. Call get_training_plan first to know the day and session indices. Day indices are 0-based (0=Monday, 6=Sunday).",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "weekNumber": ToolProperty(type: "number", description: "Week index to patch (1-based). Must already exist in the plan.", enum: nil),
                "operations": ToolProperty(type: "array", description: "Array of operations. Each op is one of: {op:'move', fromDay, fromIndex, toDay, toIndex?} (toIndex defaults to end); {op:'update', day, index, fields:{...}} (shallow-merges fields into existing session — use null to clear a field; field names are snake_case e.g. distance_miles, effort_category, pace_range); {op:'set_rest', day, isRest, restNote?} (setting isRest:true clears that day's sessions); {op:'add', day, session:{...}, index?} (index defaults to end; session shape matches get_training_plan output); {op:'delete', day, index}.", enum: nil),
            ],
            required: ["weekNumber", "operations"]
        )
    ),
    ToolDefinition(
        name: "update_plan_progress",
        description: "Advance the current week number or phase in the training plan.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "currentWeek": ToolProperty(type: "number", description: nil, enum: nil),
                "currentPhase": ToolProperty(type: "number", description: nil, enum: nil),
                "notes": ToolProperty(type: "string", description: nil, enum: nil),
            ],
            required: ["currentWeek", "currentPhase"]
        )
    ),
    ToolDefinition(
        name: "get_week_review",
        description: "Compare prescribed training plan vs actual logged workouts for a specific week.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "weekNumber": ToolProperty(type: "number", description: "Week to review. Default: previous week.", enum: nil),
                "includeMultiWeek": ToolProperty(type: "boolean", description: "Include 4-week rolling pattern analysis. Default false.", enum: nil),
            ],
            required: nil
        )
    ),
    ToolDefinition(
        name: "get_plan_history",
        description: "Get archived past training plans with adherence data.",
        inputSchema: ToolInputSchema(type: "object", properties: nil, required: nil)
    ),
    ToolDefinition(
        name: "start_weekly_review_check_in",
        description: "Start (or resume) the weekly review check-in for the week that just ended. Call this at the very beginning of a Sunday-evening or Monday-morning wrap-up conversation, BEFORE asking any questions. Returns the review id (you'll pass it to populate_review_field and complete_weekly_review) plus the prior week's adherence summary so you can frame the conversation around what actually happened. Idempotent — if a check-in is already in progress for the same week, returns the existing row instead of creating a duplicate. Section 11's WEEKLY CHECK-IN sub-section governs the conversational flow.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "week_start_date": ToolProperty(type: "string", description: "OPTIONAL. yyyy-MM-dd Monday of the week being reviewed. Default: prior Monday (or this Monday on Sunday). Override only if the athlete is retroactively wrapping up an older week.", enum: nil),
            ],
            required: nil
        )
    ),
    ToolDefinition(
        name: "populate_review_field",
        description: "Write one or more structured fields onto an in-progress weekly review. Call this AFTER each athlete answer in the check-in conversation — once per turn, only with the field(s) the answer actually addressed. Don't batch all fields into a single call at the end; the per-field rhythm is what makes the conversation feel paced. All fields are optional so you can send any subset. The shape mirrors weekly_reviews columns; ratings are 1–10 ints, soreness_level is one of none/mild/significant/concerning, sleep_avg_hours and body_weight are decimals.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "review_id":           ToolProperty(type: "string",  description: "ID returned by start_weekly_review_check_in.", enum: nil),
                "fields":              ToolProperty(type: "object",  description: "Subset of {sleep_avg_hours: number, energy_rating: int (1-10), motivation_rating: int (1-10), soreness_level: 'none'|'mild'|'significant'|'concerning', soreness_location: string, pain_flag: bool, pain_description: string, life_stress_rating: int (1-10), body_weight: number, best_session_text: string, worst_session_text: string, life_context: string, questions: string, next_week_focus: string}.", enum: nil),
            ],
            required: ["review_id", "fields"]
        )
    ),
    ToolDefinition(
        name: "complete_weekly_review",
        description: "Finalize the weekly review check-in. Call this once the conversation has covered everything that needed covering. Stamps completed_at, auto-computes adherence_pct from logged-vs-prescribed sessions, attempts to pull the week's HealthKit sleep average if not already set. The athlete-side state is now frozen; the AI-side response prose + paired preview are generated in a follow-up step. Section 11's WEEKLY CHECK-IN sub-section says when the conversation is ready to be wrapped — don't call this prematurely.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "review_id": ToolProperty(type: "string", description: "ID returned by start_weekly_review_check_in.", enum: nil),
            ],
            required: ["review_id"]
        )
    ),
    ToolDefinition(
        name: "app_action",
        description: "Perform an action in the app: create/update/delete a goal, update/delete a logged workout, delete a strength session, delete the training plan (with archiving), update coaching memory, change settings, or navigate to a tab. Only the (action, target) pairs documented on the `data` property are supported — anything else returns \"not yet implemented\". Cross-tool rules (id lookup before update/delete, confirm-before-destructive, error handling, post-action reply length) live in Section 14.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "action": ToolProperty(type: "string", description: "The action type", enum: ["create", "update", "delete", "navigate"]),
                "target": ToolProperty(type: "string", description: "What to act on", enum: ["goal", "workout", "strength_workout", "plan", "coaching_memory", "settings", "app"]),
                "id": ToolProperty(type: "string", description: "ID of the item to update/delete. Required for update/delete on goal, workout, strength_workout. Call the matching get_* tool first to find it — never guess.", enum: nil),
                "data": ToolProperty(type: "object", description: """
                    Payload shape depends on the (action, target) pair.

                    GOAL / RACE CARD:
                    - create: {name, presetId, mode:'race'|'goal'|'pr', date:'YYYY-MM-DD', location, distance, goal, stretchGoal, baseline, url}. presetId is one of: marathon, half-marathon, 10k, 5k, ultra, trail-race, full-tri, half-tri, olympic-tri, sprint-tri, century, gran-fondo, swim-race, custom. For known races (IRONMAN/70.3 branded, marathon majors, UTMB, Kona, etc.) fill in name/date/location/distance from your real-world knowledge — don't ask redundant questions. If the exact date isn't known for the stated year, use the event's traditional slot AND mention the assumed date so the athlete can correct it. Relative years ('this year', 'next year') resolve against today. OMIT the url field entirely if you can't recall the exact official site — never guess or construct URLs from patterns; a missing URL is fine, a wrong one isn't.
                    - update: {...fields to change}. Pair with top-level id.
                    - delete: pair with top-level id. Confirm with the athlete first for race goals.

                    WORKOUT (cardio):
                    - update: {date?, sport?, duration?, distance?, pace?, notes?, avgHR?, maxHR?, calories?, location?}. Pair with top-level id from get_workouts.
                    - delete: pair with top-level id.

                    STRENGTH_WORKOUT:
                    - delete: pair with top-level id. Editing exercises inside a session isn't supported — ask the athlete to delete and re-log if they want to fix sets/reps.

                    PLAN:
                    - delete: {reason:'short label', notes:'longer context'}. Archives the current plan to PlanHistory before removing. Always confirm with the athlete first.

                    COACHING_MEMORY (append/edit facts about the athlete):
                    - shape: {category, operation, value, id?}
                    - String-list categories (add/remove/clear): equipment, facilities, medicalHistory, dietaryConstraints, patterns, motivators, openItems, skipPatterns. Example: {category:'equipment', operation:'add', value:'smart trainer'}
                    - Singleton-string categories (set/clear): communicationPrefs, currentFocus, consistency, volumeVsIntensity, recoveryRate, easyDayDiscipline, sessionPreferences, communicationNeeds. Example: {category:'currentFocus', operation:'set', value:'base building for Boston 2027'}
                    - coachingNotes (add/update/remove/clear) — your hidden scratchpad for patterns the athlete doesn't see. Only write a note after observing the same behavior 3+ times; single occurrences don't earn a slot. add: {text, relatedTopic?} where relatedTopic is a freeform tag like 'tuesday_pace_drift' or 'right_knee'. When a pattern resolves, update with {id, status:'resolved'} — the system hides resolved notes from your working context on later turns. update can also amend text/relatedTopic on an existing entry: {id, text:'...'} or {id, relatedTopic:'...'}. remove deletes permanently — prefer status:'resolved' unless the note was simply wrong.
                    - benchmarks (add/remove/clear): value is {metric, value, testDate?, method?}; remove takes the metric name as a string.
                    - injuries (add/remove/update/clear): add takes {area, status, severity, triggers?, safeActivities?, modifications?, returnCriteria?}; remove takes the injury id (from get_athlete_profile); update takes id + a value object with status/severity/triggers/safeActivities/modifications/returnCriteria/note (note is appended to injury history).
                    - safetyRules (add/remove/clear): add takes {rule, reason}; remove takes the rule text.
                    - Call get_athlete_profile first if you need existing IDs (for injury update/remove).

                    SETTINGS:
                    - update: {appearance?:'system'|'light'|'dark', personality?:'normal'|'goggins'|'hype'|'custom', customPrompt?:'...'}. Only change what the athlete explicitly asked for. Don't silently flip unrelated fields.

                    APP (navigation):
                    - navigate: {tab:'coach'|'goals'|'plan'|'analytics'|'log'}. Use sparingly — only when the athlete explicitly asks to open a tab. Don't navigate reflexively after every mutation.
                    """, enum: nil),
            ],
            required: ["action", "target"]
        )
    ),
]
