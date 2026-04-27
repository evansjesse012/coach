import Foundation

/// Composes the Coach AI system prompt from individually-authored section
/// files plus a per-turn `CoachState`. The output is one string that gets
/// sent as Claude's `system` message.
///
/// Layout (top-to-bottom):
///
///   Static head — sections 1 through 11
///       Authored content; cacheable across turns.
///   Dynamic block — `state.render(...)`
///       Persona content + today's date + recovery picture + athlete
///       summary. Fresh every turn; never cached.
///   Static tail — sections 12 through 15
///       Output format / anti-patterns / tool & app contract / few-shots.
///       Cacheable across turns.
///
/// Phase 1: outputs one combined string from `assemble(...)`. The API
/// call wiring (Phase 2) will split static head + tail into a single
/// cached block and the dynamic block into an uncached block.
enum PromptAssembler {

    /// Compose the full system prompt for the active personality + the
    /// per-turn state.
    static func assemble(
        personality: Personality,
        customText: String,
        state: CoachState
    ) -> String {
        let staticHead = staticHeadSections.compactMap { content -> String? in
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }.joined(separator: "\n\n")

        let dynamic = state.render(personality: personality, customText: customText)

        let staticTail = staticTailSections.compactMap { content -> String? in
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }.joined(separator: "\n\n")

        return [staticHead, dynamic, staticTail]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    // MARK: - Section ordering

    /// Sections rendered before the dynamic block (CoachState).
    /// Order is the spec'd order — do not reshuffle without an update to
    /// `DECISIONS.md`.
    private static var staticHeadSections: [String] {
        [
            Section01_Identity.content,
            Section02_Philosophy.content,
            Section03_DecisionPosture.content,
            Section04_DiagnosticProtocol.content,
            Section05_SafetyAndScope.content,
            Section06_DataGroundingAndToolUse.content,
            Section07_ReadinessAndLoad.content,
            Section08_MemoryProtocol.content,
            Section09_GoalRouter.content,
            Section10_PlanCreationAndModification.content,
            Section11_PostWorkoutCoaching.content,
        ]
    }

    /// Sections rendered after the dynamic block.
    private static var staticTailSections: [String] {
        [
            Section12_OutputFormat.content,
            Section13_AntiPatterns.content,
            Section14_ToolAndAppContract.content,
            Section15_FewShotExchanges.content,
        ]
    }
}
