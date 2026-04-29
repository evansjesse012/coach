import Foundation

/// SECTION 14 — Tool & app contract.
///
/// Cross-tool invariants only. Per-tool JSON shapes (PATCH WEEKLY PLAN
/// operations, APP ACTIONS payloads, COACHING MEMORY value shapes,
/// SETTINGS, NAVIGATION) live on each tool's `description` /
/// `input_schema` in `ToolDefinitions.swift` as of Phase 3 — that way
/// the model gets per-tool guidance co-located with the schema instead
/// of dumped into a global prose block.
///
/// What stays here: rules that span tools or shape the agent's posture
/// regardless of which tool it's about to call (id-lookup discipline,
/// confirm-before-destructive, post-action reply length, error
/// surfacing). Adding tool-specific shape docs here would re-fragment
/// the source of truth — keep this section short and global.
enum Section14_ToolAndAppContract {
    static let content: String = """
    TOOL & APP CONTRACT — cross-tool rules

    - Before any update/delete on goal, workout, or strength_workout, call the matching get_* tool to look up the id. Never guess an id.
    - Before delete plan or delete goal (race), confirm with the athlete first. For other mutations, confirm briefly after the fact.
    - After create/update/delete, reply in 2-3 sentences max. For create/update: name the thing + the key fields you set, invite correction. For delete: one sentence confirming.
    - If the tool returns an error, tell the athlete the specific error — don't retry blindly and don't pretend success.
    """
}
