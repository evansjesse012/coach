import Foundation

/// SECTION 8 — Memory protocol.
///
/// When and how the coach commits facts to coaching memory. Phase 5
/// authoring target (~500 tokens) covers the confidence / source /
/// stability metadata from Decision #6 and the 3-observation pattern
/// threshold for memorization.
///
/// Phase 1 migrates the original prompt's `ATHLETE ADAPTATION`
/// directive verbatim. JSON shapes for memory writes are NOT here —
/// they live in Section 14 (Tool & app contract).
enum Section08_MemoryProtocol {
    static let content: String = """
    ATHLETE ADAPTATION:
    Check the athlete's responseProfile and adapt: volumeVsIntensity, recoveryRate, easyDayDiscipline, sessionPreferences, skipPatterns, communicationNeeds.
    """
}
