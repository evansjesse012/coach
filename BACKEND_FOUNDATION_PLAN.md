# Backend Foundation & Prescription Normalization — Plan & Design

Status: **Revised / Ready to build** · Owner: jesse@maverickx.com
Original investigation branch: `claude/problem-investigation-8mbqi`
Revision branch: `claude/plan-review-assessment-b7Fd9`

This document consolidates the design decisions from our investigation into a
single buildable plan. It covers four intertwined pieces of one chunk of work:

1. **Backend as foundation** — put a real API in front of Postgres so the
   database stops being the client's public interface.
2. **Prescription normalization** — move the live training plan out of a single
   JSONB blob into queryable rows (the hybrid: structured columns + JSON detail).
3. **Adherence read-model** — compute adherence once, server-side, and persist
   it structured instead of re-deriving it on the device every time.
4. **Week-start snapshots** — measure adherence against *what was committed at
   the start of the week*, not the edited live plan.

> **Revision notes (this pass).** Verified every claim below against the actual
> code and migrations. Changes from the proposed version: (a) locked the tech
> stack — TypeScript + Hono + Drizzle on Railway, pg-boss for jobs (§3.1);
> (b) corrected FK types — the exercise catalog PK is `slug TEXT` and
> `training_plans.id` is `TEXT`, not UUID (§4); (c) added the jobs/scheduler
> design the week-start/week-close triggers actually require (§4.5); (d) made
> the auth + RLS model explicit now that a service-role backend becomes the
> writer (§3.2); (e) named the read-path strategy, which Phase 1 leaves on
> PostgREST (§3.3); (f) noted that the **agent loop**, not just the tools, is
> client-side today and is the real orchestration to relocate (§1, §5).

---

## 1. Why now — what the code actually does today

Verified against the codebase (file:line where it lives):

| Concern | Where it lives today | Problem |
|---|---|---|
| The training plan | One JSONB blob: `training_plans.weekly_plans` (`001_initial_schema.sql:173`), keyed by week-number string → `WeeklyPlan{ sessions:[7 DayPlan], phase, focusOfWeek }` (`TrainingPlan.swift:464`) | Not queryable; every edit rewrites the blob in place |
| Plan edits | `patch_weekly_plan` mutates the blob (`ToolExecutor.swift:428`); `plan_edits` logs ops (`013`) | Mutation logic runs on the **client** |
| Prescription identity | `PrescribedSession.id` = computed `"\(type)-\(label)"` (`TrainingPlan.swift:235`) | **Not stable** across edits; collides on duplicates |
| Prescription vs. completion | One `PrescribedSession` struct holds the prescription *and* the actuals — `completionStatus`, `actualDuration`, `rpe`, `fatigue`, … (`TrainingPlan.swift:234-306`) | Two different lifecycles conflated in one record |
| Adherence | `computeWeekAdherence` (`AdherenceComputation.swift:104-202`) runs **on the device** against the **live blob**; only a single scalar `weekly_reviews.adherence_pct` is persisted (`012:45`) | History is recomputed against the *current, edited* plan — not honest; the rich `DayReview` breakdown is thrown away |
| The agent loop | `AgentLoop.swift:429` calls the proxy for a model turn, `ToolExecutor` runs the tools on-device, `DataService.applyAgentEffects` writes to Postgres, then loops | The multi-step coaching orchestration lives **on the device** |
| "Backend" | `supabase/functions/chat/index.ts` — a 149-line Anthropic proxy | It only forwards completions; all real logic executes on the client, writing directly to Postgres under RLS via PostgREST |
| Anthropic key | Lives in the proxy edge function | Fine where it is — see §6 |

The throughline: **the client is the application server.** The database schema is
the public API (iOS hits PostgREST directly — `DataService.swift` does
`.from("training_plans").upsert(...)`), business rules live in shipped app code,
the agent loop orchestrates on-device, and analytics are re-derived on the
device from a mutable blob. Normalization, honest adherence, and proactive
coaching are all blocked by this until there's a server seam.

---

## 2. Decisions locked

From our discussion, these are settled and drive the plan:

- **This is the next chunk of work.** ✔ Execute all phases.
- **Adherence baseline = week-start committed.** Measure against the plan as it
  stood when the week began (after pre-week edits, before in-week reality).
- **Exercise prescription depth = link by id + sets/reps as JSON.** No
  row-per-set; link strength prescriptions to the exercise catalog by stable id,
  carry prescribed sets/reps in JSON.
- **Past plans: accept degraded history.** Honest "vs. originally prescribed"
  adherence starts at cutover. No backfill of old plans.
- **Shipped clients: clean cutover.** The new app version calls the API; the old
  direct-to-Postgres write path is dropped, not carried forward.
- **Hybrid storage, not "abandon JSON."** Rows for what we query, edit, and
  aggregate; JSON for freeform detail and immutable snapshots.
- **Stack (new, this revision): TypeScript + Hono + Drizzle, deployed on
  Railway, jobs via pg-boss.** Rationale in §3.1.

---

## 3. Target architecture

```
            BEFORE                                  AFTER
  ┌─────────────┐                       ┌─────────────┐
  │  iOS app    │  supabase-js          │  iOS app    │  intent calls
  │ (all logic) │──"UPDATE workouts"──▶ │ (thin)      │──"POST /move-workout"─┐
  └─────────────┘        │              └─────────────┘                       │
                         ▼                                                     ▼
                   ┌──────────┐                                        ┌──────────────┐
                   │ Postgres │                                        │  Backend API │
                   │ (public) │                                        │ (rules,tx,   │
                   └──────────┘                                        │  snapshots,  │
                                                                       │  adherence,  │
                                                                       │  agent loop) │
                                                                       └──────┬───────┘
                                                                              ▼
                                                                       ┌──────────┐
                                                                       │ Postgres │
                                                                       │(private) │
                                                                       └──────────┘
```

- **One backend service**, not several. Mutation/coaching (request/response) and
  background/proactive work (deferred) share the same codebase; the only thing
  added for background work is a **trigger** (queue/scheduler) that calls back
  into the same code — not a second backend.
- **Postgres becomes a private implementation detail** *for the write path*. Its
  schema can change freely as long as the API contract holds. RLS stays as
  defense-in-depth (see §3.2). The read path migrates later (§3.3).

### 3.1 Stack — locked, and why (optimized for a solo non-expert that must scale)

| Layer | Choice | Why this, for you |
|---|---|---|
| Language | **TypeScript** | The edge proxy and all your tool/agent code are already TS-shaped (Deno). One backend language = half the things to learn. The iOS side stays Swift; nothing changes there. |
| Web framework | **Hono** | Tiny, modern, first-class TypeScript, great docs. Runs on Node *and* edge — so the existing `chat` proxy could fold into the same codebase later with no rewrite. Simpler surface than Express for a beginner. |
| DB access | **Drizzle ORM** (typed queries) | Type-safe SQL: the compiler catches a misspelled column or wrong type *before* it ships — exactly the guardrail that helps when you're not a full-time coder. We keep the **Supabase SQL migrations in `supabase/migrations/` as the single source of truth** for schema; Drizzle is used for queries only (no competing migration tool). |
| Jobs / scheduling | **pg-boss** | A durable job queue that lives *inside the Postgres you already have* — zero new infrastructure, no extra account, no extra bill. Powers week-start snapshots, week-close adherence, and future proactive coaching. We can graduate to Inngest later if we want hosted step-functions; pg-boss is the right start. |
| Hosting | **Railway** | The most beginner-friendly path: connect the GitHub repo, it builds and deploys on every push, gives you logs and a URL, and scales by bumping a slider. Handles thousands of users comfortably. (Fly.io is the alternative if we later want multi-region; Railway first.) |
| Auth | **Supabase JWT verification** | Reuse the exact token the app already sends; the backend verifies it and trusts `auth.uid()`. No new login system. |

This stack scales to thousands of users without re-architecting: Hono on Node
is fast, Drizzle is thin, pg-boss rides your existing Postgres, and Railway
scales horizontally. The only thing we'd add at much larger scale is a managed
queue or a read replica — neither is needed now, and neither forces a rewrite.

### 3.2 Auth & RLS once the backend is the writer

- The iOS app already sends a Supabase JWT (`AgentLoop.swift` invokes
  `functions/v1/chat` with the user's session). The backend **verifies that JWT**
  (same secret/JWKS the edge function uses) and derives `user_id` from it — the
  client never gets to assert who it is.
- The backend connects to Postgres with a **service-role / direct connection**,
  which **bypasses RLS**. That is intentional: the backend is now the trusted
  writer and enforces ownership in code (`where user_id = <jwt subject>`).
- **RLS stays enabled** as defense-in-depth for the read path (which is still
  the anon-key PostgREST client on the device) and as a backstop. We do *not*
  drop the policies. The contract: writes go through the API; the anon key can
  no longer write the normalized tables (policy them read-only to the client).

### 3.3 The read path (explicit — Phase 1 does not move it)

Today the device loads everything via PostgREST and computes in memory. We are
**not** rewriting all reads in this chunk. Strategy:

- **Phase 1–3:** reads stay on PostgREST. After a server-side write, the API
  returns the updated resource so the client can refresh its in-memory copy
  immediately (no stale UI). Optionally enable **Supabase Realtime** on the
  normalized tables so background/proactive server writes push to the device.
- **Later (out of this chunk):** migrate hot reads (today screen, plan, history)
  to API endpoints so Postgres is fully private. Deferred deliberately.
- **Hosting note:** the existing Anthropic proxy can stay an edge function
  (see §6); the new container is for the agent loop + mutation/adherence logic.

---

## 4. Data model — normalization target

Replace the per-session blobs with rows. **Split prescription from completion.**
(FK types corrected this revision: `training_plans.id` is **TEXT**, and the
exercise catalog PK is **`exercises.slug TEXT`** — `001:161`, `007:5`.)

### 4.1 `prescribed_workouts` (the live, editable plan, as rows)

```
prescribed_workouts
├─ id              UUID PK         -- STABLE identity (fixes the type-label id)
├─ user_id         UUID            -- = auth.uid() of owner
├─ plan_id         TEXT  FK → training_plans(id)      -- TEXT, not UUID
├─ week_number     INT
├─ day             SMALLINT        -- 0..6
├─ position        SMALLINT        -- order within the day
├─ type            TEXT            -- sport | "strength" | "brick"
├─ label           TEXT
├─ duration        INT
├─ distance        NUMERIC
├─ zone, pace, effort_category, priority, purpose   -- queried/edited fields
├─ detail          JSONB           -- freeform: workout text, fuel, legs, notes,
│                                  --   warning, target_intensity, …
├─ created_at      TIMESTAMPTZ
└─ deleted_at      TIMESTAMPTZ     -- SOFT DELETE (tombstone), never hard-delete
```

Rule of thumb already agreed: **rows for what we query/edit/aggregate; JSON for
what we only read whole.** Rest days become a day-level property, not a fake row
(carried on a small `prescribed_days` row with `is_rest`/`rest_note` per
(plan, week, day) — finalized at build time; leaning day-level row).

### 4.2 `prescribed_exercises` (strength, link-by-id)

```
prescribed_exercises
├─ id                    UUID PK
├─ prescribed_workout_id UUID FK → prescribed_workouts
├─ catalog_exercise_slug TEXT FK → exercises(slug)    -- stable link (007/008)
├─ position              SMALLINT
└─ prescription          JSONB    -- prescribed sets/reps/load (per the decision)
```

> Corrected: links to `exercises.slug` (TEXT), not a UUID `catalog_exercise_id`.
> Custom exercises also carry a `slug` (`007:25`), so the same link works for them.

### 4.3 `workout_completions` (the completion ledger — separate lifecycle)

The actuals currently crammed into `PrescribedSession` move here, keyed to the
stable prescription id:

```
workout_completions
├─ id                    UUID PK
├─ user_id               UUID
├─ prescribed_workout_id UUID FK → prescribed_workouts (nullable: unplanned)
├─ status                TEXT     -- completed | shortened | missed | substituted | swapped
├─ actual_duration, actual_distance, actual_sport
├─ rpe, fatigue, athlete_note, completion_note
├─ linked_workout_id     -- HealthKit/Cardio link
└─ resolved_at, needs_review
```

Soft-delete on the prescription side means a moved/deleted workout never dangles
its completion or corrupts past adherence.

### 4.4 Snapshots & adherence (read-models)

- **`weekly_plan_snapshots`** already exists (`013`), but its CHECK constraint
  only allows `source IN ('create_plan','generate_week','regenerate_week')`
  (`013:42`) — it fires at *generation* time only. **Migration adds a
  `'week_start'` source** to the CHECK and the job below freezes the week when it
  begins — this snapshot is the artifact week-start-committed adherence measures
  against.
- **`week_adherence`** (new) — computed once, server-side, at week close:

```
week_adherence
├─ user_id, plan_id (TEXT), week_number, phase
├─ prescribed, completed, shortened, missed, substituted   -- the breakdown,
│                                                          --   now persisted
├─ by_sport       JSONB
├─ adherence_pct  NUMERIC
├─ snapshot_id    UUID FK → weekly_plan_snapshots   -- provenance: measured-against
└─ computed_at
```

Historical adherence = `SELECT … FROM week_adherence` (indexed, exact, chartable).
Snapshots are the immutable evidence behind each number. `weekly_reviews.adherence_pct`
becomes a denormalized convenience copy (or a view) rather than the source of truth.

### 4.5 How week-start / week-close actually fire (the missing piece)

Postgres has no built-in clock, and today `adherence_pct` is only computed when
the user *finishes a weekly review*. For an honest week-start baseline and a
guaranteed week-close compute we need a scheduler:

- **pg-boss** runs scheduled jobs inside Postgres. Two recurring jobs:
  - `freeze-week-start` — at each user's week boundary, write a `week_start`
    snapshot of the then-current rows (idempotent: skip if one exists).
  - `close-week-adherence` — at week end, compute adherence of completions vs.
    the `week_start` snapshot and upsert `week_adherence`.
- Week boundaries are per-user (the app already has `WeekBoundary.swift`); the
  job enumerates users due at each run (e.g. hourly tick) rather than assuming a
  global Monday.
- The weekly-review flow stays, but now *reads* the persisted `week_adherence`
  instead of recomputing on device.

---

## 5. Phased delivery

Ordering matters: **build the seam before changing the storage**, so the schema
migration happens once, behind a stable contract.

- **Phase 0 — Backend skeleton + setup (infra you provision, see §9).**
  Create the `backend/` service (Hono + Drizzle + pg-boss), health check, JWT
  verification middleware, Postgres connection via the Supabase connection
  string, deploy to Railway. Nothing functional yet — proves the pipe end to end.

- **Phase 1 — Backend mutation API (still on the blob).**
  Port the existing tools — `patch_weekly_plan`, `save_weekly_plan`,
  `log_workout`, `complete_weekly_review`, `generate_week_plan` — from
  `ToolExecutor.swift` to intent-named server endpoints that wrap the *current*
  blob ops. **This is a reimplementation in TypeScript, not a move** — the patch
  op-semantics (move/update/set_rest/add/delete) get rebuilt and unit-tested
  server-side. Client stops writing the blob directly; it calls the API and
  refreshes from the returned resource. **No schema change yet.** Existing reads
  keep working (§3.3). The agent loop can stay on-device for now or move next.

- **Phase 2 — Normalize prescriptions behind the API.**
  Introduce `prescribed_workouts` / `prescribed_exercises` / `workout_completions`.
  Write a **blob → rows data migration** (parse `weekly_plans`, mint stable
  UUIDs, split actuals into `workout_completions`). Rewrite the API's edit ops to
  operate on rows (stable UUIDs, soft-delete). Clients are unaffected — they
  still call `/move-workout`. Retire the blob as the working copy.

- **Phase 3 — Week-start snapshots + adherence read-model.**
  Add the `week_start` snapshot source + the pg-boss jobs (§4.5). Move
  `computeWeekAdherence` server-side, compute at week close against the
  week-start snapshot, persist to `week_adherence`. Repoint history/patterns
  reads at the table.

- **Phase 4 — relocate the agent loop (same chunk, can trail).**
  Move the `AgentLoop` orchestration off the device into the container so
  multi-step coaching (fetch context → model → tool → model → write, retried)
  runs server-side. Naturally enabled once the tools are server endpoints (P1).

Each phase ships independently and leaves the app working.

---

## 6. Where the Anthropic API lives

Unchanged by default. The Anthropic call is just outbound HTTPS and works fine
from the existing edge-function proxy; prompt caching etc. are unaffected. The
constraint is never the call — it's the **orchestration around it**. A single
completion fits inside edge limits; long multi-step coaching (fetch context →
call → tool → call → write, several rounds, survives retries) does not. So keep
the proxy where it is, and graduate the heavy multi-turn coaching path
(`AgentLoop`) to the container API (Phase 4). Because both are TypeScript/Hono,
the proxy can later fold into the same codebase with no rewrite.

---

## 7. Non-goals / explicitly deferred

- Re-platforming off Postgres — **no.** Keep Supabase Postgres as system of record.
- Microservices — **no.** One service + Postgres + a job runner (pg-boss).
- Row-per-set exercise modeling — deferred; link-by-id + JSON is the decision.
- Backfilling honest history for past plans — out of scope by decision.
- Carrying the old direct-write client path — dropped at cutover.
- Migrating *reads* off PostgREST — deferred to a later chunk (§3.3).

---

## 8. Open items

None blocking. Resolved during design:

- "Originally prescribed" → **week-start committed.**
- Exercise depth → **link by id (slug).**
- Past-plan history → **accept degraded.**
- Shipped clients → **clean cutover.**
- Edge vs. container for the API → **container (Railway)** for the new service;
  proxy stays edge.
- Stack → **TypeScript + Hono + Drizzle + pg-boss.**

---

## 9. What you need to provision (so I can build against real infra)

I can write all the code and migrations in this repo now. To deploy and wire it
up, you'll create a few accounts/values and paste them back to me — step-by-step
instructions will accompany each:

1. **Railway account** (railway.app) — sign in with GitHub, create one project.
   This hosts the `backend/` service; deploys on every push to the repo.
2. **Supabase connection string + service-role key** — from your existing
   Supabase project (Settings → Database for the pooled connection string;
   Settings → API for the `service_role` key). These let the backend talk to
   Postgres as the trusted writer. *(Secrets — paste into Railway's env vars, not
   into the repo.)*
3. **Supabase JWT secret** — Settings → API → JWT secret, so the backend can
   verify the app's tokens.
4. **Anthropic API key** — only needed in the backend once we relocate the agent
   loop (Phase 4); the edge proxy already has its own. Reuse the same key.

Nothing here changes the iOS bundle, your App Store status, or the existing edge
proxy. The new service runs alongside what you have until the client is cut over.
