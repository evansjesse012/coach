# Features

A plain-English walkthrough of how the Coach app works, what each screen
does, and how the important flows play out. If you want the technical "how
is this built" version, see [ARCHITECTURE.md](./ARCHITECTURE.md).

---

## The shape of the app

Coach is a 5-tab iOS app:

1. **Home** — today's focus. The workout you're meant to do right now,
   with one-tap completion.
2. **Goals** — your upcoming races and training goals.
3. **Plan** — your periodized training plan, phases and weeks.
4. **Log** — your workout history and exercise library.
5. **Stats** — analytics: training-load curves (CTL/ATL/TSB), weekly
   volume, intensity distribution.

Plus the **Coach chat** itself — a persistent pill above the tab bar
on every screen (the "Coach bar"), which expands into a chat sheet
when tapped. Not a tab: it's the always-on access point to the
coaching relationship.

Underlying the whole thing: an AI coach (Claude Sonnet 4.6) that has read
access to everything you've logged, can create and adjust plans, can log
workouts on your behalf, can remember things about you across
conversations, and has a distinct coaching voice you can pick.

---

## Authentication

First launch shows **Sign in with Apple**. One tap, Face ID / Touch ID,
done. The app creates a Supabase user linked to your Apple ID, stores a
JWT in the keychain, and drops you into the main tab view.

There's no email/password flow. If you sign out (from Settings), the next
launch starts back at the sign-in screen.

---

## Home tab

The home tab answers one question: **"what am I supposed to do today?"**

What you see:

- **Push message card** — a personalized greeting at the top, written by
  your coach. Pulled from your last chat's summary or a pre-seeded
  message. Dismissible.
- **Today's focus card** — the highest-priority session prescribed for
  today. For a plan day with multiple sessions (e.g. morning easy run +
  afternoon strength), this picks the key one. Shows type, duration,
  distance/pace target, effort category, and a one-line purpose.
- **Completion controls** — buttons to mark the session as:
  - **Did it** (completed as prescribed)
  - **Modified it** (completed but different — opens a sheet to enter
    actual duration/distance + a note)
  - **Swapped it** (did a different workout instead — opens a sheet to
    pick or describe the substitute)
  - **Skipped it** (opens a sheet to pick a reason: fatigue, time,
    soreness, life)
- **Needs-review banner** — if HealthKit auto-paired a workout at medium
  confidence, this shows a yellow border + review prompt on the card.
- **New workout detected** cards — unmatched HealthKit imports (see
  [HealthKit auto-matching](#workout-completion-tracking)).
- **Week glance** — a horizontal strip of dots showing this week's
  sessions and their completion state.

Tapping the completion button fires a state change that writes to the
training plan and updates the adherence computation used elsewhere in
the app.

---

## Goals tab

Your races and training goals.

### Adding a goal

Tap the `+` button. You get a picker sheet with two options:

1. **Chat with Coach** — opens `RaceCreationChatSheet`, an embedded
   chat where the coach asks what race you're training for. You can
   say "Boston Marathon 2027" and it fills in the date, location,
   distance, and preset from real-world knowledge. It uses the existing
   system prompt's race-card section and completes via the
   `app_action` tool with `target: 'goal'`, `action: 'create'`.
2. **Fill out a form** — opens `GoalFormView`, the traditional form.
   Fields: name, event type (preset picker — marathon / half-marathon /
   10k / 5k / trail / full-tri / half-tri / century / gran fondo /
   custom), race vs goal toggle, date, location, distance (single or
   triathlon sub-distances), goal time, stretch goal, baseline/current
   PR, bib number, official website URL.

Both flows end with a new row in the `events` table and an updated
Goals list.

### Race detail view

Tapping a goal card opens `RaceDetailView`:

- **Header** — name, event type badge, days-until countdown, date,
  location, distance, goal time, "Official site" link (opens in an
  in-app `SFSafariViewController`).
- **AI Race Overview card** — structured race-day conditions:
  - 2-sentence summary of what makes the race distinctive
  - Stat strip: terrain, elevation, climate (short + detail tooltip)
  - 5-8 prioritized tips from the coach ("start conservative —
    the first 5k drops into the headwind", "fuel every 20min...")
  - A "Regenerate" button that kicks off a fresh call
- **Weather card** — a 7-day forecast pulled from Open-Meteo when the
  race is within 2 weeks, with an AI-generated impact narrative
  ("tailwind at the gun, 10s/mi faster than target pace for the
  first 5k is realistic"). For longer-lead races, shows historical
  norms.
- **Race plan card** — AI-generated pacing and nutrition strategy
  (lives in `event.planSections`).
- **Notes card** — athlete-added race notes with a quick-add field.
- **Result card** — shown after the race, with actual time and notes.

The race overview is generated by `RaceConditionsGenerator`, which
calls Claude with Anthropic's native `web_search` tool enabled so the
official URL is sourced from real search results rather than model
memory. The weather impact narrative is a separate call via
`WeatherImpactGenerator`.

---

## Plan tab

Your current training plan.

What you see top to bottom:

- **Compact goal header** — race name, date, days to go.
- **Freshly Generated Banner** (when applicable) — a subtle
  accent-tinted card that reads *"Your coach wrote week N. Tap to
  preview what's coming up next."* Appears when background
  pre-generation just completed a future week. Tapping navigates to
  that week and dismisses the banner.
- **Full plan timeline** — a horizontal bar showing all phases, with
  a marker on your current week.
- **Phase stack** — one card per phase (Base / Build / Peak / Taper,
  or whatever the coach picked). Each phase card has three visual
  modes:
  - **Completed** — small muted row with a checkmark
  - **Current** — hero card with philosophy, week count,
    intensity distribution mini-bar, key workouts preview
  - **Upcoming** — outlined preview card
  Tapping opens `PhaseDetailView` — a detail screen showing the
  phase's full philosophy, volume range, sessions per week, key
  workouts, strength focus, physiological goals, progression rules.
- **This week card** — a `WeekCard` showing the current week's
  sessions. Tapping opens `WeekDetailView` with per-day cards.
- **Modify plan with your coach** — a subtle link that routes to the
  Coach tab with a pre-seeded prompt for plan modification.

### Building a plan

Tapping "Build a plan with your coach" from the empty state opens
`PlanCreationChatSheet`. This is an embedded chat (not a jump to the
Coach tab) so the athlete never leaves the Plan tab context. Inside:

- The coach greets with race-aware context already in hand ("Let's
  build your plan for Big Sur Marathon on Nov 8 — about 16 weeks
  out. How many days a week can you train, and do you prefer
  Saturday or Sunday for long runs?").
- The athlete answers; the coach asks follow-ups if needed.
- When the coach has enough info, it calls `create_training_plan`.
  The generator kicks off and streams its output back. The loading
  bubble reflects stages: "Designing your season structure…" →
  "Writing week 1 in detail…" → "Finalizing your plan…".
- On success, the input bar swaps for a "Plan saved — X-week plan,
  week 1 ready · View plan →" tile. Tapping dismisses the sheet and
  the Plan tab renders the new plan underneath.

---

## Plan creation: how it actually works under the hood

The plan generator doesn't try to write every daily session for every
week in one giant call — that would take minutes and blow past network
timeouts. Instead it uses a **skeleton-first, lazy-weeks** approach
that mirrors how a real coach designs a season:

1. **Skeleton call** — one API call to Claude that generates the
   *phase structure only*. The output is a list of phases (2–5
   typically, but the coach picks based on runway), each with:
   - Week count (must sum to total plan length)
   - Start and end dates
   - Philosophy (2–3 sentences personalized to the athlete and race)
   - Weekly volume range
   - Sessions per week
   - Intensity distribution (% easy / tempo / threshold / VO2max)
   - Key workouts (3–5 per phase with descriptions)
   - Strength focus
   - Physiological goals
   - Progression rules
   - Race-specific notes
   - Deload week positioning
   
   The prompt gives the coach full latitude on these choices — "you
   decide how many phases, how long each runs, what they're called".
   No hardcoded template. For long runways (>6 months), it explicitly
   tells the coach to spend most of the plan in base building; for
   short runways, to compress into specific prep.
   
   Output size is fixed regardless of plan length: a 12-week plan and
   a 78-week plan both produce ~1.5–2k tokens of skeleton. Completes
   in ~20–30 seconds.

2. **Week 1 generation** — a second API call that writes the current
   week's 7 days of sessions in full detail. The prompt includes the
   relevant phase's context so the sessions match the phase's
   intensity mix, volume target, and key workout placement.

3. **Stubs for every other week** — weeks 2 through N are stored as
   `WeeklyPlan` stubs: just their `phase` number and an empty
   `sessions: []` array. The Plan tab shows them as "Not yet planned"
   with a "Generate now" button.

Total initial creation time: ~60–90 seconds streamed end-to-end. Every
future week gets shaped closer to when it's needed, based on how the
athlete is actually doing.

---

## Lazy per-week generation

Stub weeks get filled in either by the coach chat (via the
`generate_week_plan` tool), by tapping "Generate this week now" on a
stub card, or automatically by the background pre-generation pipeline.

When a week is generated, the prompt includes:

- **Phase context** for the phase containing this week (philosophy,
  volume range, key workouts, progression rules, etc.).
- **Week position** ("week 5 of 12 in Base phase"), and whether this
  is the phase's deload week.
- **Recent adherence history** for the last 3 weeks — which sessions
  were completed, which were modified, which were skipped or swapped,
  plus any completion notes the athlete left ("cut short due to
  rain", "knee felt off"). This lets the coach *adapt*: progress if
  the athlete is nailing everything, pull back if they're missing
  key sessions or flagging fatigue.

The generator writes a full 7-day week (Monday-Sunday), including
rest days with personalized rest notes, strength sessions with
exercise lists, and every non-rest session with fuel prescriptions.

---

## Auto-advance and pre-generation

Two problems the app solves automatically:

**Problem 1: currentWeek doesn't know time has passed.** If the athlete
opens the app in week 3 of a plan that started 5 weeks ago,
`plan.currentWeek` would still say 1. Fix: on app launch (and Plan tab
appearance), compute "what calendar week are we in" from
`startDate + today` and advance `currentWeek` / `currentPhase` if
needed.

**Problem 2: stub weeks aren't generated until the athlete asks.** If
the athlete passively uses the app through week 1 and then opens it
Monday morning for week 2, week 2 is still a stub — they stare at a
"generate now" button instead of having sessions ready.

Fix: the background pre-generation pipeline. On Thursday (day 3+) of
the current Mon-Sun week, if next week is still a stub, silently
generate it. By Friday morning the athlete can peek ahead and see a
fully-populated week; by Sunday night it's waiting for them.

Why Thursday specifically? That's when a real coach would sit down to
write next week — early enough to give the athlete mental runway
before Monday, late enough that the coach has observed how the
current week's key sessions went (Tuesday intervals, Wednesday
moderate run). The adherence-aware prompt pulls in that context
automatically.

**Phase-transition lookahead**: if next week begins a new phase, the
week *after* it is also silently pre-generated. Extra mental runway
for transitions like base → build or build → peak.

**The visual cue**: when a pre-generation completes, `PlanTab` shows
a small accent-tinted banner at the top of the content — *"Your
coach wrote week N. Tap to preview what's coming up next."* Tapping
navigates to that week and dismisses the banner. It's how the
athlete sees that work happened in the background while they were
busy.

---

## Coach chat tab

The main AI chat. A clean messaging interface with:

- **Personality-aware system prompt** — the coach's voice is set by
  the athlete's chosen personality (see [Settings](#settings)).
- **Tool-use agent loop** — the coach can call any of 21 tools per
  turn (loop caps at 5 rounds by default). Tools are the coach's
  hands and eyes on your data.
- **Streaming-looking output** — responses render with a loading
  bubble that shows contextual progress ("Checking your profile…",
  "Reviewing your data…", "Building your plan…") based on which
  tool is currently running.
- **Markdown rendering** — bold, italic, bullet lists, and links
  render inline via `AttributedString(markdown:)`.
- **Metadata badges** on assistant messages — small chips like
  "Logged" or "Plan updated" when the turn produced side effects.
- **Memory extraction** — runs in the background after every turn
  to harvest durable facts about you (injuries, benchmarks, patterns,
  equipment) and merge them into your coaching memory.
- **Conversation auto-archive** — chat threads archive automatically
  after 2 hours of inactivity. On archive a 1–2 sentence summary is
  generated and stored on the conversation; the next thread's coach
  has the last 3 summaries injected into its prompt for thread-to-
  thread continuity without re-sending old transcripts.
- **Per-turn coach state** — every chat turn the coach prompt
  includes today's date, a chronic-load snapshot (CTL/ATL/TSB +
  7-day ramp), an LLM-generated recovery picture from overnight
  HealthKit data, and the recent-conversation summaries above. All
  of this rides in a dynamic block so the rest of the (much larger)
  prompt stays cached.

### What the coach can do

The agent has access to these tools, grouped by function:

**Read-only:**
- `get_workouts` — recent cardio sessions with filters
- `get_training_plan` — full plan or a specific week
- `get_training_stats` — volume, distance, time-in-zone aggregates
- `get_personal_records` — PRs by exercise
- `get_goals` — active races and training goals
- `get_athlete_profile` — the full coaching memory
- `get_nutrition` — recent fueling history
- `get_week_review` — adherence summary for a specific week
- `get_plan_history` — archived plans

**Writes:**
- `log_workout` — add a cardio session on your behalf
- `log_nutrition` — add a meal/fuel entry
- `create_training_plan` — generate a full plan (calls
  `TrainingPlanGenerator`)
- `generate_week_plan` — fill in a stub week (calls
  `TrainingPlanGenerator.generateWeek`)
- `save_weekly_plan` — wholesale replacement of one week (rare;
  used when the athlete wants to rewrite the whole week at once)
- `patch_weekly_plan` — surgical edits to a week (move a session
  between days, change a distance, toggle rest, add or delete a
  session). Operations apply atomically — if any op is invalid,
  none apply. This is the preferred way to adjust a week.
- `update_plan_progress` — advance `currentWeek` / `currentPhase`
  explicitly
- `app_action` — a catch-all for create/update/delete of goals,
  workouts, memory (injuries, benchmarks, equipment, safety rules,
  etc.), settings, plan, and tab navigation. This is how the coach
  can do pretty much anything you could do in the UI.

### How the coach uses context

Every turn, the system prompt tells the coach to be *context-calibrated*:

- **Quick (no tools)** — greetings, motivation, answers from the
  current conversation.
- **Light (1–2 tools)** — logging a workout, quick stat check.
- **Moderate (2–3 tools)** — "how am I doing?", coaching advice,
  injury-aware prescription.
- **Full (4+ tools)** — weekly plan generation, plan creation, major
  adjustments.

The prompt also carries a safety protocol: before prescribing any
session, check injury state, benchmarks, and user-defined safety
rules. Universal rules baked in: fever → rest, sharp joint pain →
stop/modify, chest pain → stop immediately, sleep < 5h → easy only.

---

## Weekly check-in, review, and preview

The weekly ritual is the coaching relationship's heartbeat. Once a
week the coach kicks off a wrap-up conversation in the chat thread.
The conversation produces two **artifacts** — persistent documents,
not chat messages — that the athlete can return to throughout the
week. The review captures the week that just ended; the preview
frames the week ahead. They get produced together as a paired
ritual at the week boundary.

### When it triggers

The coach posts the wrap-up opener automatically when:

- It's **Sunday after 4pm local time** OR **Monday before noon**
- AND no completed review exists for the week being wrapped up
- AND we haven't already prompted in this trigger window (debounced
  via `UserDefaults` so reopening the app doesn't repost)

The trigger fires from the app-open / scene-active path in
`MainTabView`, not a server cron — so it requires the athlete to
open the app within the window. Server-driven scheduling is on the
backlog (issue #67 platform-agnostic agent refactor unblocks it).

When the trigger fires, the Coach bar lights up green and
auto-expands into its 300pt accent card showing the opener:

> *"Hey, let's wrap up the week. How did it feel overall?"*

### The check-in conversation

The athlete taps the bar (or scrolls into chat) and replies. Their
reply kicks off the agent loop normally; the coach then runs the
**WEEKLY CHECK-IN** flow defined in Section 11 of the system prompt:

1. The coach calls `start_weekly_review_check_in` once, before
   asking the first question. That creates an in-progress
   `weekly_reviews` row keyed to the week being reviewed and
   returns a compact adherence summary (X% completed, Y skipped,
   Z modified) so the coach can frame the conversation around
   what actually happened.
2. The coach asks one question per turn. The athlete answers.
3. After each answer, the coach calls `populate_review_field`
   with whichever fields the answer addressed. The structured
   row fills incrementally — sleep hours, energy 1–10, motivation
   1–10, soreness level, pain flag + description, life stress
   1–10, life context, best/worst session, questions, next-week
   focus.
4. Coverage map (any order; the coach adapts to the athlete):
   how the week felt overall, what stood out, pain/soreness, life
   context, anything to flag for next week.
5. When the conversation has covered the territory, the coach
   calls `complete_weekly_review`. This:
   - Stamps `completed_at` on the review row
   - Auto-computes adherence percentage from logged-vs-prescribed
     sessions
   - Fires both AI generators in parallel (~6–10s wall time)

### The review artifact (the week just ended)

The completed review row holds:

- **The athlete's check-in answers** — structured ratings and
  free-text fields above
- **The AI's response prose** — 100–250 words written by a Sonnet
  4.6 call covering, in order: life context acknowledgment (if any
  was raised), honest assessment of the week, specific feedback on
  1–2 key sessions, pattern callout (only if something across
  multiple weeks is genuinely surfacing), direct answers to
  athlete-raised questions, bridge to next week
- **Structured component breakdown** — the same prose split into
  `life_acknowledgment`, `week_assessment`, `session_feedback`,
  `pattern_callout`, `questions_answered`, `bridge_to_next_week` so
  later analytics can read the structure without re-parsing prose
- **Detected patterns** — currently empty in W1 Phase 1; pattern
  detection across the trailing 4–8 weeks of reviews is the Phase 3
  enhancement

### The preview artifact (the week ahead)

The paired preview row holds:

- **Theme** — one prominently-displayed sentence stating what kind
  of week this is. Examples:
  > *"This is your hardest week of the build — everything is hard
  > on purpose."*
  > *"Recovery week — resist any urge to add intensity."*
  > *"Race week. Everything you do should support the start line."*
- **Theme category** — one of: build / recovery / peak / race_week
  / taper / base / consolidation / return_from_break / bridge
- **Macro position** — *"Week 4 of 8 in the build, 12 weeks until
  Oceanside."*
- **Volume metrics** (computed in Swift, not LLM) — total planned
  hours, distance, quality vs easy session counts, delta from
  previous week
- **Key sessions** (1–3) — each named with day-of-week, why it
  matters this week, what success looks like, what to watch for
- **Watch-outs** — athlete-specific risk callouts based on dossier
  + recent patterns (sleep deficit pattern, weather forecast,
  scheduling conflict)
- **Tactical notes** — pacing, fueling, gear, recovery, strength
  integration as relevant
- **Life management notes** — anticipatory framing using known life
  context (work trip, kid schedules)
- **Rendered prose** — 300–500 words; the body the athlete actually
  reads
- **Closing question** — one sentence inviting two-way conversation
- **Engagement** — `read_at` stamped on first view, `reread_count`
  incremented on subsequent opens

### Where artifacts surface

The artifacts are visible across four places:

- **Coach bar** — the chat reply summarizing the wrap-up auto-expands
  into the 300pt accent card. The athlete reads it without leaving
  the current tab.
- **Today tab** — a single-line "This week" theme line (accent-tinted
  callout) sits below the week header. Tapping opens the full preview
  in a modal sheet.
- **WeekDetailView** — the prior week's review (if completed) and the
  current week's preview (if it exists) embed as cards at the top of
  any week's plan view. Both render via the shared
  `WeeklyArtifactView`.
- **Standalone modal sheet** — the full preview / review card with
  every structured section expanded. Stamped as read on first view.

### What happens if the athlete skips the check-in

For W1 Phase 1, skipped check-ins are not auto-resolved (server cron
deferred). If the athlete opens the app on Tuesday without having
done the Sunday check-in, the trigger window is past and no opener
posts. The plan stays held flat from the previous week until the
athlete starts a check-in manually or waits for the next Sunday.

Phase 2 of W1 will add a soft hard-gate: if the athlete navigates to
next week's plan without a check-in, a banner appears explaining
that the plan is held flat and offering to regenerate after the
check-in.

### What's still in flight

W1 Phase 1 (the ritual end-to-end) shipped in commits `af2d850`
through `317a0a3`. Three known soft spots are tracked in [issue
#80](https://github.com/evansjesse012/coach/issues/80) — verify on
first end-to-end test:

1. Tool-call rhythm — whether the coach actually populates fields
   per-turn vs batching at the end
2. Generation latency — whether 6–10s of "..." between hitting send
   and the chat reply landing feels acceptable
3. Theme line refresh — whether the Today theme line updates
   immediately after a check-in completes, or requires kill-and-
   relaunch (SwiftUI @Observable edge case)

Phase 2 (conversational refinement + soft hard-gate), Phase 3 (the
6 multi-week pattern detectors that drive pattern callouts and
watch-outs), and Phase 4–5 (life management layer + theme taxonomy)
are tracked separately.

---

## Stats tab — training load and analytics

The Stats tab is the analytics view of how your training has been
trending over weeks and months. The headline content is the
**Performance Management Chart (PMC)** — three curves that summarize
chronic vs acute training stress:

- **CTL ("fitness")** — a 42-day exponentially-weighted average of
  daily training stress. Climbs slowly with consistent training; the
  chronic-frame view of how much work your body is absorbing.
- **ATL ("fatigue")** — a 7-day EWMA of the same daily stress.
  Reactive; spikes with hard sessions and decays within a few days.
- **TSB ("form")** — `CTL − ATL`. Negative when fatigue exceeds
  fitness (mid-build, expected); positive when you're freshening up
  (taper, race week).

Phase boundaries from the active training plan are overlaid so you
can see when transitions happened relative to the curves. The chart
also surfaces weekly-volume bars (per sport) and intensity
distribution.

### How the numbers get computed

Per-workout TSS (training stress score) flows through a tiered
"ladder" — for each workout the calculator tries the ideal method
first and falls back through progressively coarser ones, stamping a
confidence level so the curve below knows how much to trust each
contribution:

- **Cycling:** power-normalized (best) → power-avg → HR-zone →
  HR-avg → session-RPE → sport default.
- **Running:** pace-gap (uses your threshold pace, with elevation
  adjustment) → flat pace → HR-zone → HR-avg → effort category.
- **Swimming:** pace per 100 → HR → effort category.
- **Strength:** session RPE × duration → volume load → effort
  category fallback.

Each method picks the threshold that was effective on the workout's
date — `benchmark_history` carries a versioned timeline (LTHR, FTP,
threshold pace, CSS) so a workout from 8 months ago doesn't get
re-scored against today's FTP.

`daily_training_load` rows are immutable once written. When you log,
edit, or delete a workout, only the rows from that date forward
recompute — past rows stay put.

### "Calibrating" notes

When the EWMAs haven't built up enough history (typically the first
few weeks of using the app, or after a long gap), the curves are
mathematically valid but don't yet reflect your real fitness picture.
The Stats tab surfaces a "calibrating" note in those cases rather
than presenting under-cooked numbers as authoritative.

---

## Workout completion tracking

Every prescribed session can be in one of 6 states:

- **Upcoming** — hasn't happened yet
- **Completed** — done as prescribed (green checkmark)
- **Needs review** — paired by HealthKit at medium confidence,
  waiting for athlete confirmation (amber border, "Tap to review")
- **Modified** — done but with different duration/distance (yellow
  check, with the actual values stored)
- **Swapped** — did a different workout instead (purple swap icon,
  with the actual sport stored)
- **Skipped** — explicitly skipped with a reason (gray X)

The athlete can mark these manually from Home tab action buttons or
from Plan tab (`WeekDetailView.SessionCard` has the same controls).

### HealthKit auto-matching

When the athlete has HealthKit connected, the app syncs their workouts
and tries to automatically pair each imported workout with a prescribed
session. The flow:

1. **Sync** — `DataService.syncHealthKitWorkouts` fetches the last N
   days' workouts and filters to ones we haven't already imported.
2. **Candidate gathering** — for each unmatched workout, the app
   collects prescribed sessions that could plausibly match: today's
   sessions, yesterday-after-8pm sessions, tomorrow-before-6am
   sessions.
3. **Scoring** — `WorkoutMatcher` scores each candidate:
   - Sport match: +40 points (required — mismatches are filtered out)
   - Duration in range: +30 points
   - Duration within 20% of range: +15 points
   - Time-of-day proximity: +15 points (only meaningful with
     multiple same-sport candidates)
   - HR zone exact match: +15 points
   - HR zone adjacent: +5 points
4. **Confidence mapping** — raw score maps to high (≥70), medium
   (40-69), low (1-39), or none.
5. **Action**:
   - **High confidence** → auto-pair silently, mark session as
     completed, store actual duration/distance
   - **Medium confidence** → auto-pair + set `completionNeedsReview:
     true`, surface review prompt in Home tab
   - **Low / none** → push onto `pendingHealthKitImports` for
     manual handling via a "New workout detected" card

The athlete can always override by tapping the needs-review card or
dismissing the unmatched import.

---

## Live strength workout tracker

A Strong-app-style tracker for strength sessions. Entry points:

- **From a prescribed strength session** — tap "Start Workout" on a
  strength session in `PrescribedSessionDetailView`. The prescribed
  exercises materialize into live sets ready to check off.
- **From the Log tab** — "Start Workout" banner. Shows a picker sheet
  with:
  - Saved templates (quick-start)
  - A "Blank workout" option
  - "Resume" if there's an in-progress session
- **From a past session** — "Repeat Workout" on `StrengthDetailView`
  clones the session with all sets reset and uses it as a template.

Inside the live view (`WorkoutLoggingView`):

- **Header** — workout name, elapsed time, cancel button, finish
  button (enabled once any set is marked complete).
- **Exercise cards** — one per exercise. Shows exercise name, type
  badge (weighted/bodyweight/banded/timed/cardio-drill), and per-set
  rows. Each set has editable weight/reps/duration fields and a
  "mark complete" checkbox.
- **Rest timer overlay** — floating bar at the bottom that shows
  remaining seconds with ±15s adjustments. Kicks off automatically
  when a set is marked complete (using the exercise's prescribed
  rest duration); can be skipped.
- **Add exercise** — opens a picker sheet to search the exercise
  library (catalog + custom + recent) and add one mid-workout.
- **Workout-in-progress pill** — a floating pill above the tab bar
  that persists across tabs, so the athlete can navigate elsewhere
  and jump back to the tracker without losing state.

On finish:

1. Empty exercises (no completed sets) are dropped
2. Trailing uncompleted sets are trimmed
3. Session is persisted via `addStrength`
4. PRs are rolled — for each completed set, `computeExercisePR`
   checks against the existing PR and upserts if a new record was set
5. Active session state is cleared

Mid-workout state survives app kills via `UserDefaults` persistence.

---

## Log tab & exercise library

**Log tab** shows:

- **Exercise library entry** — a nav card at the top.
- **Workouts / Strength toggle** — switches between cardio and
  strength history.
- **Sport filter chips** (cardio mode) — All / Run / Bike / Swim /
  Hike.
- **Session list** — one row per logged workout, with sport badge,
  date, notes, duration/distance. Tapping opens a detail view.

**Exercise library** (`ExerciseLibraryView`):

- Search bar + filter chips for body part (Chest, Back, Legs,
  Shoulders, Arms, Core, Full Body) and equipment (Barbell, Dumbbell,
  Machine, Cable, Bodyweight, Band, Kettlebell).
- Alphabetically grouped list with sections A–Z plus a "From Your
  History" section for exercises you've done but aren't in the
  catalog.
- Each row shows the exercise name, body part + category, and PR
  summary.

Built-in catalog: 234 exercises across all 7 body parts and all 7
equipment categories, seeded via Postgres migrations. Users can add
custom exercises that merge into the library.

**Exercise detail view:**

- Header with name, type, muscle groups, custom/history badges
- PR stats (weight × reps + estimated 1RM, or best reps / best
  duration / best band level depending on exercise type)
- Progression chart over time
- Session history list

---

## Coaching memory

The coach remembers things about the athlete across conversations.
Memory is tiered so different kinds of facts live in appropriate
places.

### The structure

`CoachingMemory` has 6 sub-structures:

1. **Permanent** — things that rarely change:
   - Equipment the athlete owns (smart trainer, power meter, etc.)
   - Facilities they train at (pool, gym, climbing wall)
   - Schedule (days per week, preferred times, constraints)
   - Medical history (asthma, prior injuries, conditions)
   - Dietary constraints
   - Communication preferences
   - Safety rules the athlete has asked the coach to always follow
2. **Benchmarks** — performance data points with a metric, value,
   test date, and method. Updated each time a new test happens. Used
   to compute pace ranges, power targets, threshold zones.
3. **Injuries** — a list of active/monitoring/resolved injuries with
   area, severity, triggers, safe activities, and modifications. The
   coach consults this before prescribing sessions and adds `warning`
   fields to sessions that might aggravate an active injury.
4. **Observations** — softer patterns the coach has noticed:
   training patterns, motivators, consistency notes, current focus,
   open items, coaching notes. These are the freeform notes a real
   coach would jot down after a conversation.
5. **Response profile** — how the athlete responds to training:
   volume vs intensity sensitivity, recovery rate, easy day
   discipline, session preferences, skip patterns, communication
   needs. Informs how the coach prescribes work.
6. **Conversation summaries** — short 1–2 sentence summaries of each
   chat session, useful for the coach to remember what was recently
   discussed without rehashing the full transcript.

### How memory gets populated

After every chat turn, a background task fires
`MemoryExtractor.extract`, which sends the recent messages to Claude
with a dedicated memory-extraction prompt. The prompt asks the model
to classify any new facts into the 6 tiers above and return them as
JSON. The extractor then merges them into the existing memory without
duplicating and persists via `saveMemory`.

The coach can also update memory directly via the `app_action` tool
with `target: 'coaching_memory'` — useful when the athlete explicitly
says "remember that I prefer long runs on Saturday" or "I have a new
Garmin HRM".

### How memory gets used

Every turn of the chat, the system prompt tells the coach to consult
the memory before prescribing work:

- **Pre-prescription safety check** — before writing any session,
  read `permanent.safetyRules` and the active injury list. Apply
  modifications or warnings.
- **Adaptation** — read `responseProfile` and adapt: a
  volume-sensitive athlete gets volume-focused progressions; an
  intensity-responsive athlete gets more quality work.
- **Benchmarks → pace/power ranges** — when prescribing a zone-based
  session, pull the relevant benchmark and compute the actual target
  range.
- **Patterns** — if `observations.skipPatterns` mentions "often
  skips strength on Thursdays", the coach can proactively move
  strength to Wednesday or Friday.

---

## Settings & personalities

Under the Settings screen:

- **Appearance** — system / light / dark
- **Coach personality** — pick one of four voices:
  - **Normal (Head Coach)** — direct, professional, no fluff.
    Pushes when you're sandbagging, pulls back when you're overdoing
    it, grounds advice in your data.
  - **Goggins** — accountability coach. Doesn't accept excuses.
    Pushes you to find 10% more. Still respects safety protocols —
    even Goggins doesn't tell you to run through chest pain.
  - **Hype** — positive-energy coach grounded in real data.
    Celebrates specific achievements with specific numbers. Still
    honest about missed sessions.
  - **Custom** — pick your own voice. A text field lets you describe
    the coaching style you want.
- **Athlete profile link** — opens a read-only view of your full
  `CoachingMemory` (so you can see what the coach knows about you).
- **Clear and reseed data** — dev-only buttons for loading demo
  data.

The personality flows into the system prompt via
`getPersonalityPrompt` in `SystemPrompts.swift`, which prepends the
voice to every chat turn.

---

## Race day features

When a race is within 2 weeks, extra features activate on
`RaceDetailView`:

- **Weather forecast** — 7-day hourly forecast from Open-Meteo,
  cached on the event row.
- **Gun-time-specific strip** — hourly cards for race day starting at
  the gun time, showing temperature, apparent temp, wind, and
  precipitation chance.
- **AI weather impact narrative** — Claude turns the forecast into a
  coaching note ("tailwind at the gun, 10s/mi faster than target for
  the first 5k is realistic; headwind returns on the loop at mile 18
  — save something for it").
- **Race conditions card** — if not already generated, shows a
  "Generate overview" button. Calls Claude with Anthropic's native
  `web_search` tool to look up the actual race, find terrain /
  elevation / climate data, and extract the official race website
  URL (prioritizing organizer pages over aggregators). Returns a
  structured summary with 5-8 prioritized tips.

---

## Other notes

- **No offline mode.** Every action hits Supabase. If the network is
  down, writes fail and the app shows an error.
- **Data ownership.** Everything in Supabase is scoped to your user
  via row-level security. Sign out clears the keychain session but
  leaves your Supabase rows intact — signing back in restores
  everything.
- **Claude API key never leaves the server.** All Anthropic calls go
  through the Supabase edge function, which holds the API key as a
  server-side secret.
- **Dev flags.** A couple of HealthKit helpers (`injectMockHealthKitWorkout`)
  and a seed data loader exist for testing the completion tracking
  and strength tracker flows without waiting for real data.
