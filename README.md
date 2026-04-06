# Coach

AI-powered training coach that thinks like a real coach — not a template generator.

Built for triathlon, running, cycling, swimming, and strength training. Single-user PWA running on Vercel with Claude as the coaching engine.

## What makes this different

The AI has 13 tools it calls on demand to access your complete training history, then reasons about what you need like a real coach would: assessing your current fitness, comparing prescribed vs actual training, detecting patterns across weeks, and adapting the plan based on what actually happened — not just what was scheduled.

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
  page.jsx                  ← Entire frontend (~2700 lines)
  layout.jsx                ← Root layout
  api/chat/route.js         ← Anthropic API proxy
  api/weather/route.js      ← Open-Meteo weather proxy
public/
  seed-data.json            ← Test data (8 weeks of training)
docs/
  ARCHITECTURE.md           ← How the AI coaching engine works
  DEVELOPMENT.md            ← How to work on this codebase
  COACHING_ENGINE_PLAN.md   ← Roadmap for coaching intelligence
```

## Docs

- **[Architecture](docs/ARCHITECTURE.md)** — Agent loop, tools, memory, plan builder, adherence tracking
- **[Development](docs/DEVELOPMENT.md)** — How to add features, coding conventions, current tools
- **[Coaching Engine Plan](docs/COACHING_ENGINE_PLAN.md)** — 8-step plan for deeper coaching intelligence
