# Backend Foundation & Prescription Normalization — Plan & Design

Status: Proposed · Owner: jesse@maverickx.com · Branch: `claude/problem-investigation-8mbqi`

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

---

## 1. Why now — what the code actually does today

Verified against the codebase (not from memory):

| Concern | Where it lives today | Problem |
|---|---|---|
| The training plan | One JSONB blob: `training_plans.weekly_plans`, keyed by week-number string → `WeeklyPlan{ sessions:[7 DayPlan], phase, focusOfWeek }` | Not queryable; every edit rewrites the blob in place |
| Plan edits | `patch_weekly_plan` mutates the blob; `plan_edits` logs ops (migration 013) | Mutation logic runs on the **client** (`ToolExecutor.swift`) |
| Prescription identity | `PrescribedSession.id` = computed `"\(type)-\(label)"` | **Not stable** across edits; collides on duplicates |
| Prescription vs. completion | Same `PrescribedSession` struct holds both the prescription *and* the actuals (`completionStatus`, `actualDuration`, `rpe`, `fatigue`, …) | Two different lifecycles conflated in one record |
| Adherence | `computeWeekAdherence` in `AdherenceComputation.swift` runs **on the device**, against the **live blob**; only a single scalar `weekly_reviews.adherence_pct` is persisted | History is recomputed against the *current, edited* plan — not honest; the rich breakdown is thrown away |
| "Backend" | `supabase/functions/chat/index.ts` — a 148-line Anthropic proxy | All real logic (tools) executes on the client, writing directly to Postgres under RLS |
| Anthropic key | Lives in the proxy edge function | Fine where it is — see §6 |

The throughline: **the client is the application server.** The database schema is
the public API, business rules live in shipped app code, and analytics are
re-derived on the device from a mutable blob. Normalization, honest adherence,
and proactive coaching are all blocked by this until there's a server seam.

---

## 2. Decisions locked

From our discussion, these are settled and drive the plan:

- **This is the next chunk of work.** ✔
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
                                                                       │  adherence)  │
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
- **Postgres becomes a private implementation detail.** Its schema can change
  freely as long as the API contract holds. RLS stays as defense-in-depth.
- **Hosting:** start with a container (Fly.io / Railway / Cloud Run) for the API
  so multi-step coaching/LLM orchestration isn't boxed by edge-function runtime
  limits. The existing Anthropic proxy can stay an edge function (see §6).
- **Background/proactive:** `pg-boss` (queue inside Postgres, zero new infra) for
  the simple path, or Inngest if we want hosted scheduling/retries/step-functions
  for the eventing design.

---

## 4. Data model — normalization target

Replace the per-session blobs with rows. **Split prescription from completion.**

### 4.1 `prescribed_workouts` (the live, editable plan, as rows)

```
prescribed_workouts
├─ id              UUID PK         -- STABLE identity (fixes the type-label id)
├─ user_id, plan_id, week_number
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
what we only read whole.** Rest days become a day-level property, not a fake row.

### 4.2 `prescribed_exercises` (strength, link-by-id)

```
prescribed_exercises
├─ id                    UUID PK
├─ prescribed_workout_id FK → prescribed_workouts
├─ catalog_exercise_id   FK → exercise catalog (007/008)   -- stable link
├─ position              SMALLINT
└─ prescription          JSONB    -- prescribed sets/reps/load (per the decision)
```

### 4.3 `workout_completions` (the completion ledger — separate lifecycle)

The actuals currently crammed into `PrescribedSession` move here, keyed to the
stable prescription id:

```
workout_completions
├─ id                    UUID PK
├─ prescribed_workout_id FK → prescribed_workouts (nullable: unplanned sessions)
├─ status                TEXT     -- completed | shortened | missed | substituted | swapped
├─ actual_duration, actual_distance, actual_sport
├─ rpe, fatigue, athlete_note, completion_note
├─ linked_workout_id     -- HealthKit/Cardio link
└─ resolved_at, needs_review
```

Soft-delete on the prescription side means a moved/deleted workout never dangles
its completion or corrupts past adherence.

### 4.4 Snapshots & adherence (read-models)

- **`weekly_plan_snapshots`** already exists (013), but only fires at *generation*
  time (`create_plan|generate_week|regenerate_week`). **Add a `week_start`
  source** and a trigger that freezes the week when it begins — this is the
  artifact week-start-committed adherence is measured against.
- **`week_adherence`** (new) — compute once, server-side, at week close:

```
week_adherence
├─ user_id, plan_id, week_number, phase
├─ prescribed, completed, shortened, missed, substituted   -- the breakdown,
│                                                          --   now persisted
├─ by_sport       JSONB
├─ adherence_pct  NUMERIC
├─ snapshot_id    FK → weekly_plan_snapshots   -- provenance: what we measured against
└─ computed_at
```

Historical adherence = `SELECT … FROM week_adherence` (indexed, exact, chartable).
Snapshots are the immutable evidence behind each number, read whole only on
inspection. `weekly_reviews.adherence_pct` becomes a denormalized convenience
copy (or a view) rather than the source of truth.

---

## 5. Phased delivery

Ordering matters: **build the seam before changing the storage**, so the schema
migration happens once, behind a stable contract.

- **Phase 1 — Backend mutation API (still on the blob).**
  Stand up the service. Port the existing tools (`patch_weekly_plan`,
  `save_weekly_plan`, `log_workout`, `complete_weekly_review`,
  `generate_week_plan`) from `ToolExecutor.swift` to intent-named server
  endpoints that wrap the *current* blob ops. Client stops writing to Postgres
  directly. **No schema change yet** — this is purely the seam. Existing reads
  keep working.

- **Phase 2 — Normalize prescriptions behind the API.**
  Introduce `prescribed_workouts` / `prescribed_exercises` /
  `workout_completions`. Migrate the live blob → rows. Rewrite the API's edit
  ops to operate on rows (stable UUIDs, soft-delete). Clients are unaffected —
  they still call `/move-workout`. Retire the blob as the working copy.

- **Phase 3 — Week-start snapshots + adherence read-model.**
  Add the `week_start` snapshot trigger. Move `computeWeekAdherence` server-side,
  compute at week close against the week-start snapshot, persist to
  `week_adherence`. Repoint history/patterns reads at the table.

Each phase ships independently and leaves the app working.

---

## 6. Where the Anthropic API lives

Unchanged by default. The Anthropic call is just outbound HTTPS and works fine
from the existing edge-function proxy; prompt caching etc. are unaffected. The
constraint is never the call — it's the **orchestration around it**. A single
completion fits inside edge limits; long multi-step coaching (fetch context →
call → tool → call → write, several rounds, survives retries) does not. So:
keep the proxy where it is, and graduate only the heavy multi-turn coaching path
to the container API if/when it outgrows the edge runtime.

---

## 7. Non-goals / explicitly deferred

- Re-platforming off Postgres — **no.** Keep Supabase Postgres as system of record.
- Microservices — **no.** One service + Postgres + a job runner.
- Row-per-set exercise modeling — deferred; link-by-id + JSON is the decision.
- Backfilling honest history for past plans — out of scope by decision.
- Carrying the old direct-write client path — dropped at cutover.

---

## 8. Open items

None blocking. Resolved during design:

- "Originally prescribed" → **week-start committed.**
- Exercise depth → **link by id.**
- Past-plan history → **accept degraded.**
- Shipped clients → **clean cutover.**
- Edge vs. container for the API → **container** for the new service; proxy stays edge.
