# Development Guide

How to work on the Coach codebase, add features, and update the AI.

## Current File Structure

The working app is two files:

```
app/
  page.jsx              ← The entire frontend (~1500 lines)
  layout.jsx            ← Root layout (metadata + html shell)
  api/
    chat/
      route.js           ← API proxy for Anthropic (44 lines)
```

Everything else in the repo is documentation.

## Development Workflow

### Making changes with Claude

The recommended workflow:

1. Open the repo with Claude Code
2. Describe what you want to change
3. Claude edits `app/page.jsx` directly
4. Push to `main` — Vercel auto-deploys

For AI behavior changes (tool definitions, system prompt, personality prompts), always describe the exact behavior you want and let Claude update the relevant section. Test by chatting with the coach after deploy.

### Testing locally

```bash
cd coach
echo "ANTHROPIC_API_KEY=sk-ant-..." > .env.local
npm install
npm run dev
```

Open `http://localhost:3000`. Requires Node.js >= 20.

## How to Add Features

### Adding a new tool

The AI can only access data you give it tools for. To make new data available:

1. **Define the tool** — Add to the `TOOLS` array:
```javascript
{ name:'get_sleep_data',
  description:'Get recent sleep data. Use when athlete asks about recovery or sleep quality.',
  input_schema:{type:'object',properties:{days:{type:'number'}}} },
```

2. **Implement the executor** — Add a case to `executeTool()`:
```javascript
case 'get_sleep_data': {
  const { days=14 } = input;
  const sleepData = /* read from wherever sleep data lives */;
  return JSON.stringify({ records: sleepData });
}
```

3. **Update the system prompt** (optional) — If the tool needs specific guidance, add a line to the decision tree in `buildSystemPrompt()`:
```
- Recovery/sleep questions: get_sleep_data
```

That's it. The agent loop handles any number of tools automatically.

### Adding a new tab

1. Add the tab to the `TABS` array:
```javascript
{id:'progress', label:'Progress', icon:'chart'}
```

2. Add the conditional render in the content section:
```javascript
{tab==='progress' && <ProgressTab cardio={cardio} strength={strengthH} prs={prs} />}
```

3. Create the component function above the app root.

### Adding a new coach personality

1. Add to the `PERSONALITIES` object:
```javascript
zen: {
  name:'Zen Coach', icon:'heart', color:'#8B6FE8',
  tagline:'Calm · consistent · philosophical',
  description:'Finds meaning in small daily actions. Values consistency over intensity.',
  prompt:`You are a calm, philosophical coach...`,
  commentaryStyle:'Reflective tone. 2-3 sentences. Emphasize the process over outcomes.',
},
```

2. Add the key to the personality selector in `SettingsPage`.

### Adding a new dashboard widget

Currently the home tab has hardcoded stat cards. To add more:

1. Compute the data in `HomeTab` from the props it receives
2. Add a new `Card` in the grid layout
3. No AI changes needed — widgets are pure UI

## Coding Conventions

### Style

- Inline styles throughout (no CSS modules, no Tailwind). This keeps the single-file architecture working.
- Color references use the `C` object (e.g., `C.accent`, `C.text`). Never hardcode hex values in components.
- Font references use the `F` object (e.g., `F.display`, `F.ui`, `F.mono`).
- Shadow references use the `S` object.

### Component patterns

- Shared UI components (`Card`, `Btn`, `Inp`, `Label`, `Pill`, `SportBadge`) are defined as functions or arrow expressions.
- Modal-style overlays use the `Sheet` component for bottom sheets.
- Confirmation dialogs use the global `confirmDialog()` function.
- Toast notifications use the global `toast.success()` / `toast.error()` / etc.
- Assistant chat messages use `renderMd()` for basic markdown (bold, bullets).

### Data patterns

- All persistent data goes through the `db` helper: `db.get(key, fallback)` and `db.set(key, value)`.
- localStorage keys are prefixed with `coach_` (e.g., `coach_cardio`, `coach_events`).
- State flows down via props. There's no global state management (no Zustand, no Context) — the root component holds all state.
- Events (goals/races/PRs) have a `mode` field: `'goal'`, `'race'`, or `'pr'`.
- Triathlon races store `splits: { swim, t1, bike, t2, run, total }`.

### AI interaction patterns

- All AI calls go through `callAI()`, which POSTs to `/api/chat`.
- The agent loop (`runAgentLoop`) handles multi-step tool use. Message history is sanitized before sending (extra properties stripped, content normalized to strings).
- Memory extraction (`extractMemory`) is fire-and-forget after the user sees their response.
- Quick capture (`parseQuickCapture`) is a one-shot API call with structured JSON output.
- Error messages are displayed to the user but not persisted to chat history.

## Current Tools (13)

| Tool | Purpose |
|------|---------|
| `get_workouts` | Workout history filtered by sport/date |
| `get_training_plan` | This week's plan with completion status |
| `get_training_stats` | Weekly volume, trends, consistency |
| `get_personal_records` | PRs for exercises |
| `get_goals` | Active goals with days remaining |
| `get_athlete_profile` | Coaching memory (accumulated facts) |
| `log_workout` | Log a completed workout |
| `log_meal` | Log a meal with timing relative to training |
| `get_meals` | Recent meal log filtered by days/timing |
| `save_training_plan` | Save a full periodized season plan |
| `save_weekly_plan` | Save a generated weekly plan for a specific week |
| `update_plan_progress` | Advance current week/phase in training plan |

## Known Issues

1. **Theme mutation** — `C` and `S` are mutable module-level objects. Components don't re-render when theme changes; they rely on the root re-render cascading. This breaks if you add `React.memo` to any component.

2. **localStorage purging** — Safari clears PWA localStorage after 7 days of inactivity. Training data will be lost. Fix: wire up Supabase.

3. **No rate limiting** — The `/api/chat` endpoint has no auth or rate limiting. Anyone who discovers the URL can burn API credits.

4. **Plan generation is static** — `generateWeeklyPlan()` doesn't adapt to training phase or progression.

5. **Data is per-device** — localStorage doesn't sync between phone and computer.
