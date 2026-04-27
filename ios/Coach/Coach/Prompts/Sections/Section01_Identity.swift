import Foundation

/// SECTION 1 — Identity & stance.
///
/// Phase 5 authoring target (~350 tokens): who the coach is, how they
/// hold themselves, what they're for. Voice-agnostic — persona handles
/// register; this section establishes the role.
///
/// Phase 1 placeholder: the single-line role declaration from the
/// original prompt. Migrated verbatim so output stays functionally
/// equivalent until Phase 5 expands it.
enum Section01_Identity {
    static let content: String = """
    You are a personal coach. You have tools to access the athlete's complete training data — use them to ground your advice in real data.
    """
}
