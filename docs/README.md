# Coach

AI-powered personal training companion for triathlon, running, and strength training. Built for daily use as a mobile-first PWA.

## What This Is

A single-page React app that acts as your personal coach. It knows your training history, race goals, injury status, and behavioral patterns — and gives you real feedback based on real data, not generic encouragement.

### Features

- **Home** — Today's prescribed sessions, daily AI coaching analysis (push message), event countdown cards, recent activity summary
- **Goals** — Track upcoming goals, log past races (with tri splits: swim/T1/bike/T2/run/total), record PRs, organized into Upcoming / Race History / Personal Records / Completed sections
- **Plan** — Auto-generated weekly training plan from active goals, tap strength sessions to launch a set-by-set workout tracker with rest timers and PR detection
- **Log** — Manual workout logging, Apple Health import (mock data now, real HealthKit when native), filter by sport
- **Coach** — AI chat with tool-use agent loop, markdown rendering for bold and bullet lists. The AI fetches exactly the data it needs via tools rather than receiving everything upfront
- **Quick Capture** — Floating ⚡ button on every tab. Type "45 min easy run" and the AI parses and confirms it
- **Settings** — Light/dark mode, 4 coach personalities (Head Coach, Goggins Mode, Hype Coach, Custom), coaching memory viewer, data export

### AI Architecture

The AI has 13 tools it calls on demand: `get_workouts`, `get_training_plan`, `get_training_stats`, `get_personal_records`, `get_goals`, `get_athlete_profile`, `log_workout`, `log_nutrition`, `get_nutrition`, `save_training_plan`, `save_weekly_plan`, `update_plan_progress`. The system prompt is ~300 tokens (no data stuffing). This scales to years of training history.

After each conversation, a background API call extracts new facts (injuries, patterns, motivations) and merges them into persistent coaching memory.

## Tech Stack

- React JSX, single file (`app/page.jsx`) → deploys to Vercel via GitHub
- Vercel serverless API route for Anthropic proxy (API key stays server-side)
- Claude claude-sonnet-4-20250514 via Anthropic Messages API with tool use
- All data in localStorage (Supabase backend designed, not yet wired)
- Mobile-first PWA, optimized for iPhone home screen

## Project Structure

```
app/
  page.jsx              ← The entire frontend (~1500 lines)
  layout.jsx            ← Root layout (metadata + html shell)
  api/
    chat/
      route.js           ← API proxy for Anthropic

docs/                     ← Documentation
  README.md
  ARCHITECTURE.md
  DEVELOPMENT.md
  DEPLOY.md
  ROADMAP.md
```

## API Route

This is the only server-side code. It proxies requests to Anthropic so the API key never reaches the browser.

```javascript
// app/api/chat/route.js

export async function POST(request) {
  const body = await request.json();

  const payload = {
    model:      'claude-sonnet-4-20250514',
    max_tokens: body.max_tokens || 1024,
    system:     body.system,
    messages:   body.messages,
  };

  // Pass tools through if provided
  if (body.tools?.length) {
    payload.tools       = body.tools;
    payload.tool_choice = body.tool_choice || { type: 'auto' };
  }

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method:  'POST',
    headers: {
      'Content-Type':      'application/json',
      'x-api-key':         process.env.ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const error = await response.text();
    return new Response(
      JSON.stringify({ error: `Anthropic API error: ${response.status}`, detail: error }),
      { status: response.status, headers: { 'Content-Type': 'application/json' } }
    );
  }

  const data = await response.json();
  return Response.json(data);
}
```

## Quick Deploy

1. Connect the GitHub repo to Vercel
2. Set `ANTHROPIC_API_KEY` in Vercel → Settings → Environment Variables
3. Push to `main` — Vercel auto-deploys
4. Open on iPhone → Share → Add to Home Screen

See [DEPLOY.md](./DEPLOY.md) for the full step-by-step guide.

## Documentation

- [ARCHITECTURE.md](./ARCHITECTURE.md) — How the AI works: tool use, agent loop, memory system, streaming
- [DEVELOPMENT.md](./DEVELOPMENT.md) — How to work on this codebase, add features, update the AI
- [DEPLOY.md](./DEPLOY.md) — Step-by-step deployment guide with testing checklist
- [ROADMAP.md](./ROADMAP.md) — Phased plan from current state → daily use → native iOS → multi-user

## License

Private. Not open source.
