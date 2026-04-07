# Architecture

How the AI coaching system works.

## Core Design

**Agentic tool use, not context stuffing.** The AI has tools to fetch exactly the data it needs. The system prompt stays constant regardless of how much training data exists. A question about today's workout doesn't load 6 months of history — it calls `get_training_plan` and gets today's sessions.

**Tool execution is local.** `executeTool()` runs in the browser against localStorage data. The only network call is to the Anthropic API via `/api/chat`. This means the AI can access all training data without sending it over the wire on every message.

**The plan is a hypothesis.** Training plans are created through a conversational plan builder, stored as structured data, and continuously compared against actual logged workouts. The AI adapts based on what the athlete actually did, not what was prescribed.

## Tools (14)

| Tool | What it does |
|------|-------------|
| `get_workouts` | Workout history filtered by sport/date/limit. Includes brick linkage info. |
| `get_training_plan` | Current phase, week plan, or full season structure |
| `get_training_stats` | Weekly volume breakdown, trends, consistency over N weeks |
| `get_personal_records` | Strength PRs with estimated 1RM (keyed by exercise slug) |
| `get_goals` | Active goals with days remaining, optionally includes completed races/PRs |
| `get_athlete_profile` | Full coaching memory — permanent facts, injuries, benchmarks, patterns, response profile |
| `log_workout` | Log a completed workout (sport, duration, notes, date) |
| `log_nutrition` | Log what the athlete ate with training timing |
| `get_nutrition` | Recent nutrition log filtered by days/timing |
| `save_training_plan` | Save a full periodized season plan with phases |
| `save_weekly_plan` | Save a generated weekly plan for a specific week |
| `update_plan_progress` | Advance current week/phase |
| `get_week_review` | Prescribed vs actual adherence comparison with multi-week pattern detection |
| `get_plan_history` | Archived past training plans with adherence summaries and end reasons |

## Agent Loop

```
User message
  → sanitize message history (strip extra props, normalize to strings)
  → call Claude with system prompt + tools
  → if tool_use: execute locally, append results, loop (max 7 rounds)
  → if end_turn: extract text response
  → post-process: persist workouts, nutrition, plan changes to state + localStorage
  → typewriter animation + renderMd()
  → background: extractMemory() merges new facts into coaching memory
```

The loop tracks three side-effect categories separately: `workoutsLogged`, `nutritionLogged`, `planChanges`. Each has its own post-processing in `handleSend`.

## System Prompts

**`buildSystemPrompt`** — Main coaching prompt. Includes:
- Coaching personality (normal, Goggins, hype coach, custom)
- Context-calibrated response (QUICK/LIGHT/MODERATE/FULL tool routing)
- App schema (data format rules for sessions, bricks, nutrition)
- Session prescriptions (purpose, workout detail, modification notes required)
- Strength exercise types (weighted, bodyweight, banded, timed, cardio-drill)
- Safety protocol (universal rules + athlete-specific from coaching record)
- Athlete adaptation (reads responseProfile to personalize coaching)
- Guardrails (no macros, restructure vs repeat, protect from overtraining)

**`buildPlanBuilderPrompt` (create mode)** — The AI gathers data silently, checks plan history for past patterns, leads with its assessment, proposes phases, asks only what data can't answer (max 5 questions), and generates on confirmation. Requires phase intelligence fields: progression models, success criteria, rules, strength protocols.

**`buildPlanBuilderPrompt` (week mode)** — Requires `get_week_review` first, then adapts the week based on adherence patterns. References what changed from last week and why.

## Prescribed vs Actual (Adherence)

The most important feedback loop. Two shared functions compute adherence on demand:

**`computeWeekAdherence(trainingPlan, weekNum, cardio, strength)`** — For each prescribed session, finds matching logged workouts by sport/type and day. Classifies as:
- **completed** — logged with >= 80% of prescribed duration
- **shortened** — logged but < 80% duration
- **substituted** — different sport logged that day
- **missed** — no matching log (past days only)

Strength sessions match by session label (name) with fallback to templateId for backward compatibility.

**`computeMultiWeekPatterns(trainingPlan, currentWeek, cardio, strength)`** — Looks back 4 weeks for recurring patterns: "swim missed in 3 of 4 weeks", "adherence declining: 90% → 65%".

Both are used by the `get_week_review` tool (AI reads them) and the Plan tab UI (athlete sees them).

## Memory System (Tiered, v2)

After each coaching conversation, a background API call extracts new facts and merges them into a persistent coaching memory document.

**Structure (coach_memory_v2):**
- **Permanent tier** (never pruned): equipment, facilities, schedule, medical history, dietary constraints, communication preferences, safety rules
- **Benchmarks** (append-only): metric/value/testDate/method — updates existing if same metric with newer date
- **Injuries** (never deleted): area, status, severity, triggers, safe activities, modifications, return criteria, full history timeline
- **Observations** (fuzzy dedup, no hard caps): patterns, motivators, consistency, current focus, open items, coaching notes
- **Response profile** (built over time): volume vs intensity preference, recovery rate, easy day discipline, session preferences, skip patterns, communication needs
- **Conversation summaries**: keep last 30 verbatim, compress oldest 20 into period summaries when exceeding 30

**Merge logic:** Permanent tier merges additively (never prunes). Injuries merge by area, append history. Observations use fuzzy dedup (substring matching for entries 15+ chars). Benchmarks update by metric if newer date. No hard caps on any arrays.

**Migration:** `loadMemory()` checks for v2 first, falls back to v1 with automatic migration via `migrateV1toV2()`.

**Memory extraction prompt:** Classifies facts into tiers and includes response profile assessment with evidence-based guidance (e.g., "always wiped after intervals" → recoveryRate: "slow after intensity").

## Exercise System

Exercises are prescribed inline by the AI coach — no fixed library or templates. Each exercise has a `type` field:

| Type | Tracks | Examples |
|------|--------|----------|
| `weighted` | weight + reps | bench press, RDL, leg press |
| `bodyweight` | reps only | push-ups, pull-ups, air squats |
| `banded` | band level + reps | banded walks, pull-aparts |
| `timed` | duration (seconds) | plank, wall sit, dead hang |
| `cardio-drill` | reps or duration | high knees, mountain climbers |

PRs are keyed by exercise name slug (`exSlug(name)`) and track history for progression over time. PR detection adapts per type (1RM for weighted, best reps for bodyweight, longest hold for timed).

## Plan Archiving

When a training plan is ended, the user selects a reason (completed, new goal, injury, not working, life, other) and optionally adds notes. The full plan is archived to `coach_plan_history` with:
- Complete adherence summary (overall %, per-week breakdown, missed-by-type)
- Phase completion status
- Reason and notes

A coaching note is written to memory. The `get_plan_history` tool lets the AI reference past plans when building new ones.

## Data Persistence Pattern

Every data type follows the same chain:

```
Creation (tool result or UI action)
  → React state update (setCardio, setEvents, etc.)
  → localStorage persist (db.set('coach_key', data))
  → Available to tools via getAppState() on next AI call
  → Loaded on app start via db.get('coach_key', fallback)
```

localStorage keys: `coach_events`, `coach_cardio`, `coach_strength_history`, `coach_prs`, `coach_nutrition`, `coach_bricks`, `coach_training_plan`, `coach_plan_history`, `coach_messages`, `coach_memory_v2`, `coach_push_message`, `coach_personality`, `coach_custom_prompt`, `coach_dark_mode`, `coach_active_workout`.

## Brick Workouts

Bricks link two existing workouts as a multi-discipline session (bike→run, swim→bike). Stored in `coach_bricks` as lightweight link objects referencing cardio workout IDs. Auto-detection prompts the athlete to link when different-sport workouts are logged on the same day. The AI prescribes bricks using `type:'brick'` with a `legs` array in weekly plans.

## Markdown Rendering

`renderMd()` converts AI output to styled React elements: `#`/`##`/`###` headings, `**bold**`, `-`/`*`/`•` bullets, `1.` numbered lists, `---` rules, and paragraph spacing. Applied to all AI-facing text: chat messages, streaming, plan builder, coach's note, athlete profile chat.

## API Routes

**`/api/chat`** — Proxies requests to Anthropic Messages API. Passes through tools and tool_choice. API key stays server-side.

**`/api/weather`** — Proxies to Open-Meteo (free, no key). Geocodes location string, returns forecast (within 16 days) or climate context (further out). Used for race detail views.
