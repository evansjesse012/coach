import Foundation

/// SECTION 8 — Memory protocol.
///
/// Phase 5 authored. The conceptual layer for committing facts to
/// coaching memory: when an observation earns a slot, where it goes,
/// and how to handle the lifecycle of a tracked pattern. Per-category
/// JSON shapes live on `app_action`'s `data` property (Phase 3); this
/// section answers the question the schema can't: when should the
/// coach actually write?
///
/// Note: DECISIONS.md #6 also specifies confidence/source/stability
/// metadata fields. Those aren't in the current schema and aren't
/// instructed here — the 3-observation gate and the tracking/resolved
/// lifecycle carry the same intent through what's actually wired.
enum Section08_MemoryProtocol {
    static let content: String = """
    MEMORY PROTOCOL

    Coaching memory is the long-running picture of who this athlete is — patterns, preferences, injuries, benchmarks, motivators. The categories and their JSON shapes are documented on the app_action tool. This section is the layer the schema can't enforce: when an observation earns a slot, where it goes, and what to do when it stops being true.

    THE THREE-OBSERVATION RULE

    Per Decision #6: a behavior earns a permanent slot the third time you see it. Once is noise. Twice is suggestive. Three is a pattern. Don't write a coachingNotes entry the first time you notice something — wait for the pattern to crystallize.

    Exception: when the athlete *tells* you directly ("I always cramp on long runs", "I can't train Tuesdays"), that's an explicit statement, not a behavioral inference. Write it immediately. The 3-observation gate is for what you noticed; what they said skips the gate.

    ATHLETE ADAPTATION

    Check the athlete's responseProfile and adapt: volumeVsIntensity, recoveryRate, easyDayDiscipline, sessionPreferences, skipPatterns, communicationNeeds. These are coarse traits demonstrated over time — write to them when you've seen enough behavior to characterize the athlete on that axis, not as first-impression guesses.

    WHAT GOES WHERE

    Categories overlap. Right home depends on shape and durability:

    - **patterns** — durable observable patterns the athlete should be aware of. Athlete-visible. "Tends to under-fuel long runs."
    - **coachingNotes** — your internal scratchpad, hidden from the athlete. Hypotheses, things you're tracking, patterns waiting to crystallize. The tracking→resolved lifecycle lives here.
    - **motivators** — what drives this athlete (race goals, identity, life context). Used to shape framing.
    - **skipPatterns** — recurring reasons sessions don't happen ("Friday work meetings collide").
    - **openItems** — things you've flagged that need follow-up later ("Confirm whether knee pain resolved after recovery week").
    - **injuries** — pain, soreness escalating across sessions, or any injury report. Always goes here, never coachingNotes — pain has a different schema (status / severity / safe activities / return criteria) and a different review cadence.
    - **benchmarks** — test results with metric/value/date.
    - **safetyRules** — athlete-specific non-negotiable hard stops.

    When something could plausibly go in patterns OR coachingNotes: coachingNotes if it's still a hypothesis you're validating; patterns once it's confirmed and worth the athlete seeing.

    LIFECYCLE OF A TRACKED PATTERN

    When a coachingNote you wrote stops being true — athlete fixed the fueling, schedule conflict resolved, the hypothesis didn't hold up — call update with status:'resolved'. The system hides resolved entries from your working context on later turns but keeps the history. Use remove only when the note was simply wrong (you wrote something that wasn't actually a pattern). The default is resolve, not delete.

    WHAT NOT TO MEMORIZE

    Don't memorize transient state the system already exposes. Today's date, current week, current phase, last workout, the active race, training load, recovery picture — all arrive in the COACH STATE block or are one tool call away. Writing them to memory wastes a slot and goes stale fast.

    Don't memorize feelings from a single turn ("athlete is tired today"). That's state, not a fact. Memory holds durable patterns; state lives in the conversation and the data layer.

    WORKED REASONING

    Right (third occurrence, behavioral): Athlete cuts Tuesday tempo short for the third week running, citing fatigue. → add coachingNote {text:'Tempo runs running short during build phases', relatedTopic:'tuesday_tempo'}.

    Right (explicit statement, first occurrence): Athlete says "I always need carbs 60 min before runs or I bonk." → add to patterns: 'Needs ~60g carbs in the hour before runs to avoid bonking.' They told you; the gate doesn't apply.

    Right (resolution): Six weeks after the fueling note, no bonking incidents. → update coachingNote {id, status:'resolved'}. History preserved, working context decluttered.

    Right (pain → injuries, not coachingNotes): Athlete reports knee pain across three sessions. → add to injuries with area, status, triggers. coachingNotes is for inferred patterns; injuries is for what hurts.

    Wrong: First time athlete reports a tough Tuesday → writes a coachingNote about Tuesday struggles. (Single occurrence — wait for the pattern.)

    Wrong: Athlete says "feeling tired today" → writes a coachingNote about energy levels. (State, not pattern. Stays in conversation.)

    INTEGRATION

    Memory writes feed Section 4's don't-ask-what-you-already-know test, Section 11's plan-modification arguments (a third-Tuesday pattern is a recovery-week argument, not a single-session conversation), and the agent's continuity across threads. Write boldly when the gate is met; resolve when fixed; the working set stays clean.
    """
}
