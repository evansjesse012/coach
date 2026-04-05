# Architecture

How the AI coaching system works, why decisions were made, and how to extend it.

## Overview

Coach uses an **agentic tool-use pattern** rather than context stuffing. Instead of cramming all training data into every system prompt, the AI has tools it can call to fetch exactly the data it needs. The system prompt stays at ~300 tokens regardless of how much training data exists.

This was a deliberate architectural choice. Context stuffing works fine for a few weeks of data, but after 6 months of daily training logs, you'd be sending 3000+ tokens of context on every message — most of it irrelevant to the actual question. Tool use scales to years of data with constant prompt size.

## The Agent Loop

The core of the AI system. It handles multi-step tool use: the AI requests data, we execute the tool locally in the browser, send the result back, and repeat until the AI produces a final text response.

Key design:
- Messages are **sanitized** before entering the loop — extra properties stripped, content normalized to plain strings. This prevents 400 errors from malformed message history.
- The loop tracks workouts logged, meals logged, and plan changes separately so the caller can update React state.
- **maxRounds** prevents runaway tool loops. Most conversations use 1-3 rounds. The push message (which gathers 4 datasets) uses maxRounds=4.
- **Tool execution is local.** `executeTool()` runs in the browser against localStorage data. No network call. The only network call is to the Anthropic API.

## Tool Definitions

13 tools that give the AI access to all training data:

| Tool | Purpose | Key inputs |
|------|---------|------------|
| `get_workouts` | Workout history | sport, days, limit |
| `get_training_plan` | This week's plan with completion status | — |
| `get_training_stats` | Weekly volume, trends, consistency | weeks |
| `get_personal_records` | PRs for exercises | exercise |
| `get_goals` | Active goals with days remaining | include_completed |
| `get_athlete_profile` | Coaching memory (accumulated facts) | — |
| `log_workout` | Log a completed workout | sport, duration, notes, date |
| `log_meal` | Log a meal with training timing | meal, timing, relatedWorkout, date |
| `get_meals` | Recent meal log | days, timing |
| `save_training_plan` | Save a full periodized season plan | goalId, phases, totalWeeks, etc. |
| `save_weekly_plan` | Save a generated weekly plan | weekNumber, phase, sessions |
| `update_plan_progress` | Advance current week/phase | currentWeek, currentPhase |

The descriptions are deliberately opinionated about *when* to use each tool. "Only use when athlete explicitly describes something they just completed" prevents the AI from logging hypothetical workouts. These descriptions are the primary lever for controlling AI behavior.

### Adding a New Tool

1. Add the tool definition to the `TOOLS` array (name, description, input_schema)
2. Add a `case` to `executeTool()` that reads from `appState` and returns a JSON string
3. If it produces side effects (like logging), extract the result in the agent loop so the caller can update state
4. Mention the tool in the system prompt's decision tree if it needs special guidance
5. No other changes needed — the agent loop handles any number of tools

## System Prompt

The system prompt is intentionally lean. It tells the AI its personality, gives it a decision tree for tool usage, and provides today's date. No training data.

The decision tree is critical. Without it, the AI tends to call `get_workouts` for everything. With it, the AI uses the right tool for the right question, which produces better coaching because it has the right context.

## Memory System

After each coaching conversation, a background API call extracts new facts and merges them into a persistent memory document. This runs after the user sees their response — it never blocks the UI.

The memory structure has five sections:
- **profile** — communication style, preferred workout times, equipment
- **physical** — injuries (with status tracking), strengths, limiters
- **behavioral** — patterns, motivators, consistency notes
- **coaching** — open items, current focus, session notes
- **conversationSummaries** — rolling window of the last 10 conversation summaries

The merge logic is additive with deduplication: new injuries update existing entries by body area, behavioral patterns are appended with `Set`-based dedup, and arrays are capped (12 patterns, 10 summaries) to prevent unbounded growth.

### Memory Architecture Limitation

Currently stored in localStorage. This means:

- Safari can purge it after 7 days of PWA inactivity
- No backup or sync
- Lost if the user clears browser data

When Supabase is wired up, memory should move to a `coaching_memory` table with the same JSON structure, loaded on auth and saved after extraction.

## Streaming / Typewriter Effect

The app uses a fake typewriter effect rather than real streaming. The full response is available after the agent loop completes, then revealed character by character using `requestAnimationFrame`. This gives a better UX than dumping a wall of text at once while being simpler than implementing real SSE streaming through the Vercel proxy.

To add real streaming later, you'd need to switch the API route to return a ReadableStream and process SSE events in the browser. The agent loop makes this harder because tool calls require full roundtrips — you can only stream the final text response, not the intermediate tool-calling steps.

## Chat Markdown Rendering

Assistant messages use a `renderMd()` function that converts:
- `**bold text**` → `<strong>` spans
- Lines starting with `-` or `•` → styled bullet points
- Bold within bullets is supported

This is applied to assistant messages and streaming text only. User messages remain plain text. No dependencies — just regex and React elements.

## Push Message Generation

The daily coaching analysis on the home screen uses the same agent loop but with a specific prompt that forces 4 tool calls (training plan, workouts, stats, goals). The result is cached in localStorage with a staleness check (8 hours) and refreshes when workout count changes.

## Goals / Races / PRs

Events have a `mode` field: `'goal'` (future target), `'race'` (completed race), or `'pr'` (personal record).

- **Goals** — standard future events with goal time, stretch goal, baseline
- **Past Races** — auto-marked completed, with result and placement fields
- **PRs** — auto-marked completed, with result and previous best
- **Triathlon splits** — tri presets (70.3, Ironman, Sprint) store `splits: { swim, t1, bike, t2, run, total }` for both past races and when completing a tri goal

When completing a tri goal, a "Race Results" sheet prompts for splits before marking complete.

## Data Flow

```
User types message
        │
        ▼
  handleSend()
        │
        ├── Add user message to React state
        │
        ▼
  runAgentLoop()
        │
        ├── Sanitize message history (strip extra props, normalize content)
        ├── Build system prompt (personality + date, ~300 tokens)
        ├── Send to /api/chat (Vercel proxy → Anthropic)
        │
        ├── If stop_reason === 'tool_use':
        │     ├── executeTool() runs locally against localStorage
        │     ├── Extract workouts/meals/plan changes from tool results
        │     ├── Append tool results to conversation chain
        │     └── Loop back to send again
        │
        └── If stop_reason === 'end_turn':
              ├── Extract final text
              └── Return { response, workoutsLogged, mealsLogged, planChanges }
        │
        ▼
  typewriter(response) + renderMd()
        │
        ├── Reveal text character by character with markdown formatting
        │
        ▼
  extractMemory() [background, fire-and-forget]
        │
        ├── Send last 8 messages to API for fact extraction
        ├── Merge extracted facts into localStorage memory
        └── Never blocks UI, never surfaces errors
```

## Extending the Architecture

### Adding a new data source (e.g., HealthKit)

1. Add a new tool definition (e.g., `get_health_data`)
2. In `executeTool()`, read from whatever storage HealthKit data lives in
3. The AI will call it when relevant — no prompt changes needed if the tool description is clear

### Adding proactive coaching (pattern detection)

Create a scheduled function that runs daily:
1. Call `get_training_stats(weeks=4)` and `get_goals()` locally
2. Compare actual vs prescribed volume
3. If a gap is detected (e.g., swim sessions < 1/week for 3 weeks), generate a "pattern card" via a focused API call
4. Display on the home screen above the push message

### Moving to Supabase

The tool executor currently reads from `appState` (which is hydrated from localStorage). To move to Supabase:
1. Replace `db.get()`/`db.set()` calls with Supabase queries
2. Hydrate `appState` from Supabase on auth instead of localStorage
3. Tool execution stays local — it reads from the in-memory appState, not directly from the database
4. Writes (workout logging, memory updates) go to Supabase instead of localStorage
