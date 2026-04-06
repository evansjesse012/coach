# Architecture

How the AI coaching system works.

## Core Design

**Agentic tool use, not context stuffing.** The AI has tools to fetch exactly the data it needs. The system prompt stays constant regardless of how much training data exists. A question about today's workout doesn't load 6 months of history — it calls `get_training_plan` and gets today's sessions.

**Tool execution is local.** `executeTool()` runs in the browser against localStorage data. The only network call is to the Anthropic API via `/api/chat`. This means the AI can access all training data without sending it over the wire on every message.

**The plan is a hypothesis.** Training plans are created through a conversational plan builder, stored as structured data, and continuously compared against actual logged workouts. The AI adapts based on what the athlete actually did, not what was prescribed.

## Tools (13)

| Tool | What it does |
|------|-------------|
| `get_workouts` | Workout history filtered by sport/date/limit. Includes brick linkage info. |
| `get_training_plan` | Current phase, week plan, or full season structure |
| `get_training_stats` | Weekly volume breakdown, trends, consistency over N weeks |
| `get_personal_records` | Strength PRs with estimated 1RM |
| `get_goals` | Active goals with days remaining, optionally includes completed races/PRs |
| `get_athlete_profile` | Full coaching memory — permanent facts, injuries, patterns, observations |
| `log_workout` | Log a completed workout (sport, duration, notes, date) |
| `log_nutrition` | Log what the athlete ate with training timing |
| `get_nutrition` | Recent nutrition log filtered by days/timing |
| `save_training_plan` | Save a full periodized season plan with phases |
| `save_weekly_plan` | Save a generated weekly plan for a specific week |
| `update_plan_progress` | Advance current week/phase |
| `get_week_review` | **Prescribed vs actual.** Compares plan against logged workouts, classifies sessions as completed/shortened/missed/substituted, detects multi-week patterns |

## Agent Loop

```
User message
  → sanitize message history (strip extra props, normalize to strings)
  → call Claude with system prompt + tools
  → if tool_use: execute locally, append results, loop
  → if end_turn: extract text response
  → post-process: persist workouts, nutrition, plan changes to state + localStorage
  → typewriter animation + renderMd()
  → background: extractMemory() merges new facts into coaching memory
```

The loop tracks three side-effect categories separately: `workoutsLogged`, `nutritionLogged`, `planChanges`. Each has its own post-processing in `handleSend`.

## Three System Prompts

**`buildSystemPrompt`** — Main coaching prompt. Includes personality, tool routing (graduated by request complexity), training plan generation rules, brick workout guidance, nutrition coaching, and safety protocol.

**`buildPlanBuilderPrompt` (create mode)** — Enforces a 6-step coaching sequence: silent data gathering → present assessment → propose plan concept → targeted questions → refine on input → generate on confirmation. The AI leads with what it knows, asks only what it can't derive from data.

**`buildPlanBuilderPrompt` (week mode)** — Requires `get_week_review` first, then adapts the week based on adherence patterns. References what changed from last week and why.

## Prescribed vs Actual (Adherence)

The most important feedback loop. Two shared functions compute adherence on demand:

**`computeWeekAdherence(trainingPlan, weekNum, cardio, strength)`** — For each prescribed session, finds matching logged workouts by sport/type and day. Classifies as:
- **completed** — logged with >= 80% of prescribed duration
- **shortened** — logged but < 80% duration
- **substituted** — different sport logged that day
- **missed** — no matching log (past days only)

**`computeMultiWeekPatterns(trainingPlan, currentWeek, cardio, strength)`** — Looks back 4 weeks for recurring patterns: "swim missed in 3 of 4 weeks", "adherence declining: 90% → 65%".

Both are used by the `get_week_review` tool (AI reads them) and the Plan tab UI (athlete sees them).

## Plan Builder

A dedicated sheet (not the Coach chat) for creating training plans and generating weekly sessions. Uses its own message chain, separate from the main chat history.

**Create mode:** Conversational flow where the AI assesses the athlete, proposes phases, asks questions, and generates on confirmation. The athlete stays on the Plan tab throughout.

**Week mode:** AI reviews last week's adherence, checks current phase, adapts the new week, and saves it. Progress stepper shows stage (Reviewing → Designing → Generating → Done).

## Memory System

After each coaching conversation, a background API call extracts new facts and merges them into a persistent coaching memory document.

**Structure:** profile (communication style, times, equipment), physical (injuries with status, strengths, limiters), behavioral (patterns, motivators, consistency), coaching (focus, open items, notes), and conversation summaries (rolling window of 10).

**Merge logic:** Additive with deduplication. Injuries update by body area. Patterns use Set-based dedup. Arrays are capped to prevent unbounded growth.

**Stored in:** `localStorage` under `coach_memory_v1`.

## Data Persistence Pattern

Every data type follows the same chain:

```
Creation (tool result or UI action)
  → React state update (setCardio, setEvents, etc.)
  → localStorage persist (db.set('coach_key', data))
  → Available to tools via getAppState() on next AI call
  → Loaded on app start via db.get('coach_key', fallback)
```

localStorage keys: `coach_events`, `coach_cardio`, `coach_strength_history`, `coach_prs`, `coach_nutrition`, `coach_bricks`, `coach_training_plan`, `coach_messages`, `coach_memory_v1`, `coach_push_message`, `coach_personality`, `coach_custom_prompt`, `coach_dark_mode`, `coach_active_workout`.

## Brick Workouts

Bricks link two existing workouts as a multi-discipline session (bike→run, swim→bike). Stored in `coach_bricks` as lightweight link objects referencing cardio workout IDs. Auto-detection prompts the athlete to link when different-sport workouts are logged on the same day. The AI prescribes bricks using `type:'brick'` with a `legs` array in weekly plans.

## Markdown Rendering

`renderMd()` converts AI output to styled React elements: `#`/`##`/`###` headings, `**bold**`, `-`/`*`/`•` bullets, `1.` numbered lists, `---` rules, and paragraph spacing. Applied to all AI-facing text: chat messages, streaming, plan builder, coach's note, athlete profile chat.

## API Routes

**`/api/chat`** — Proxies requests to Anthropic Messages API. Passes through tools and tool_choice. API key stays server-side.

**`/api/weather`** — Proxies to Open-Meteo (free, no key). Geocodes location string, returns forecast (within 16 days) or climate context (further out). Used for race detail views.
