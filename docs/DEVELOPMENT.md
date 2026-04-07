# Development Guide

## File Structure

```
app/
  page.jsx                  <- Entire frontend (~3600 lines)
  layout.jsx                <- Root layout (metadata + html shell)
  api/
    chat/route.js           <- Anthropic API proxy (44 lines)
    weather/route.js        <- Open-Meteo weather proxy (111 lines)
public/
  seed-data.json            <- Test data: 8 weeks of triathlon training
docs/
  ARCHITECTURE.md           <- How the AI engine works
  DEVELOPMENT.md            <- This file
  FEATURES.md               <- How each feature works in detail
  COACHING_ENGINE_PLAN.md   <- Original roadmap (mostly complete)
```

## Workflow

1. Open the repo with Claude Code
2. Describe what you want to change
3. Claude edits `app/page.jsx` directly
4. Push to `main` — Vercel auto-deploys

For local dev:
```bash
echo "ANTHROPIC_API_KEY=sk-ant-..." > .env.local
npm install && npm run dev
```
Requires Node.js >= 20.

## Loading Test Data

Settings -> "Load test data" fetches `public/seed-data.json` and populates all localStorage keys. Contains 63 cardio workouts (55 from HealthKit), 11 strength sessions, 5 bricks, 18 nutrition entries, 4 events, PRs, coaching memory, and 1 archived plan history — all across 8 weeks of base-building triathlon training.

## Tools (14)

| Tool | Purpose |
|------|---------|
| `get_workouts` | Workout history filtered by sport/date |
| `get_training_plan` | Current plan, phase, and week sessions |
| `get_training_stats` | Weekly volume, trends, consistency |
| `get_personal_records` | Strength PRs with estimated 1RM |
| `get_goals` | Active goals with days remaining |
| `get_athlete_profile` | Coaching memory (permanent facts, injuries, benchmarks, observations, response profile) |
| `log_workout` | Log a completed workout |
| `log_nutrition` | Log nutrition with training timing |
| `get_nutrition` | Recent nutrition log |
| `save_training_plan` | Save periodized season plan |
| `save_weekly_plan` | Save weekly plan for a specific week |
| `update_plan_progress` | Advance week/phase |
| `get_week_review` | Prescribed vs actual adherence comparison |
| `get_plan_history` | Archived past plans with adherence data |

### Adding a tool

1. Add definition to `TOOLS` array
2. Add `case` to `executeTool()`
3. If it produces side effects, extract results in the agent loop
4. Optionally add routing guidance to `buildSystemPrompt`

## Key Components

| Component | What it does |
|-----------|-------------|
| `TodaySessionCard` | Shows today's prescribed sessions with completion status, brick support |
| `TrainingPlanTab` | Full plan view: phase timeline, weekly sessions with adherence bar, disruption buttons, season grid, phase detail with progression/criteria/rules |
| `PlanBuilderSheet` | Conversational plan creation/week generation with dedicated AI prompt |
| `WorkoutLogTab` | Workout list with sport filters, brick grouping, Workouts/Exercises toggle |
| `ExerciseListView` | All unique exercises with PR, last performed, session count |
| `ExerciseDetailSheet` | Full exercise history: PR progression, session-by-session breakdown |
| `WorkoutDetailSheet` | Full workout details: duration, distance, HR, zones, pace, notes, exercise sets |
| `BrickDetailSheet` | Brick workout details: both legs, transition time/notes |
| `AthleteProfilePage` | Tiered coaching memory view (Setup, Benchmarks, Injuries, Patterns, Response Profile, History) with chat-based updates |
| `GoalDetailView` | Race/goal details: splits, placements, race plan sections, weather, conditions |
| `EndPlanSheet` | Plan archiving flow with reason selection and adherence summary |
| `ChatTab` | Main coaching chat with markdown rendering |
| `StrengthTracker` | Set-by-set workout tracker with exercise-type-adaptive UI, rest timers, PR detection |

## Coding Conventions

**Styles:** Inline throughout. Colors via `C` object, fonts via `F`, shadows via `S`. Never hardcode hex values.

**Shared UI:** `Card`, `Btn`, `Inp`, `Label`, `Pill`, `SportBadge`, `Sheet`, `Icon`, `Toggle`, `Textarea`.

**Data:** All via `db.get(key, fallback)` / `db.set(key, value)`. Keys prefixed `coach_`.

**AI:** All calls through `callAI()` -> `/api/chat`. Agent loop via `runAgentLoop()`. Memory extraction via `extractMemory()` (fire-and-forget).

**Markdown:** `renderMd()` handles headings, bold, bullets, numbered lists, rules. Applied to all AI output.

**Events:** Have `mode` field: `'goal'` | `'race'` | `'pr'`. Tri races store `splits` object.

**Bricks:** Lightweight links between two cardio workouts. Auto-detected on log.

**Adherence:** `computeWeekAdherence()` and `computeMultiWeekPatterns()` shared between `get_week_review` tool and Plan tab UI.

**Exercises:** Keyed by slug (`exSlug(name)`). PRs track history array for progression. Exercise types: weighted, bodyweight, banded, timed, cardio-drill.

**Memory:** Tiered v2 format with automatic v1 migration. No hard caps. Fuzzy dedup for observations. Conversation summaries auto-compress after 30.

## Known Issues

1. **Theme mutation** — `C`/`S` are mutable module-level objects. Dark mode toggle can flash mixed colors. Don't add `React.memo` to components.
2. **localStorage risk** — Safari may purge PWA data after 7 days of inactivity.
3. **No rate limiting** — `/api/chat` has no auth. Anyone with the URL can burn API credits.
4. **Per-device data** — localStorage doesn't sync between phone and computer.
5. **Static fallback plan** — `generateWeeklyPlan()` still exists as fallback for `TodaySessionCard` when no periodized plan exists. Static strength sessions have no exercises array (no "Start" button).
