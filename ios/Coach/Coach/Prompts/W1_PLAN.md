# W1 — Weekly Preview & Review (implementation plan)

Companion to [issue #70](https://github.com/evansjesse012/coach/issues/70).
The issue is the *spec* (purpose, structure, tone, edge cases). This file
is the *plan* — what we build in this codebase, in what order, with
which file touches and PR boundaries.

## Status

**Phase 1 is complete on `main`.** All five PRs landed (`af2d850` →
`317a0a3`); end-to-end flow is wired. Three known soft spots are tracked
in [issue #80](https://github.com/evansjesse012/coach/issues/80) for
verification on the first real check-in conversation. Phases 2–5 below
have not started.

For the user-facing flow walkthrough, see
[FEATURES.md → Weekly check-in, review, and preview](../../../FEATURES.md#weekly-check-in-review-and-preview).
For the technical subsystem breakdown, see
[ARCHITECTURE.md → Weekly check-in, review, and preview](../../../ARCHITECTURE.md#weekly-check-in-review-and-preview).

## What lands in W1

- Two persistent artifacts (review covering the past week + preview
  covering the next week), produced as a paired ritual at the week
  boundary.
- A conversational Sunday/Monday check-in surfaced in the Coach chat
  thread that populates the structured review fields as it goes.
- AI-generated review response (Half B) + AI-generated preview, both
  persisted and returnable mid-week.
- Surfacing across Today (theme line), WeekDetailView (paired artifact
  embed), and Coach bar (green-light when the pair lands).
- Pattern detection across the trailing 4–8 weeks of reviews, feeding
  both the review's pattern callout and the preview's watch-outs.

## What does NOT land in W1

- Server-cron auto-generation when the athlete skips the check-in.
  Deferred to W6 (issue #67 platform-agnostic agent refactor first).
  In W1 the "you skipped → I built a generic version" message fires
  from the Monday-morning app-open trigger instead.
- Calendar integration for travel/conflict awareness (Phase 4
  surface in spec; built later as a separate track).
- Mid-week edit / addendum UI on the artifacts (data model leaves
  room; UI later).
- Onboarding-specific framing for first-week athletes (Phase 1 ships
  the generic "I'm still learning you" framing inline; dedicated
  onboarding flow is its own track).

---

## Architecture sketch

Five layers, each maps to a code area we already have or are adding:

**Data** — two new Supabase tables (`weekly_reviews`, `weekly_previews`)
+ Swift models in `Models/` + read/write methods on a new
`WeeklyArtifactsService`. `DataService.loadAll` wires them in.

**Tools** — three new tools the agent uses to drive the check-in
conversation:

- `start_weekly_review_check_in` — creates an in-progress
  `weekly_reviews` row keyed by `(user_id, week_start_date)`.
- `populate_review_field` — shallow-merges one or more structured
  fields onto the in-progress review. Called repeatedly as the agent
  extracts each field from the conversation.
- `complete_weekly_review` — finalizes the review, triggers the
  paired generation (review response + preview), and writes both
  artifacts.

These ride the same `ToolDefinitions.swift` / `ToolExecutor.swift`
pattern as everything else.

**Generation** — two new `@MainActor enum` generators, mirroring the
shape of `RecoveryPictureGenerator` and `CompletionResponseGenerator`:

- `WeeklyReviewResponseGenerator` — LLM call producing Half B prose
  plus the structured `ai_response_components` JSON.
- `WeeklyPreviewGenerator` — LLM call producing preview prose, theme,
  theme category, key sessions list, watch-outs, tactical notes,
  closing question.

Both fire from inside `complete_weekly_review`'s executor handler —
single API turn budget, ~5–10 seconds, runs server-side via the same
`chat` edge function.

**Trigger** — Sunday-evening check-in is athlete-initiated by the
Coach kicking off the conversation when they open the app on Sunday
or Monday. Implemented as an app-open / scene-active handler in
`MainTabView` (or `CoachApp`) that looks at `data.weeklyReviews` for
the prior week — if missing, the agent posts a framing message into
the chat thread:

> "Hey, let's wrap up the week. How did it feel overall?"

Logic for "missing" is just `weeklyReviews.first(where: { $0.weekStart == priorMonday }) == nil`.

**UI** — three surfaces, in order of priority:

1. **Today tab** — "This week" card on Today gets a theme line pulled
   from the active week's preview. One sentence, clearly distinct.
2. **WeekDetailView** — review (prior week) and preview (current
   week) embed as expandable sections at the top of the week view.
3. **Standalone "This Week" view** — accessed from CoachBar when
   the paired artifact green-lights, or from a Today CTA.

---

## Phase 1 — MVP (5 PRs)

Phase 1 ships the full ritual: schema → tools → generators → trigger
→ UI. Conversational from the start; pattern detection comes in
Phase 3. Each PR builds on the last; merge in order.

### PR 1.1 — Schema + models + service

**Goal:** the data exists; nothing reads or writes it yet.

- Supabase migration: `weekly_reviews` + `weekly_previews` tables
  matching the data models in issue #70's spec. Indexes on
  `(user_id, week_start_date)`.
- New `Models/WeeklyReview.swift` + `Models/WeeklyPreview.swift`
  with `Codable` matching snake_case columns.
- New `Services/WeeklyArtifactsService.swift`:
  - `loadReviews()`, `loadPreviews()` — bulk load on startup.
  - `latestReview()`, `latestPreview()` — convenience.
  - `createInProgressReview(weekStart:)`, `populateReviewFields(id:_:)`,
    `completeReview(id:)`, `savePreview(_:)`.
- `DataService.loadAll` parallel-fetches both collections; new
  `@Observable` properties `weeklyReviews`, `weeklyPreviews`.
- New `WeekStart` helper that derives the Monday of a given date in
  the athlete's local TZ (avoid UTC edge cases).

**Exit criteria:** loading the app populates both arrays; manual
INSERT into Supabase shows up in `data.weeklyReviews` after relaunch.

**Estimated diff:** ~300 lines.

### PR 1.2 — Tools + executor handlers (no generation yet)

**Goal:** the agent can drive the check-in conversation end-to-end,
producing a populated review row, but no AI response or preview yet.

- Three new tool definitions in `ToolDefinitions.swift`:
  - `start_weekly_review_check_in` — `{}` input, returns the
    in-progress review id + the prior week's adherence summary so
    the agent can frame the conversation.
  - `populate_review_field` — `{review_id, fields: {...}}`. Fields
    matches the structured columns. Shallow-merge; partial updates
    are normal (agent calls this repeatedly during the
    conversation).
  - `complete_weekly_review` — `{review_id}`. Marks `completed_at`,
    auto-computes `adherence_pct` from logged vs planned sessions
    (reuses `AdherenceComputation`), pulls week sleep avg from
    HealthKit (reuses Phase 4b infra), then returns the finalized
    review JSON.
- Executor handlers wire to `WeeklyArtifactsService` methods.
- Section 14 (or per-tool descriptions) documents the conversational
  flow: agent calls `start_*` once, `populate_*` zero or more times
  as the conversation progresses, then `complete_*` when done.

**Exit criteria:** sending the agent the message "let's wrap up the
week" causes it to call `start_weekly_review_check_in`, ask
questions one at a time, call `populate_review_field` per answer,
and `complete_weekly_review` at the end. Inspecting Supabase shows
the populated row with structured fields.

**Estimated diff:** ~400 lines (heaviest PR).

**Risk:** the conversational extraction tool-call rhythm is the
hardest UX in W1. Plan a half-day of iteration on the prompt
guidance — likely a new dedicated section or a sub-section of
Section 11 covering the check-in flow specifically. See "open
questions" below.

### PR 1.3 — Review response + preview generators

**Goal:** completing a review produces both AI artifacts.

- New `AI/WeeklyReviewResponseGenerator.swift` — single Sonnet 4.6
  LLM call, structured output (Half B prose + the
  `ai_response_components` JSON). Mirrors
  `CompletionResponseGenerator`'s pattern.
- New `AI/WeeklyPreviewGenerator.swift` — single Sonnet 4.6 LLM call,
  structured output (theme, theme_category, prose, key_sessions
  array, watch_outs, tactical_notes, closing_question). Mirrors
  the same pattern.
- `complete_weekly_review` executor now calls both generators
  sequentially and writes the results before returning. Tool
  response includes the generated `ai_response_text` so the agent
  can include it (or quote from it) in the chat reply.
- Skip pattern detection for now — Phase 3 adds the pattern callout
  and watch-out enrichment; Phase 1 emits empty arrays for those
  fields.

**Exit criteria:** completing a review writes a `weekly_previews`
row with non-empty prose and theme. The chat thread shows the
agent's reply that references / contains the review response.

**Estimated diff:** ~500 lines (two generators with their own
system prompts).

### PR 1.4 — App-open trigger + Coach bar wire-up

**Goal:** the ritual starts itself on Sunday/Monday.

- New helper in `MainTabView` (or extracted into
  `WeeklyArtifactsService`) — `shouldPromptCheckIn(now:)` returns
  true when the prior week has no review and today is Sunday after
  4pm OR Monday before noon, in the athlete's local TZ.
- `MainTabView.onAppear` and a `scenePhase` `.active` listener
  invoke a check; if it fires, post a framing message into the
  chat thread via `data.sendUserMessage` (or a new
  `data.postCoachOpener` that doesn't get treated as a user
  message).
- Coach bar's `hasUnreadCoachMessage` already lights up; the
  `coachBarExpanded` cold-launch fix from `fe3e31b` covers
  morning-of behavior.
- Add a one-shot `weeklyCheckInPromptedAt` in UserDefaults so we
  don't re-prompt the same window if the athlete dismisses without
  completing.

**Exit criteria:** opening the app Sunday at 5pm with no review
for the prior week causes the coach to post the framing message.
Completing the conversation produces the paired artifact and the
bar lights green when the preview lands.

**Estimated diff:** ~150 lines.

**Open question:** should "post a coach opener" be a new system-
initiated message type, or just synthesize a user message that
says "It's Sunday — wrap up the week" and let the agent reply
normally? The latter is simpler and ships faster; the former is
cleaner long-term (proactive messages without faking user input).
**Recommend the latter for W1**; revisit when Track 3 Pb (proactive
message generator) lands.

### PR 1.5 — UI surfaces

**Goal:** the artifacts are visible and returnable.

- `Views/Plan/WeekDetailView.swift` — embed the review (if it
  exists for this week's prior week) and the preview (if it exists
  for this week) at the top, as expandable sections.
- `Views/Home/HomeTab.swift` — "This week" card gets a theme line
  derived from `data.latestPreview?.theme`. Single sentence,
  clearly distinct typography.
- New `Views/Shared/WeeklyArtifactView.swift` — renders either a
  review or a preview as a structured card (theme header, prose,
  key sessions list, watch-outs, closing question). Reused by the
  embedded surfaces and a future standalone view.
- Optional: new `Views/Plan/ThisWeekView.swift` standalone surface
  reachable from a Today CTA. Can be deferred if scope tightens.

**Exit criteria:** Today shows the theme line; WeekDetailView
shows both artifacts; tapping into either expands the full
content.

**Estimated diff:** ~400 lines.

**Total Phase 1: 5 PRs, ~1750 lines, ~1–2 weeks of focused work.**

---

## Phase 2 — Conversational refinement

Phase 1 already ships conversational; Phase 2 hardens it.

- New prompt section or sub-section dedicated to the check-in flow
  — what to ask first, when to skip questions the athlete already
  covered, how to wrap up, when to push for clarity vs accept what
  they wrote.
- "Soft hard-gate" message when the athlete attempts to navigate to
  next week's plan without completing the check-in. Wording:
  > "I haven't built next week yet because I don't have your
  > check-in. The plan you're seeing is held flat from last week —
  > want to do the check-in so I can adapt?"
- Tool-call rhythm tuning — measure how many `populate_review_field`
  calls a typical conversation produces; aim for ≤6 (one per
  meaningful field).
- Eval cases added to `EVALS.md` covering the check-in conversation
  shape (asks one question at a time, doesn't restate prior
  answers, captures structured fields correctly).

**Estimated 1 PR, ~300 lines.**

---

## Phase 3 — Pattern detection

The piece that makes the AI feel like it's actually paying attention.

- New `AI/WeeklyPatternDetector.swift` — pure Swift functions that
  take the trailing N reviews + workouts + recovery snapshots and
  emit a list of detected patterns. Each pattern carries a stable
  id + supporting evidence + a suggested phrasing for the review
  response.
- Six required patterns per the spec:
  1. Recurring day-of-week struggles (3+ same-day cuts/skips).
  2. Sleep-performance correlation (sessions after <7h sleep are
     consistently HR-elevated).
  3. Life stress impact (training quality drops on weeks with
     life_stress > 7).
  4. Easy pace creep (avg easy run pace getting faster over time).
  5. Volume tolerance (soreness ratings vs weekly volume trend).
  6. Motivation drift (multi-week downward trend).
- `WeeklyReviewResponseGenerator` and `WeeklyPreviewGenerator` get
  the detected patterns array as part of their input prompt;
  templates ensure pattern callouts land in the right place
  (review's pattern section, preview's watch-outs).
- Patterns also write to `coachingMemory.coachingNotes` per
  Section 8 (3-observation gate already met by definition for any
  pattern that crystallizes).

**Estimated 1 PR, ~500 lines (detectors + generator wiring).**

**Risk:** the pattern detection thresholds need tuning against real
data. Plan an iteration after a few weeks of reviews accumulate.

---

## Phase 4 — Life management layer

Anticipatory notes from the athlete dossier (coachingMemory) and
known constraints.

- Preview generator gets dossier context — race date, known life
  patterns (skipPatterns), open items, recent injuries — and
  produces `life_management_notes` when relevant.
- Manual context entry: athlete can post into chat "I have a work
  trip Tuesday-Thursday" and the agent writes a temporary
  scheduling note that the next preview consumes and resolves.
- Calendar integration explicitly deferred (separate track).

**Estimated 1 PR, ~200 lines.**

---

## Phase 5 — Theme taxonomy + per-theme templates

Currently themes are free-form strings. Phase 5 codifies.

- `Models/WeeklyPreview.swift` adds `theme_category` enum (the 9
  values in the spec).
- `WeeklyPreviewGenerator` system prompt enumerates the categories
  + a one-paragraph framing template per category.
- Tone calibration per category — recovery weeks read different
  from peak weeks, baked into per-theme template fragments.

**Estimated 1 PR, ~200 lines.**

---

## Open questions (resolve before PR 1.1)

1. **Time zone canonicalization.** Athlete's local TZ for "Monday"
   and "Sunday evening." Current `DataService` uses
   `Calendar.current` (device locale). Recommend: keep that for now,
   stamp `week_start_date` as the device-local Monday at insert. If
   athlete travels across time zones during a week, the row's
   `week_start_date` follows whatever device they're using when the
   review starts. Acceptable single-user-app simplification.

2. **First-week framing.** First week of a new athlete with no prior
   review or workouts. Spec says lead on macro structure and
   acknowledge the lack of personalization. Plan: detect via
   `weeklyReviews.isEmpty && workouts.count < 7` and pass a flag to
   the generators that swaps to the new-athlete framing prompt.

3. **Conversational from PR 1.2 vs form-first then conversational.**
   Spec proposes form first (Phase 1) then conversational (Phase 2).
   I'd skip the form. The prompt's tone is conversational anyway,
   the form would be throwaway UI work, and the tool primitives
   (`populate_review_field` per call) work the same either way.
   **Confirm before PR 1.2.**

4. **Generic preview when check-in skipped.** Without server cron,
   the "I built generic because you skipped" path fires Monday
   morning when the athlete opens the app and `weeklyReviews` for
   the prior week is missing AND the prompt window is past. Plan:
   `WeeklyPreviewGenerator` accepts a `skippedCheckIn: Bool` flag
   that swaps the framing.

5. **Review/preview pairing identity.** The spec's data model has
   `paired_review_id` on the preview. What about cases where a
   preview is generated without a review (skipped check-in)? Plan:
   `paired_review_id` is nullable.

6. **Pattern persistence.** Detected patterns live where —
   `weeklyReviews.patterns_detected` (per-week snapshot) or a
   separate `coaching_memory.coachingNotes` write (durable)? Plan:
   both. The week's snapshot logs what was detected for that week's
   response; the durable note (per Section 8's 3-observation gate)
   only writes if the pattern hasn't been noted yet.

---

## Risks

**Tool-call rhythm in PR 1.2.** This is the hardest piece and the
one most likely to feel weird in user testing. Plan to ship 1.2
behind a debug flag and iterate the prompt guidance over a couple
of real check-in cycles before exposing it.

**Generation latency in PR 1.3.** Two LLM calls back-to-back at the
end of a multi-turn conversation. Could feel slow (8–15s combined).
Consider parallelizing review-response and preview generation since
they share the same input data. Or: generate review response
synchronously, then preview asynchronously (preview lands a few
seconds after the review response shows in chat). Decide based on
real-world perceived latency once 1.3 is testable.

**Pattern detection false positives in Phase 3.** Three "Tuesday
struggles" might be a pattern, or might be three coincidentally
hard Tuesdays. Tune thresholds against real data; allow the agent
to express uncertainty in pattern callouts ("might be a pattern,
worth watching").

**Spec scope creep.** Issue #70 is detailed and tempting to
implement fully. Phase 1 is the MVP that produces the ritual; the
rest is iteration. Ship 1.1 → 1.5 before starting Phase 2.

---

## Done criteria for W1 overall

W1 is complete when:

1. Sunday-evening or Monday-morning app open triggers the conversational
   check-in.
2. Completing the check-in produces both a review (Half B) and the
   following week's preview, both persisted.
3. Both artifacts surface on Today (theme line), WeekDetailView
   (embedded), and via the Coach bar green-light.
4. The trailing 4–8 weeks of reviews drive pattern detection that
   shows up in both the review's pattern callout and the preview's
   watch-outs.
5. The athlete-of-one quality bar from issue #70 Part 6 passes on
   real reviews/previews — the artifact references at least 2–3
   athlete-specific data points and reads like the coach paid
   attention.

Tests 4 and 5 require real data accumulating over weeks; expect to
treat W1 as "shipped" after Phase 3 and let 4 and 5 iterate from
there.
