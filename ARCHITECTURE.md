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
- `ToolDefinitions.swift` — the static list of tools the coach can
  call: `get_workouts`, `get_training_plan`, `get_training_stats`,
  `get_personal_records`, `get_goals`, `get_athlete_profile`,
  `log_workout`, `log_nutrition`, `get_nutrition`, `create_training_plan`,
  `generate_week_plan`, `save_weekly_plan`, `patch_weekly_plan`,
  `update_plan_progress`, `get_week_review`, `get_plan_history`,
  `app_action` (a catch-all for create/update/delete of goals, workouts,
  memory, settings, plan, and tab navigation).
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

Under `supabase/migrations/`. There are 8 migrations as of this writing.

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
| `settings` | User settings — theme, coach personality, custom prompt, push message. |
| `templates` | Saved strength workout templates. Each is a named list of exercises with pre-filled sets/reps/weights. |
| `custom_exercises` | User-authored exercises that aren't in the built-in catalog. |
| `exercises` | Built-in global exercise catalog — 234 common movements across 7 body parts × 7 equipment categories. Read-only to users, seeded via migration. |

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
- Asks for JSON with `weeks[0]` containing all 7 days (Monday through
  Sunday) with full session details.
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
