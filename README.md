# Coach

AI-powered training coach that thinks like a real coach — not a template generator.

Built for triathlon, running, cycling, swimming, and strength training. Single-user PWA running on Vercel with Claude as the coaching engine.

## What makes this different

The AI has 14 tools it calls on demand to access your complete training history, then reasons about what you need like a real coach would: assessing your current fitness, comparing prescribed vs actual training, detecting patterns across weeks, adapting the plan based on what actually happened, checking injuries and safety rules, and learning how you respond to training over time.

## Features

- **Periodized training plans** — AI-generated phases with progression models, success criteria, and phase-specific rules
- **Prescribed vs actual tracking** — every session classified as completed, shortened, missed, or substituted with multi-week pattern detection
- **Flexible exercise system** — coach prescribes any exercise with 5 types (weighted, bodyweight, banded, timed, cardio-drill), no fixed library
- **Exercise history and PRs** — full per-exercise history, PR progression tracking, session-by-session breakdown
- **Tiered coaching memory** — permanent facts (equipment, injuries, safety rules) never pruned, observations rotate, conversation summaries auto-compress
- **Athlete response profiling** — coach learns how you respond to volume vs intensity, recovery rate, skip patterns
- **Plan archiving** — ended plans preserved with adherence data, referenced when building new plans
- **Safety protocol** — universal rules + athlete-specific safety rules enforced before prescriptions
- **Race conditions** — AI-generated course analysis with weather data
- **4 coaching personalities** — normal, Goggins mode, hype coach, or custom
- **Brick workouts** — link multi-sport sessions with transition tracking
- **Nutrition coaching** — per-session fueling guidance, timing-based logging

## Quick start

```bash
git clone https://github.com/evansjesse012/coach.git
cd coach
echo "ANTHROPIC_API_KEY=sk-ant-..." > .env.local
npm install && npm run dev
```

Open `http://localhost:3000`. Or push to Vercel — it auto-deploys from `main`.

## Project structure

```
app/
  page.jsx                  <- Entire frontend (~3600 lines)
  layout.jsx                <- Root layout
  api/chat/route.js         <- Anthropic API proxy
  api/weather/route.js      <- Open-Meteo weather proxy
public/
  seed-data.json            <- Test data (8 weeks of training)
docs/
  ARCHITECTURE.md           <- How the AI coaching engine works
  DEVELOPMENT.md            <- How to work on this codebase
  FEATURES.md               <- How each feature works in detail
  COACHING_ENGINE_PLAN.md   <- Original roadmap for coaching intelligence
```

## Docs

- **[Architecture](docs/ARCHITECTURE.md)** — Agent loop, tools, memory system, exercise system, plan archiving
- **[Development](docs/DEVELOPMENT.md)** — How to add features, coding conventions, current tools and components
- **[Features](docs/FEATURES.md)** — How each feature works under the hood (plans, adherence, memory, race conditions, strength, etc.)
- **[Coaching Engine Plan](docs/COACHING_ENGINE_PLAN.md)** — Original 8-step roadmap (Steps 1-4, 6-8 complete; Step 5 pending)
