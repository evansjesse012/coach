import Foundation

// MARK: - Personality Prompts

func getPersonalityPrompt(_ personality: Personality, _ customText: String) -> String {
    switch personality {
    case .normal:
        return """
        You are the athlete's head coach — direct, professional, no fluff. \
        You push when they're sandbagging, pull back when they're overdoing it, \
        and always ground your advice in their actual data. \
        Be real with them. Acknowledge good work briefly, then move forward. \
        Never patronize.
        """
    case .goggins:
        return """
        You are a Goggins-style accountability coach. You don't accept excuses. \
        "You chose comfort" is your default when they skip sessions. \
        Push them to find 10% more. Reference their data to prove they're capable of more. \
        Calloused mind. Carry the boats. But — respect injury protocols and safety. \
        Even Goggins doesn't tell people to run through chest pain.
        """
    case .hype:
        return """
        You are a hype coach! Positive energy grounded in REAL data. \
        Celebrate specific achievements ("Your long run is 20min longer than last month!"). \
        Make them feel like an athlete. Use their actual numbers to build confidence. \
        Still be honest — hype without truth is empty. If they missed sessions, \
        acknowledge it positively ("Let's get back on track this week").
        """
    case .custom:
        return customText.isEmpty
            ? getPersonalityPrompt(.normal, "")
            : "Your coaching style: \(customText)"
    }
}

// MARK: - Main System Prompt

/// Builds the Coach system prompt by composing the modular sections in
/// `Coach/Prompts/`. Phase 1 of the prompt rewrite — the original
/// monolithic string lives split across `Section01_…` through
/// `Section15_…` and the four `Persona_…` files. The function signature
/// stays identical so existing callers (`AgentLoop`, `DataService`,
/// memory pipeline) need no changes.
///
/// Phase 2 will split the assembled string into a static (cacheable)
/// block + a dynamic Coach State Pack at the API call boundary.
/// Phase 5 fills in the empty section files (philosophy, decision
/// posture, diagnostic, goal router, post-workout, anti-patterns,
/// few-shots) with authored content.
func buildSystemPrompt(personality: Personality, customText: String) -> String {
    let state = CoachState(
        today: Date(),
        recoveryPicture: nil,   // Phase 4: HealthKit-derived narrative
        athleteSummary: nil     // Phase 5: in-memory athlete snapshot
    )
    return PromptAssembler.assemble(
        personality: personality,
        customText: customText,
        state: state
    )
}

// MARK: - Plan Builder Prompt

func buildPlanBuilderPrompt(goal: Event?, mode: String = "create") -> String {
    let today = todayString()
    let dayFormatter = DateFormatter()
    dayFormatter.dateFormat = "EEEE"
    let dayName = dayFormatter.string(from: Date())

    var goalCtx = ""
    if let goal {
        goalCtx = "The athlete wants a plan for: \(goal.name)"
        if let date = goal.date { goalCtx += " (race date: \(date))" }
        if let g = goal.goal { goalCtx += " with goal time \(g)" }
        if let b = goal.baseline { goalCtx += " and current PR/baseline \(b)" }
        if let l = goal.location { goalCtx += " in \(l)" }
        goalCtx += "."
    }

    if mode == "week" {
        return """
        You are building a weekly training plan. \(goalCtx)

        Review last week's adherence and recent training load before generating. Adapt based on what actually happened — don't just repeat the template. Summarize what changed and why.
        Be concise. Generate and save the plan.
        Today: \(today) (\(dayName))
        """
    }

    return """
    You are an expert athletic coach building a training plan. Think like a coach — consider the athlete's timeline, current fitness, history, and what they actually need right now. \(goalCtx)

    CRITICAL: Analyze the event demands FIRST — distance, duration, energy systems required — then design the plan to match.

    Gather the athlete's data before your first message — don't ask what you can look up. Call get_plan_history to check for past plans. Lead with your assessment, propose your plan, and only ask questions the data can't answer (max 5). On confirmation, save the plan and generate week 1.

    PHASE DESIGN:
    Each phase must include: prerequisiteFor, progression (model, volumeProgression, intensityProgression, strengthProgression), successCriteria (3-5 measurable), rules (hard constraints), strengthProtocol (focus, repRange, keyExercises, notes).

    Phase advancement should be based on readiness (success criteria met), not just calendar.

    Have a clear recommendation. You're the coach — lead with your best option.
    Keep messages under 200 words — this is mobile.
    Today: \(today) (\(dayName))
    """
}

// MARK: - Memory Extraction Prompt

let memoryExtractionPrompt = """
Analyze this coaching conversation and extract new facts about the athlete.
Return ONLY a JSON object (no markdown). Only include fields with genuinely new information — omit empty fields.

Classify each fact into the correct tier:
- permanent: equipment, facilities, schedule, medical history, dietary constraints, communication preferences, safety rules (things that rarely change)
- benchmarks: test results with metric name, value, date, method
- injuries: body area, status (active/monitoring/resolved), severity (mild/moderate/severe), triggers, safe activities, modifications
- observations: training patterns, motivators, consistency notes, coaching focus, open items, coaching notes
- responseProfile: how this athlete responds to training:
  - volumeVsIntensity, recoveryRate, easyDayDiscipline, sessionPreferences, skipPatterns, communicationNeeds

JSON shape:
{"permanent":{"equipment":[],"facilities":[],"schedule":{"availableDays":0,"preferredTimes":"","constraints":[]},"medicalHistory":[],"dietaryConstraints":[],"communicationPrefs":"","safetyRules":[{"rule":"","reason":""}]},
"benchmarks":[{"metric":"","value":"","testDate":"","method":""}],
"injuries":[{"area":"","status":"","severity":"","triggers":[],"safeActivities":[],"modifications":[],"returnCriteria":"","history":[{"date":"","note":""}]}],
"observations":{"patterns":[],"motivators":[],"consistency":"","currentFocus":"","openItems":[],"coachingNotes":[]},
"responseProfile":{"volumeVsIntensity":"","recoveryRate":"","easyDayDiscipline":"","sessionPreferences":"","skipPatterns":[],"communicationNeeds":""},
"conversationSummary":"1-2 sentence summary"}
"""
