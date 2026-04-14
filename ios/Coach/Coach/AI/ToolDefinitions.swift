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

/// All 15 tools available to the AI coach, matching page.jsx lines 363-378
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
        description: "Generate and save a full periodized training plan for a race the athlete has already added as a goal. Use this when the athlete asks you to build, create, or make them a plan. Call get_goals first to find the race_event_id. The plan is generated by a specialist model and the whole thing is saved automatically — you do not need to specify every week. Only call this after you've gathered enough context (race details, athlete constraints, timeline). If a plan already exists, the call will return an error asking you to confirm replacement — then call again with confirm_overwrite: true.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "race_event_id": ToolProperty(type: "string", description: "Event id from get_goals — the race this plan targets.", enum: nil),
                "total_weeks": ToolProperty(type: "number", description: "Number of weeks in the plan. Typically 8-20. Default 12.", enum: nil),
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
        description: "Replace an existing week's plan or insert a new one. Use this to move sessions between days, adjust duration/distance/pace, change notes or warnings, or mark a day as rest. Call get_training_plan first to read the current week, edit the returned weekPlan object, then pass it back here as the full input. This REPLACES the whole week — include every day and every field you read, don't just send the delta.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "weekNumber": ToolProperty(type: "number", description: "Week index to save (1-based). Must match an existing week for an edit, or the next week for an insert.", enum: nil),
                "phase": ToolProperty(type: "number", description: "Phase number this week belongs to.", enum: nil),
                "focusOfWeek": ToolProperty(type: "string", description: "Human-readable focus for the week (e.g. 'Aerobic base, long run progression').", enum: nil),
                "sessions": ToolProperty(type: "array", description: "Array of 7 day objects in Monday-Sunday order. Each day is { day: 'monday'|'tuesday'|..., isRest: bool?, rest_note: string?, sessions: [prescribed session objects] }. Prescribed session fields match exactly what get_training_plan returns (type, label, duration, distance_miles, effort_category, zone, pace_range, priority, purpose, workout, notes, warning, etc.). Preserve every field you read — missing fields are treated as removed.", enum: nil),
            ],
            required: ["weekNumber", "phase", "focusOfWeek", "sessions"]
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
        name: "app_action",
        description: "Perform any action in the app: create, update, delete data, change settings, or navigate.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "action": ToolProperty(type: "string", description: "The action type", enum: ["create", "update", "delete", "navigate", "settings"]),
                "target": ToolProperty(type: "string", description: "What to act on", enum: ["workout", "strength_workout", "goal", "nutrition", "plan", "plan_session", "coaching_memory", "brick", "app"]),
                "id": ToolProperty(type: "string", description: "ID of the item to update/delete", enum: nil),
                "data": ToolProperty(type: "object", description: "Payload — fields depend on target.", enum: nil),
            ],
            required: ["action", "target"]
        )
    ),
]
