# Architecture

How the Coach app is built, layer by layer. Written for someone onboarding
to the codebase or trying to understand how a specific subsystem works
without reading the code line by line.

For the product-level walkthrough of what the app does (in plain English),
see [FEATURES.md](./FEATURES.md).

---

## The big picture

```
┌─────────────────────────────────────────────────────────────┐
│                          iOS App                            │
│  ┌──────────────┐  ┌─────────────────┐  ┌────────────────┐  │
│  │  SwiftUI     │  │  DataService    │  │  AI Layer      │  │
│  │  Views       │◄─┤  (@Observable)  ├──┤  Agent Loop    │  │
│  │              │  │  central store  │  │  Tools         │  │
│  └──────────────┘  └───┬─────────────┘  │  Generators    │  │
│                        │                 └──────┬─────────┘  │
│                        │                        │            │
│                  ┌─────┴──────┐                 │            │
│                  │ HealthKit  │                 │            │
│                  │ Weather    │                 │            │
│                  └────────────┘                 │            │
└────────────────────────┬────────────────────────┼────────────┘
                         │                        │
                         │ Supabase SDK           │ URLSession
                         │ (Postgres + Auth)      │ (streaming SSE)
                         ▼                        ▼
┌─────────────────────────────────────────────────────────────┐
│                        Supabase                              │
│  ┌───────────────┐  ┌────────────────┐  ┌─────────────────┐  │
│  │   Postgres    │  │  Auth (JWT)    │  │  Edge Function  │  │
│  │   + RLS       │  │  Sign in with  │  │  `chat` proxy   │  │
│  │               │  │  Apple         │  │                 │  │
│  └───────────────┘  └────────────────┘  └────────┬────────┘  │
└──────────────────────────────────────────────────┼────────────┘
                                                    │
                                                    │ HTTPS
                                                    ▼
                                         ┌─────────────────────┐
                                         │  Anthropic Claude   │
                                         │  Sonnet 4.6         │
                                         └─────────────────────┘
```

Three tiers:

1. **iOS client** — Swift 5, SwiftUI, iOS 26 target. All app state lives in
   a single `@Observable` class (`DataService`) that views subscribe to.
2. **Supabase backend** — Postgres for persistence, Supabase Auth for
   Sign in with Apple, and a single Deno Edge Function that proxies
   Anthropic API calls so the API key never leaves the server.
3. **Claude** — Anthropic's Sonnet 4.6 model powers the coach chat, plan
   generation, race overview generation, weather impact narratives, and
   memory extraction. All calls go through the edge function.

---

## Tech stack

| Layer | Stack |
|---|---|
| UI | SwiftUI + `@Observable` (Swift 5.9 observation macro) |
| Navigation | `NavigationStack` + `.sheet` / `.fullScreenCover` |
| State | Single `DataService` injected via `@Environment` |
| Persistence | Supabase Postgres (via `supabase-swift` SDK) |
| Auth | Sign in with Apple → Supabase Auth |
| Backend functions | Deno Edge Functions on Supabase |
| Inference | Anthropic Claude Sonnet 4.6 (`claude-sonnet-4-6`) |
| Inference transport | SSE streaming for plan generation, non-streaming JSON for chat agent loop and one-shot generators |
| Local sensors | HealthKit (read-only: workouts, HR zones, route) |
| Third-party services | Open-Meteo (weather forecasts), Anthropic web search tool (race website lookup) |

---

## iOS layers

### Views

All under `ios/Coach/Coach/Views/`, organized by tab:

- `Auth/` — Sign in with Apple screen
- `Home/` — today's focus, quick actions, completion sheets
- `Goals/` — race card list, race detail view, form-based goal creation,
  chat-based race creation
- `Plan/` — phase browser, weekly plan detail, plan creation chat,
  prescribed session detail
- `Coach/` — the main AI chat tab
- `Log/` — activity history, exercise library entry point
- `Exercises/` — exercise catalog, detail view with PR history
- `Strength/` — the live strength workout tracker (Strong-app style)
- `Settings/` — app preferences, coach personality, athlete profile
- `Shared/` — reusable components (`CoachCard`, `CoachFonts`, `CoachColors`,
  `SafariSheet`, `DotsLoader`, pills, labels, etc.)

Design system lives in `Shared/`: `CoachColors` (brand palette + light/dark
variants), `CoachFonts` (`.display`, `.ui`, `.mono` presets), `CoachCard`
(rounded card wrapper with border + optional accent bar).

### DataService

`ios/Coach/Coach/Services/DataService.swift` — the center of gravity. A
single `@Observable @MainActor final class` that:

- Holds all in-memory state (events, training plan, cardio workouts,
  strength sessions, nutrition, coaching memory, settings, templates,
  PRs, catalog exercises, active strength session, rest timer state,
  chat messages, pre-generating-weeks set, recently-pregenerated-week
  signal, etc.)
- Exposes CRUD methods that mutate local state optimistically and
  persist to Supabase via the SDK.
- Acts as the single source of truth — views never hit the network
  directly; they call DataService methods.
- Provides convenience wrappers for things like `generateWeek(_:)` that
  call into the AI layer but handle persistence on the way back.
- Hosts `ensurePlanPreGenerated()` for auto-advancing `currentWeek` and
  background-generating upcoming weeks on the Thursday threshold.

Views receive it via `@Environment(DataService.self) var data`.

### Services

Targeted service classes for things that don't belong on `DataService`:

- `SupabaseService.swift` — singleton holding the configured
  `SupabaseClient`. URL + anon key hardcoded (safe — RLS protects data).
- `HealthKitService.swift` — an `actor` wrapping HealthKit queries. Auth
  prompts, workout fetching, HR zone extraction, route decoding.
- `WeatherService.swift` — Open-Meteo proxy for 7-day forecasts at a
  lat/lon. Caches recent fetches on the event row.
- `WeatherImpactGenerator.swift` — one-shot Claude call that turns a
  weather forecast into a coaching narrative ("expect 65°F and 15mph
  headwind — go out 10s/mi slower than target pace on the first 5k").
- `RaceConditionsGenerator.swift` — one-shot Claude call with
  Anthropic's native `web_search` tool enabled; returns a structured
  JSON object with terrain, elevation, climate, pacing tips, and the
  official race URL.
- `TrainingPlanGenerator.swift` — the centerpiece of the AI layer.
  Generates the phase skeleton (streaming) and individual weeks
  (streaming, adherence-aware). See [plan generation](#plan-generation).
- `SeedData.swift` — loads a curated set of demo data into the signed-in
  user's account for dev/demo — races, a training plan, strength
  sessions, templates, PRs, coaching memory.

### AI layer

Under `ios/Coach/Coach/AI/`:

- `AgentLoop.swift` — runs the multi-turn tool-use loop against Claude
  for the coach chat. Submits messages + tool definitions to the edge
  function (non-streaming), gets back a response, dispatches any
  `tool_use` blocks through `executeTool`, appends results, and
  continues until `stop_reason == "end_turn"` or a max-rounds cap.
  Also contains `callEdgeFunctionStreaming`, the streaming helper that
  the plan generator uses.
- `ToolDefinitions.swift` — the static list of 21 tools the coach
  can call: `get_workouts`, `get_training_plan`, `get_training_stats`,
  `get_personal_records`, `get_goals`, `get_athlete_profile`,
  `log_workout`, `log_nutrition`, `get_nutrition`, `create_training_plan`,
  `generate_week_plan`, `save_training_plan`, `save_weekly_plan`,
  `patch_weekly_plan`, `update_plan_progress`, `get_week_review`,
  `get_plan_history`, `start_weekly_review_check_in`,
  `populate_review_field`, `complete_weekly_review`, `app_action`.
  The last is a catch-all for create/update/delete of goals, workouts,
  memory, settings, plan, and tab navigation; the three weekly-review
  tools drive the conversational Sunday check-in flow that produces
  paired review/preview artifacts (see [Weekly check-in, review, and
  preview](#weekly-check-in-review-and-preview)).
- `ToolExecutor.swift` — the big switch that dispatches a tool name +
  input dict to the corresponding DataService method, builds the
  `tool_result` content, and emits typed `ToolEffect`s (e.g.
  `.eventCreated`, `.planCreated`, `.weekUpdated`). Effects flow back
  through `AgentLoop` to `ChatTab`, which applies them to DataService.
- `ToolResult.swift` — defines the `ToolEffect` enum (the set of
  "things an agent turn wants the app to do"). Kept separate so views
  and the loop share a typed vocabulary.
- `SystemPrompts.swift` — the big system prompt assembled from the
  active personality + the app's behavioral rules (how to ask about
  goals, when to use tools, how to handle plan creation, etc.). Also
  contains `buildPlanBuilderPrompt` for the standalone plan-builder
  generator path and `memoryExtractionPrompt` for the post-conversation
  summary job.
- `MemoryExtractor.swift` — a fire-and-forget post-chat job that sends
  the conversation to a separate Claude call asking it to extract
  durable facts about the athlete (benchmarks, injuries, patterns,
  equipment, etc.) and merge them into the existing `CoachingMemory`.

### Utilities

- `AdherenceComputation.swift` — turns a plan + completion data into
  structured per-week and multi-week adherence summaries. Also used by
  the chat agent's `get_week_review` tool and by the generator's
  "recent adherence context" block.
- `DateHelpers.swift`, `FormatHelpers.swift`, `StringHelpers.swift` —
  small formatters (date-long, date-short, distance, pace, duration,
  slug, etc.).

---

## Supabase backend

### Database tables

Under `supabase/migrations/`. 12 migrations as of this writing —
the highest is `012_weekly_artifacts.sql`.

| Table | Purpose |
|---|---|
| `profiles` | Per-user row (display name, units preference). Created on first auth. |
| `events` | Goals/races. Each row is a race card or training goal with date, location, distance, goal time, etc. Also stores AI-generated race conditions and weather forecast as JSONB fields. |
| `cardio_workouts` | Logged cardio sessions — runs, rides, swims, hikes, bricks. Rich fields: duration, distance, HR, power, zones, cadence, route, calories. |
| `strength_sessions` | Logged strength sessions — a `name`, `date`, `duration`, and an `exercises` array of `Exercise { name, exerciseType, sets[], rest, notes }`. |
| `personal_records` | Per-exercise PR record (weight, reps, estimated 1RM, best duration, band level) with a history array. One row per exercise slug per user. |
| `nutrition` | Logged nutrition entries — meal name, calories, macros, time, notes. |
| `bricks` | Brick workouts (multi-sport back-to-back) stored separately. |
| `training_plans` | The athlete's current plan. One-per-user enforced by a unique index. Stores phases array and `weeklyPlans` JSONB dictionary. |
| `plan_history` | Archived plans from previous seasons + completion snapshots. |
| `coaching_memory` | Tiered memory about the athlete — permanent facts, benchmarks, injuries, observations, response profile, conversation summaries. JSONB. |
| `chat_messages` | Rolling message history for the Coach chat tab. `role`, `content`, optional metadata flags. |
| `conversations` | One row per chat thread. Carries `last_message_at` and an optional summary so the agent can reference past conversations across thread boundaries. |
| `settings` | User settings — theme, coach personality, custom prompt, push message. |
| `templates` | Saved strength workout templates. Each is a named list of exercises with pre-filled sets/reps/weights. |
| `custom_exercises` | User-authored exercises that aren't in the built-in catalog. |
| `exercises` | Built-in global exercise catalog — 234 common movements across 7 body parts × 7 equipment categories. Read-only to users, seeded via migration. |
| `daily_training_load` | One row per (user, date) carrying the authoritative CTL/ATL/TSB and a JSONB breakdown of the per-workout TSS sources that produced the day's total. Past rows are immutable; only edits to a workout in the row's date range trigger a forward recompute. |
| `benchmark_history` | Versioned timeline of athlete thresholds (LTHR, FTP, threshold pace, CSS, max HR). TSS for a workout dated D uses the row whose `effective_from <= D` and is the latest such row, so historical workouts get historical thresholds. |
| `weekly_reviews` | The structured Sunday check-in for the week just completed (Mon–Sun). Athlete-authored fields (sleep, energy/motivation/stress ratings, soreness, pain flags, free-text best/worst session + life context + questions) populated incrementally by `populate_review_field`; AI-authored fields (response prose + structured components + detected patterns) attached at completion. Keyed by `(user_id, week_start_date)`. |
| `weekly_previews` | The AI-generated framing for the upcoming week. Carries theme + theme_category + macro_position + computed volume metrics + structured key sessions / watch-outs / tactical notes / life management notes + rendered prose + closing question. `paired_review_id` links back to the review that informed it (nullable for skipped check-ins). |

Every user-owned table has row-level security: `user_id = auth.uid()`.
The exercise catalog is globally readable and only writable by the
service role.

### Edge function (`supabase/functions/chat/index.ts`)

A single Deno function that proxies Anthropic API calls. Lives on
Supabase's managed Deno Deploy infrastructure.

**Responsibilities:**

1. **Auth check.** Pulls the `Authorization` header off the request and
   hits `$SUPABASE_URL/auth/v1/user` to verify the JWT. Direct fetch
   instead of `supabase-js` because the Deno build of `supabase-js`
   loaded via esm.sh doesn't reliably verify ES256-signed tokens that
   projects with asymmetric JWT signing keys now issue.
2. **Request transform.** Takes the iOS-side body (model, system,
   messages, tools, tool_choice, max_tokens, stream) and forwards it
   to `https://api.anthropic.com/v1/messages` with the server-side API
   key.
3. **Non-streaming path.** Calls Anthropic, waits for the JSON
   response, unwraps and returns it. Has a simple 429/529 retry loop
   with exponential backoff (2s → 4s). Used by the agent chat loop,
   race overview, weather impact, and memory extraction.
4. **Streaming path.** When `stream: true` is in the body, sets
   `stream: true` in the Anthropic request and pipes the SSE
   response body straight through to iOS with `text/event-stream`
   headers. No retry on streaming — caller retries a failed stream by
   calling again. Used by `TrainingPlanGenerator`'s skeleton and week
   batch calls.

Deployed via `supabase functions deploy chat --no-verify-jwt`. The
`--no-verify-jwt` flag tells Supabase's gateway not to pre-check the
JWT; we verify it ourselves inside the function (direct fetch approach
mentioned above).

---

## Auth flow

1. Athlete opens the app → `CoachApp.swift` checks the Supabase session
   via `client.auth.session`. If valid, drops into `MainTabView`.
2. If not signed in, shows `SignInView`. Tapping Sign in with Apple
   triggers `ASAuthorizationAppleIDProvider` → Apple returns an identity
   token → `client.auth.signInWithIdToken(credentials: .init(provider:
   .apple, idToken: ...))`.
3. On success, Supabase creates/links a user row and stores a JWT in
   keychain. Subsequent requests automatically carry the token.
4. On sign-out, keychain session is cleared.

The edge function gets the user's JWT on every call and verifies it
server-side. RLS on the tables then scopes data to that user's rows.

---

## Data flow: anatomy of a chat message

When the athlete types a message in the Coach tab, here's what happens:

1. **View** — `ChatTab` captures the text, creates a `ChatMessage(role:
   "user", content: ...)`, appends to `data.messages`, persists to
   Supabase via `addMessage`, and starts a loading state.
2. **Agent loop start** — `runAgentLoop(messages: data.messages, ...)`
   is called. It builds the system prompt from the active personality
   and calls the edge function with tools attached.
3. **Edge function** — verifies JWT, forwards to Anthropic, returns
   the response (non-streaming for the agent loop).
4. **Tool use** — if the response has `stop_reason: "tool_use"`, the
   loop extracts each `tool_use` block, passes name + input to
   `executeTool`, collects the `ToolResult` (a JSON summary string +
   typed effects), and appends the results as a new user message in
   the chain. The loop continues until the model is done (end_turn).
5. **Effect application** — when the loop returns its `AgentResult`,
   `ChatTab` iterates the collected effects and applies each one to
   `DataService` (`addEvent`, `savePlan`, `saveMemory`, etc.). Views
   auto-update because DataService is `@Observable`.
6. **Message persistence** — the final assistant message is appended
   to `data.messages` and saved to Supabase.
7. **Memory extraction** — `MemoryExtractor.extract` fires in a
   detached `Task` with a subset of recent messages. If it finds new
   durable facts (benchmarks, injuries, patterns), it merges them into
   `data.memory` and saves to Supabase. Runs in the background so it
   never blocks the chat UI.

---

## Plan generation

The most complex subsystem. Lives in `TrainingPlanGenerator.swift`.

### The model

- **`TrainingPlan`** has `phases: [TrainingPhase]` and `weeklyPlans:
  [String: WeeklyPlan]` (keyed by week number string).
- **`TrainingPhase`** carries rich periodization context: philosophy,
  volume range, sessions per week, intensity distribution, key workouts,
  strength focus, physiological goals, progression rules, race-specific
  notes. These fields are populated by the skeleton call and never
  regenerated — the season structure is stable.
- **`WeeklyPlan`** has `weekNumber`, `phase`, `focusOfWeek`, and
  `sessions: [DayPlan]`. A stub week has `sessions: []`. The `isStub`
  computed property checks for that.
- **`DayPlan`** has `day`, `isRest`, `sessions: [PrescribedSession]`,
  `restNote`.
- **`PrescribedSession`** has type, label, duration, distance, effort
  category, zone, pace range, priority, purpose, workout instructions,
  personalized notes, fuel prescription, and (for strength)
  `exercises: [PrescribedExercise]`. Plus completion fields
  (completionStatus, actualDuration, actualDistance, skipReason,
  completionNote, etc.) added in the completion-tracking phase.

### Initial creation flow

`TrainingPlanGenerator.generate(...)` runs three stages:

**Stage 1 — Skeleton** (`generateSkeleton`):

- Prompt frames the model as an expert endurance coach designing a
  season plan. Gives it the athlete, the race, the runway, and
  explicit latitude on phase structure ("you decide how many phases,
  how long each phase runs, what they're called").
- Includes runway handling guidance: long (>26 weeks → real base
  building), medium (12-26 weeks → conventional periodization), short
  (<12 weeks → compressed specific prep).
- Asks for JSON with a `phases` array only — no per-week focuses. This
  keeps skeleton output size fixed regardless of plan length: a
  12-week plan and a 78-week plan both produce ~1.5-2k tokens of
  structure.
- Uses `callEdgeFunctionStreaming` with `max_tokens: 40_000` so
  extremely detailed phase content doesn't get truncated.

**Stage 2 — Week 1** (`generateWeekBatch` with `[1]`):

- Compact phase context for just the phase containing week 1,
  including philosophy, volume range, intensity mix, key workouts,
  strength focus, progression rules.
- Per-week brief describing position within the phase ("week 1 of 12
  in Base phase").
- Asks for JSON with `weeks[0]` containing all 7 days, ordered from
  the plan's week-start anchor (Monday through Sunday by default),
  with full session details.
- Streamed, `max_tokens: 10_000`.

**Stage 3 — Stubs:**

- Instantiates `WeeklyPlan` objects for weeks 2..N with `phase` set
  (derived via `plan.phaseNumber(forWeek:)`) and empty `sessions: []`.
- Returned plan has week 1 fully detailed and every other week as a
  stub.

### Lazy per-week generation

`TrainingPlanGenerator.generateWeek(weekNumber:in:event:athleteMemory:)`
fills in a single stub week:

- Reconstructs a `PlanSkeleton` from the stored plan's phases (no
  week-focus data needed — everything derives from phase + position).
- Builds "recent adherence context" by walking the last 3 weeks of
  `plan.weeklyPlans`, counting completed/modified/needsReview vs
  skipped/swapped sessions, and surfacing completion notes. This gets
  injected into the prompt so the model adapts: "progress if they're
  nailing sessions, pull back if they're missing key workouts or
  flagging fatigue."
- Calls `generateWeekBatch([weekNumber], ..., recentAdherenceContext:
  adherence)` which hits Claude with the same per-week prompt used in
  initial creation, just with adherence context included.
- Returns a single `WeeklyPlan` that the caller splices into the plan.

Called from two places:

1. **The coach chat** — via the `generate_week_plan` tool, handled in
   `ToolExecutor.swift`.
2. **The Plan UI** — `DataService.generateWeek(_:)` is a thin wrapper
   invoked from the "Generate this week now" button on stub week cards
   (`WeekCard` in PlanTab, `StubWeekCard` in WeekDetailView), and from
   the background pre-generation pipeline.

### Auto-advance and pre-generation

`DataService.ensurePlanPreGenerated()` runs on app launch (tail of
`loadAll()` in a detached task) and on Plan tab appearance (`.task`
modifier). It:

1. **Advances `currentWeek`** based on calendar math — computes days
   since `startDate` and advances `currentWeek` / `currentPhase` if
   the calendar has moved past the stored value.
2. **Generates the current week synchronously** if it's somehow a
   stub (safety net for an athlete who let a week pass without
   opening the app).
3. **Pre-generates next week** when we're at day 3+ (Thursday) of the
   current Mon-Sun week, matching when a real coach sits down to
   write next week.
4. **Phase-transition lookahead** — if next week begins a new phase,
   also silently pre-generates the week after it.

De-duped via `pregeneratingWeeks: Set<Int>`. The immediately-next
week's pre-generation surfaces in the UI via
`recentlyPregeneratedWeek`, which `PlanTab` reads to render the
`FreshlyGeneratedBanner` ("Your coach wrote week N. Tap to preview").
The banner navigates to `WeekDetailView` on tap and clears the flag.

---

## Training load (CTL / ATL / TSB)

The training-load system is the chronic-frame view of how much
work the athlete is absorbing. CTL ("fitness," 42-day EWMA of TSS),
ATL ("fatigue," 7-day EWMA), and TSB ("form," CTL − ATL) are
computed daily from logged workouts and exposed to the coach prompt
on every chat turn. Built across migrations 010 (data + benchmark
versioning) and 011 (per-session RPE).

### Data layer

Two tables. `daily_training_load` is keyed by `(user_id, date)` and
holds the authoritative CTL/ATL/TSB plus a JSONB `sources` array
naming each contributing workout, the calculation method used, and a
confidence level. Past rows are immutable by default — only edits to
a workout in the row's date range trigger a forward recompute, which
walks the row immediately preceding the trigger date and applies the
EWMAs day-by-day to today.

`benchmark_history` carries a versioned timeline of athlete
thresholds (LTHR, FTP, threshold pace, CSS, max HR). When computing
TSS for a workout dated D, the resolver picks the row whose
`effective_from <= D` and is the latest such row, so historical
workouts get scored against historical thresholds rather than today's
FTP. Rows are append-only.

Swift models in `Models/DailyTrainingLoad.swift` (carries the row
plus a `LoadSource` nested type with method enums covering
power-normalized, power-avg, pace-gap, pace-flat, swim-pace, HR
zones, HR avg, session-RPE, volume-load, effort-category, and a
sport-default fallback) and a `BenchmarkHistoryEntry` co-located
in the same file.

### Compute layer

Three pieces under `Services/` and `Utilities/`:

- **`TSSLadder.swift`** + **`TrainingStressCalculator.swift`** — pure
  computation. Per-workout TSS via the per-sport ladder: try the
  ideal method (power-normalized for cycling, pace-gap for running,
  swim-pace for swimming), fall back through HR-zone, HR-avg, and
  session-RPE / effort-category, finally to a sport-default flat
  rate. Each tier stamps a confidence level so downstream callers
  know how much to trust the number.
- **`BenchmarkResolver.swift`** — wraps the benchmark history with a
  date-aware lookup so the calculator can ask "what was this athlete's
  FTP on 2025-08-15?" and get the right row in O(log n).
- **`TrainingLoadService.swift`** — orchestration. `loadAll`,
  `loadLatest`, and `loadRecent(days:)` are the read paths.
  `recompute(from:cardio:strength:resolver:reason:)` is the
  forward-walk that fires after every workout add/edit/delete and
  stamps a `recompute_reason` ("new_workout", "workout_edited",
  "workout_deleted", "threshold_changed", "backfill") on each
  rewritten row.

`DataService.recomputeTrainingLoad(touchingDate:reason:)` is the
single entry point views and tools call when a workout changes. It
debounces by triggering the recompute via the service then reloading
`trainingLoad` into memory.

### Prompt injection (Phase 4a)

`CoachState.trainingLoad: TrainingLoadSnapshot?` carries the latest
CTL/ATL/TSB plus a 7-day CTL ramp (oldest-vs-newest in an 8-row
window) into the per-turn dynamic prompt block. `AgentLoop`
fetches the snapshot via `TrainingLoadService.loadRecent(days: 8)`
on every chat turn; failures are swallowed so a transient Supabase
hiccup never blocks chat. The block renders as a single compact
line: `Training load (as of YYYY-MM-DD): CTL X · ATL Y · TSB Z · 7d
CTL Δ +A`.

Section 7 of the prompt teaches the coach how to interpret the
numbers — TSB ranges, CTL ramp guidance — as guides not rules, so
the agent reasons about the load context without reciting numbers
back at the athlete. The companion `recovery_picture` narrative is
the acute overlay (see [Recovery picture](#recovery-picture-acute-state-narrative)).

### UI

`AnalyticsTab.swift` renders the PMC chart (CTL/ATL/TSB curves with
phase boundaries) plus weekly volume by sport. The Today tab does
not surface load directly anymore — the readiness chip was removed
in favor of a "calibrating" note on Stats while the EWMAs warm up.

---

## Recovery picture (acute-state narrative)

The recovery picture is the *acute*-frame counterpart to training
load — an LLM-built 2–3 sentence paragraph describing what the
athlete's body did last night, fed into the coach prompt every turn.
Phase 4b authoring; companion to Section 7's already-written
recovery-narrative content.

### Data layer

`Models/RecoverySnapshot.swift` carries nine HealthKit metrics, each
paired with a 30-day rolling baseline where applicable: HRV (SDNN),
resting heart rate, respiratory rate, wrist-temperature delta,
sleep summary (asleep / inBed / deep / REM / awake hours via a
nested `SleepSummary`), steps yesterday, active energy yesterday,
VO2 max, body mass. Any field can be nil; the snapshot has a
`hasAnySignal` flag so the generator can skip the LLM call when
HealthKit returned nothing.

No DB persistence — HealthKit is the source of truth and the
snapshot is computed fresh per-day. The narrative produced from it
is held in memory only (per-day cache; see below).

### Service layer

`HealthKitService.fetchRecoverySnapshot()` runs nine metric fetches
in parallel via `async let`. The auth request was extended in Phase
4b to cover HRV / RHR / respiratory rate / sleep stages / wrist
sleeping temperature / VO2 max / body mass alongside the existing
workout types. Wrist temperature is exposed by Apple as the absolute
value; the service computes a signed delta against a 30-day mean to
match the Health-app-style "warmer than usual" framing.

Baselines exclude today's value so the comparison isn't tautological.
"Latest" means the most recent overnight reading (HRV / RHR / RR are
typically written by Apple Watch around wake-up); slow-moving
metrics (VO2 max, body mass) just take the most-recent sample
within a 6-month window.

### Generation layer

`AI/RecoveryPictureGenerator.swift` is a single Haiku 4.5 LLM call
via the `chat` edge function. The system prompt frames it as a
coach-to-coach briefing — the head coach (the main agent) reads it
and decides what to say to the athlete in voice, so the briefing is
plain and analytical, not personality-flavored. Output is 2–3
sentences. The user prompt carries the snapshot fields formatted as
deltas (`HRV: 41ms (baseline 52ms, -21%)`) plus the chronic-load
context.

System-prompt rules: reason about the data, don't recite numbers;
frame deltas, not absolute values; weave training-load context
(low TSB + rough recovery means something different than fresh TSB
+ rough recovery); call out illness possibilities when wrist temp
is elevated alongside rising RHR or respiratory rate; output
"limited data" rather than fabricating.

### Cache + injection

`AgentLoop.swift` holds a `recoveryPictureCache: (date: String,
picture: String)?` keyed by `yyyy-MM-dd`. The first chat turn of a
day fetches the snapshot, runs the generator, and stamps the cache;
subsequent turns the same day reuse the cached narrative. Picture
recovery is invariant across the day (overnight metrics don't
change), so one Haiku call per day is enough.

The narrative lands in `CoachState.recoveryPicture` and renders
inside the `[COACH STATE]` block as:

```
Recovery picture:
<2-3 sentence narrative>
```

### UI

None — the recovery picture is athlete-invisible. It exists only as
coach-prompt context. The athlete sees the *response* the coach
gives based on it, not the picture itself. Section 7's
"Read the narrative. Don't recompute it" instruction is what keeps
the agent from recreating it as numerical recitation in chat.

---

## Conversations and thread-to-thread continuity

The Coach chat is organized into discrete conversations rather than
one infinite thread. Each conversation auto-archives after 2 hours
of inactivity; on archive a 1–2 sentence summary is generated so the
next conversation's prompt has continuity context without re-sending
the full transcript. Migration 009 added the system.

### Data layer

`Models/Conversation.swift` carries `id`, `started_at`,
`last_message_at`, optional `summary`, and `is_archived`. Plus
computed `hoursSinceLastMessage` and `isStale` (`>= 2`).

The `conversations` table holds one row per thread. `chat_messages`
gained a `conversation_id` foreign key so messages scope to a thread.
`DataService` exposes `currentConversation: Conversation?` (the
non-archived one — at most one at a time) and `archivedConversations:
[Conversation]` (all the rest, sorted newest-first).

### Lifecycle

1. Athlete sends the first message → `ensureActiveConversation`
   creates a new row if `currentConversation == nil`.
2. Each subsequent message updates `last_message_at` so staleness
   resets per turn.
3. `loadAll` on launch checks `currentConversation.isStale` — if
   the previous active thread crossed the 2-hour mark while the
   app was closed, it gets archived now and a fresh one starts on
   the next user message.
4. Archival fires `generateConversationSummary` — a small Claude
   call that returns 1–2 sentences capturing what the thread
   resolved or where it left off. Summary is written back to the
   row.

### Thread-to-thread continuity

When the agent loop runs (`runAgentLoop` in `AgentLoop.swift`), it
pulls the top 3 archived summaries (`archivedConversations.prefix(3)
.compactMap(\.summary)`) and injects them into `CoachState
.recentConversationSummaries`. The dynamic prompt block then renders:

```
Recent conversations (for thread-to-thread continuity):
- 1. <summary 1>
- 2. <summary 2>
- 3. <summary 3>
```

This sits in the dynamic block (not the cached static block) so the
prompt cache stays valid as summaries update.

### UI

`ChatTab` / `CoachTab` show only the current conversation's messages.
A history surface (search and browse archived conversations) exists
but is a peripheral feature; most of the value is the agent reading
the summaries on its own to maintain continuity.

---

## Weekly check-in, review, and preview

The weekly ritual ships in five layers — data, tools, generation,
trigger, UI — that map cleanly to the existing patterns elsewhere in
the codebase. Specced in [issue #70](https://github.com/evansjesse012/coach/issues/70);
implementation plan in [`Prompts/W1_PLAN.md`](./ios/Coach/Coach/Prompts/W1_PLAN.md);
the user-facing walkthrough is in [FEATURES.md](./FEATURES.md#weekly-check-in-review-and-preview).

### Data layer

Two tables (`weekly_reviews`, `weekly_previews`) plus matching Swift
models in `Models/WeeklyReview.swift` and `Models/WeeklyPreview.swift`.
The preview's `paired_review_id` is nullable + `ON DELETE SET NULL`
so a deleted review leaves the preview standing alone rather than
cascading away with it.

`WeeklyArtifactsService.swift` is the read/write layer — mirrors the
`TrainingLoadService` pattern. Provides `loadReviews` / `loadPreviews`
for `DataService.loadAll` to parallel-fetch on launch,
`createInProgressReview` (idempotent — resumes an existing row rather
than colliding with the unique constraint), `updateReviewFields` for
the per-turn shallow merge during the conversation,
`markReviewComplete` for finalization, `attachAIResponse` /
`savePreview` for the generators' writes, plus the `shouldPromptCheckIn`
trigger logic + `markPromptedForCheckIn` debounce stamp.

`WeekBoundary.swift` (under `Utilities/`) derives week-start/week-end
strings in `Calendar.current` (device-local), anchored on the athlete's
chosen week-start day (`UserSettings.weekStartDay`, Monday by default —
see `Utilities/Weekday.swift`). All weekly artifacts are keyed by
week-start strings; mismatched timezones across devices are accepted
as a single-user-app simplification. Training plans freeze their own
anchor at creation (`TrainingPlan.weekStartDay`) — preference changes
apply to the next plan, never retroactively to a live plan's
positional day grid.

### Tool layer

Three tools in `ToolDefinitions.swift`, all dispatched in
`ToolExecutor.swift`:

- **`start_weekly_review_check_in`** — opens (or resumes) a review
  row for the week being wrapped up. Defaults `week_start_date` via
  `WeekBoundary.reviewWeekStartString` (last day of the athlete's
  week → this week's start; any other day → prior week's start).
  Returns the review id + a compact
  adherence summary so the agent can frame the conversation around
  what actually happened that week.
- **`populate_review_field`** — shallow-merges any subset of
  structured fields onto the in-progress row. Designed for
  per-athlete-answer calls rather than batched-at-end calls; the
  per-turn rhythm is the difference between a conversation and a
  form. The Section 11 `WEEKLY CHECK-IN` sub-section governs the
  cadence.
- **`complete_weekly_review`** — stamps `completed_at`, auto-computes
  `adherence_pct` from the matching plan-week (reuses
  `computeWeekAdherence`), then runs both AI generators in parallel
  via `async let` (~6–10s wall time) and persists the artifacts.

Each tool emits a typed `ToolEffect` (`.reviewUpdated` /
`.previewSaved`) so `DataService` can upsert the artifact in-memory
without a full reload.

### Generation layer

Two `@MainActor enum` generators in `AI/`, both following the
`RecoveryPictureGenerator` pattern (single Sonnet 4.6 call via the
`chat` edge function, structured JSON output parsed into Swift):

- **`WeeklyReviewResponseGenerator`** — takes the completed review +
  plan + memory + recent sessions. Produces the 6-component response
  per issue #70: life acknowledgment, week assessment, session
  feedback, pattern callout, questions answered, bridge to next week.
  100–250 word target.
- **`WeeklyPreviewGenerator`** + **`WeeklyPreviewMetrics`** — takes
  the just-completed review + upcoming week's plan + plan context +
  memory + training-load snapshot + computed volume metrics. Produces
  theme, theme_category, macro position, key sessions, watch-outs,
  tactical notes, life management notes, rendered prose, closing
  question. 300–500 word target. Volume metrics are computed
  deterministically in Swift (total hours, distance, quality vs easy
  session counts, delta from previous week) and passed verbatim into
  the prompt — the generator only handles what actually requires
  judgment.

Both generators ship with tolerant JSON parsing (strip ```json
fences, trim leading preambles, take first `{` to last `}` as the
JSON body) since Sonnet occasionally adds preambles despite "output
JSON only" instructions.

Pattern detection (the 6 multi-week patterns from issue #70) is
deferred to W1 Phase 3; PR 1.3 ships an empty `patterns_detected`
array.

### Trigger

`WeeklyArtifactsService.shouldPromptCheckIn(now:reviews:anchor:)`
returns the week-start string of the review-week if a prompt should
fire, otherwise nil. Trigger window follows the athlete's week
anchor: last day of their week after 16:00 OR first day of the new
week before 12:00 local time (Sunday evening / Monday morning on the
default Monday anchor). Skips when a completed review already exists for
the corresponding week, and debounces within the same review-window
via `UserDefaults` so repeated app-opens don't repost the opener.

`MainTabView` wires it on `.onAppear` (cold launch case) and on
`.onChange(scenePhase == .active)` (foreground while running).
Both routes call `maybePromptWeeklyCheckIn`, which hits
`shouldPromptCheckIn`, then on a non-nil result calls
`DataService.postCoachOpener` to drop the wrap-up framing message
into the chat thread as a coach-initiated assistant message
(distinct from `sendUserMessage`, which posts a user turn and runs
the agent loop). The athlete's reply when it comes kicks off the
agent loop normally; the agent has Section 11's WEEKLY CHECK-IN
guidance loaded and calls `start_weekly_review_check_in` from there.

Server-cron scheduling (the W6 path that prompts even without an
app-open) is deferred until issue #67 (platform-agnostic agent
refactor) lands.

### UI

A single reusable `Views/Shared/WeeklyArtifactView.swift` renders
either a review or a preview as a card under shared chrome (rounded
border, surface1 background). The view dispatches on a
`Source = .review(WeeklyReview) | .preview(WeeklyPreview)` enum.

Three surfaces consume it:

1. **Coach bar** (existing, no W1 changes) — the chat reply
   summarizing the wrap-up auto-expands into the 300pt accent card
   via the unread / `coachBarExpanded` flow in `CoachBar.swift`.
2. **Today tab** — `HomeTab.weeklyPreviewThemeLine` is a
   single-line, accent-tinted callout below the week section header.
   Renders only when `data.activeWeekPreview` is non-nil (computed
   property matching the preview row whose `weekStartDate` equals
   today's Monday). Tap opens a `WeeklyArtifactSheet` modal over
   the full preview.
3. **WeekDetailView** — `weeklyArtifactsBlock` embeds the current
   week's preview (if any) and the prior week's review (if completed)
   as cards at the top of any week's plan view.

Engagement tracking (`read_at` on first view, `reread_count`
incremented thereafter) lives in
`WeeklyArtifactsService.markPreviewOpened`, called from
`WeeklyArtifactSheet.task`. Best-effort: failures are swallowed,
the in-memory `read_at` and `reread_count` are used to decide
which write to send, so concurrent devices could clobber each
other but it's a single-user-app simplification.

### Known soft spots

[Issue #80](https://github.com/evansjesse012/coach/issues/80)
tracks three predictable failure modes the build can't catch —
verify on first end-to-end test:

1. **Tool-call rhythm** — whether the LLM batches `populate_review_field`
   at the end vs calls it per-turn
2. **Generation latency** — whether 6–10s of "..." between hitting send
   and the chat reply landing feels acceptable
3. **Theme line refresh** — whether the Today theme line updates
   immediately after a check-in completes, or requires kill-and-relaunch
   (SwiftUI @Observable edge case)

---

## HealthKit integration

`HealthKitService` is an `actor` under `Services/`.

**Flow:**

1. First use triggers the HealthKit authorization sheet for workouts,
   HR, route, and distance.
2. `DataService.syncHealthKitWorkouts(days:)` fetches workouts from
   HealthKit for the last N days, filters to ones we haven't already
   imported, and processes each via `processIncomingHealthKitWorkout`.
3. **Workout matching** — `WorkoutMatcher` (pure logic, no side
   effects) takes a `CardioWorkout` and a list of `MatchCandidate`s
   (unresolved prescribed sessions for today, yesterday-after-8pm,
   and tomorrow-before-6am). Scores each candidate on sport, duration
   fit, time-of-day proximity, and HR-zone alignment. Maps the raw
   score to a confidence level: high (≥70), medium (40-69), low
   (1-39), or none.
4. **Auto-pairing** — high confidence matches are paired silently
   (completion status set to `.completed`). Medium confidence is
   paired but flagged `completionNeedsReview: true`, which surfaces
   in the UI as a review prompt. Low and none go into
   `pendingHealthKitImports` — shown on the Home tab as "New workout
   detected" cards for manual handling.

---

## Deployment

**Database:**
```bash
supabase db push
```
Applies any pending migrations in `supabase/migrations/`.

**Edge function:**
```bash
supabase functions deploy chat --no-verify-jwt
```

**iOS:** Standard Xcode build + archive + TestFlight / App Store
through Xcode or CLI `xcodebuild`.

**Environment:**
- `ANTHROPIC_API_KEY` — set via `supabase secrets set` so the edge
  function can call Anthropic.
- Supabase URL and anon key are hardcoded in `SupabaseService.swift`
  (they're public identifiers — RLS is what protects data).
