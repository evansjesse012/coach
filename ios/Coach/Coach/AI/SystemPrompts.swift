import Foundation

// MARK: - Personality Prompts

/// Returns the persona content for a given `Personality`. Single source
/// of truth — delegates to the `Persona_*.content` files so the
/// post-completion reaction generator and the morning coach-note
/// generator can't drift from the main chat's persona voice.
///
/// Used by `CompletionResponseGenerator`, `CoachNoteGenerator`, and any
/// other surface that needs the persona text outside the main system
/// prompt assembly. The main chat path goes through `CoachState`,
/// which uses the same `Persona_*.content` strings — so all surfaces
/// share one authoritative voice.
func getPersonalityPrompt(_ personality: Personality, _ customText: String) -> String {
    switch personality {
    case .normal:  return Persona_Normal.content
    case .goggins: return Persona_Goggins.content
    case .hype:    return Persona_Hype.content
    case .custom:
        let trimmed = customText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Persona_Normal.content : "Your coaching style: \(trimmed)"
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
func buildSystemPrompt(
    personality: Personality,
    customText: String,
    recentConversationSummaries: [String] = []
) -> String {
    let state = CoachState(
        today: Date(),
        recoveryPicture: nil,   // Phase 4: HealthKit-derived narrative
        athleteSummary: nil,    // Phase 5: in-memory athlete snapshot
        recentConversationSummaries: recentConversationSummaries
    )
    return PromptAssembler.assemble(
        personality: personality,
        customText: customText,
        state: state
    )
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
