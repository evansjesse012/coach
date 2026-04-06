# Development Guide

## File Structure

```
app/
  page.jsx                  ← Entire frontend (~2700 lines)
  layout.jsx                ← Root layout (metadata + html shell)
  api/
    chat/route.js           ← Anthropic API proxy (44 lines)
    weather/route.js        ← Open-Meteo weather proxy (111 lines)
public/
  seed-data.json            ← Test data: 8 weeks of triathlon training
docs/
  ARCHITECTURE.md           ← How the AI engine works
  DEVELOPMENT.md            ← This file
  COACHING_ENGINE_PLAN.md   ← Roadmap for coaching intelligence
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

Settings → "Load test data" fetches `public/seed-data.json` and populates all localStorage keys. Contains 63 cardio workouts (55 from HealthKit), 11 strength sessions, 5 bricks, 18 nutrition entries, 4 events, PRs, and coaching memory across 8 weeks of base-building triathlon training.

## Tools (13)

| Tool | Purpose |
|------|---------|
| `get_workouts` | Workout history filtered by sport/date |
| `get_training_plan` | Current plan, phase, and week sessions |
| `get_training_stats` | Weekly volume, trends, consistency |
| `get_personal_records` | Strength PRs with estimated 1RM |
| `get_goals` | Active goals with days remaining |
| `get_athlete_profile` | Coaching memory (permanent facts + observations) |
| `log_workout` | Log a completed workout |
| `log_nutrition` | Log nutrition with training timing |
| `get_nutrition` | Recent nutrition log |
| `save_training_plan` | Save periodized season plan |
| `save_weekly_plan` | Save weekly plan for a specific week |
| `update_plan_progress` | Advance week/phase |
| `get_week_review` | Prescribed vs actual adherence comparison |

### Adding a tool

1. Add definition to `TOOLS` array
2. Add `case` to `executeTool()`
3. If it produces side effects, extract results in the agent loop
4. Optionally add routing guidance to `buildSystemPrompt`

## Key Components

| Component | What it does |
|-----------|-------------|
| `TodaySessionCard` | Shows today's prescribed sessions with completion status, brick support |
| `TrainingPlanTab` | Full plan view: phase timeline, weekly sessions with adherence bar, disruption buttons, season grid |
| `PlanBuilderSheet` | Conversational plan creation/week generation with dedicated AI prompt |
| `WorkoutLogTab` | Workout list with sport filters, brick grouping, clickable detail sheets |
| `WorkoutDetailSheet` | Full workout details: duration, distance, HR, zones, pace, notes |
| `BrickDetailSheet` | Brick workout details: both legs, transition time/notes |
| `AthleteProfilePage` | Read-only view of coaching memory with chat-based updates |
| `GoalDetailView` | Race/goal details: splits, placements, race plan sections, weather, conditions |
| `ChatTab` | Main coaching chat with markdown rendering |
| `StrengthTracker` | Set-by-set workout tracker with rest timers and PR detection |

## Coding Conventions

**Styles:** Inline throughout. Colors via `C` object, fonts via `F`, shadows via `S`. Never hardcode hex values.

**Shared UI:** `Card`, `Btn`, `Inp`, `Label`, `Pill`, `SportBadge`, `Sheet`, `Icon`.

**Data:** All via `db.get(key, fallback)` / `db.set(key, value)`. Keys prefixed `coach_`.

**AI:** All calls through `callAI()` → `/api/chat`. Agent loop via `runAgentLoop()`. Memory extraction via `extractMemory()` (fire-and-forget).

**Markdown:** `renderMd()` handles headings, bold, bullets, numbered lists, rules. Applied to all AI output.

**Events:** Have `mode` field: `'goal'` | `'race'` | `'pr'`. Tri races store `splits` object.

**Bricks:** Lightweight links between two cardio workouts. Auto-detected on log.

**Adherence:** `computeWeekAdherence()` and `computeMultiWeekPatterns()` shared between `get_week_review` tool and Plan tab UI.

## Known Issues

1. **Theme mutation** — `C`/`S` are mutable module-level objects. Dark mode toggle can flash mixed colors. Don't add `React.memo` to components.
2. **localStorage risk** — Safari may purge PWA data after 7 days of inactivity.
3. **No rate limiting** — `/api/chat` has no auth. Anyone with the URL can burn API credits.
4. **Per-device data** — localStorage doesn't sync between phone and computer.
5. **Static fallback plan** — `generateWeeklyPlan()` still exists as fallback for `TodaySessionCard` when no periodized plan exists.
