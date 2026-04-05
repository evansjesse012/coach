# Development Guide

How to work on the Coach codebase, add features, and update the AI.

## Current File Structure

The working app is two files:

```
app/
  page.jsx              ← CoachFinal.jsx — the entire frontend (789 lines)
  api/
    chat/
      route.js           ← API proxy for Anthropic (35 lines)
```

Everything else in the repo is either documentation or designed-but-not-wired future architecture:

```
future/
  schema.sql             ← Supabase schema (run this when you wire up the backend)
  rls.sql                ← Row-level security policies (run after schema.sql)
  _layout.jsx            ← Expo Router root layout (for native iOS version)
  auth.jsx               ← Auth screen (for multi-user version)
  src/agent/
    agentLoop.js         ← Modular agent loop (extracted reference, not imported)
    tools.js             ← Tool definitions (extracted reference, not imported)
    systemPrompt.js      ← Legacy system prompt builder (context-stuffing approach)
    commands.js          ← Legacy XML command parser (replaced by tool use)
    index.js             ← Legacy useAgent hook (calls API directly, broken)
```

**Source of truth is always `CoachFinal.jsx`.** The files in `future/src/agent/` are earlier modular versions that diverged. When you extract CoachFinal.jsx into modules, start fresh from the current code — don't try to reconcile with the old modules.

## Development Workflow

### Making changes with Claude

The recommended workflow:

1. Open CoachFinal.jsx in Claude
2. Describe what you want to change
3. Claude produces the updated file
4. Paste into v0.dev → verify → deploy

For small changes (fixing a color, changing a label), you can edit directly in v0.dev's editor.

For AI behavior changes (tool definitions, system prompt, personality prompts), always describe the exact behavior you want and let Claude update the relevant section. Test by chatting with the coach after deploy.

### Testing locally

If you want to run locally instead of through v0.dev:

```bash
npx create-next-app@latest coach --typescript=false
cd coach
# Replace app/page.jsx with CoachFinal.jsx
# Add app/api/chat/route.js
echo "ANTHROPIC_API_KEY=sk-ant-..." > .env.local
npm run dev
```

Open `http://localhost:3000` on your phone (same Wi-Fi network) using your computer's local IP.

## How to Add Features

### Adding a new tool

The AI can only access data you give it tools for. To make new data available:

1. **Define the tool** — Add to the `TOOLS` array (~line 136):
```javascript
{ name:'get_sleep_data',
  description:'Get recent sleep data. Use when athlete asks about recovery or sleep quality.',
  input_schema:{type:'object',properties:{days:{type:'number'}}} },
```

2. **Implement the executor** — Add a case to `executeTool()` (~line 146):
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

1. Add the tab to the `TABS` array (~line 739):
```javascript
{id:'progress', label:'Progress', icon:'📈'}
```

2. Add the conditional render in the content section (~line 769):
```javascript
{tab==='progress' && <ProgressTab cardio={cardio} strength={strengthH} prs={prs} />}
```

3. Create the component function above the app root.

### Adding a new coach personality

1. Add to the `PERSONALITIES` object (~line 52):
```javascript
zen: {
  name:'Zen Coach', emoji:'🧘', color:'#8B6FE8',
  tagline:'Calm · consistent · philosophical',
  description:'Finds meaning in small daily actions. Values consistency over intensity.',
  prompt:`You are a calm, philosophical coach...`,
  commentaryStyle:'Reflective tone. 2-3 sentences. Emphasize the process over outcomes.',
},
```

2. Add the key to the personality selector in `SettingsPage` (~line 418):
```javascript
{['normal','goggins','hype','zen'].map(key => { ... })}
```

### Adding a new dashboard widget

Currently the home tab has hardcoded stat cards. To add more:

1. Compute the data in `HomeTab` from the props it receives
2. Add a new `Card` in the grid layout
3. No AI changes needed — widgets are pure UI

### Changing the training plan

`generateWeeklyPlan()` (~line 343) returns a static weekly plan based on goal type. To make it adaptive:

1. Accept training phase and week number as parameters
2. Vary volume and intensity based on phase (Base → Build → Peak → Taper)
3. The AI already reads the plan via `get_training_plan` — it will automatically reference the updated plan

## Coding Conventions

### Style

- Inline styles throughout (no CSS modules, no Tailwind). This keeps the single-file architecture working.
- Color references use the `C` object (e.g., `C.accent`, `C.text`). Never hardcode hex values in components.
- Font references use the `F` object (e.g., `F.display`, `F.ui`, `F.mono`).
- Shadow references use the `S` object.

### Component patterns

- Shared UI components (`Card`, `Btn`, `Inp`, `Label`, `Pill`, `SportBadge`) are defined as functions or arrow expressions around line 322.
- Modal-style overlays use the `Sheet` component for bottom sheets.
- Confirmation dialogs use the global `confirmDialog()` function.
- Toast notifications use the global `toast.success()` / `toast.error()` / etc.

### Data patterns

- All persistent data goes through the `db` helper: `db.get(key, fallback)` and `db.set(key, value)`.
- localStorage keys are prefixed with `coach_` (e.g., `coach_cardio`, `coach_events`).
- State flows down via props. There's no global state management (no Zustand, no Context) — the root component holds all state.

### AI interaction patterns

- All AI calls go through `callAI()` (~line 319), which POSTs to `/api/chat`.
- The agent loop (`runAgentLoop`) handles multi-step tool use.
- Memory extraction (`extractMemory`) is fire-and-forget after the user sees their response.
- Quick capture (`parseQuickCapture`) is a one-shot API call with structured JSON output.

## Known Issues

1. **Theme mutation** — `C` and `S` are mutable module-level objects. Components don't re-render when theme changes; they rely on the root re-render cascading. This breaks if you add `React.memo` to any component.

2. **Duplicate className on streaming div** — Line 602 has two `className` attributes. The second wins, dropping the `fade-up` animation.

3. **localStorage purging** — Safari clears PWA localStorage after 7 days of inactivity. Training data will be lost. Fix: wire up Supabase.

4. **No rate limiting** — The `/api/chat` endpoint has no auth or rate limiting. Anyone who discovers the URL can burn API credits.

5. **Plan generation is static** — `generateWeeklyPlan()` doesn't adapt to training phase or progression.
