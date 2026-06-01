# Coach Backend

The server seam in front of Postgres. See [`../BACKEND_FOUNDATION_PLAN.md`](../BACKEND_FOUNDATION_PLAN.md)
for the why and the full design.

- **Stack:** TypeScript · [Hono](https://hono.dev) (web) · [Drizzle](https://orm.drizzle.team) (typed queries) · [pg-boss](https://github.com/timgit/pg-boss) (jobs) · Postgres (your existing Supabase)
- **Hosting:** [Railway](https://railway.app) (deploys on every push)
- **Schema source of truth:** the SQL files in `../supabase/migrations/`. Drizzle here is for queries only — it does **not** own migrations.

## Status

Phase 0 (skeleton) is in place: health check, JWT verification, DB connection,
and the Phase 1 mutation endpoints scaffolded (they return `501 not_implemented`
until Phase 1 ports the logic from `ToolExecutor.swift`).

## Endpoints

| Method | Path | Replaces (today's client tool) | Status |
|---|---|---|---|
| GET | `/health` | — | live |
| POST | `/plan/patch-week` | `patch_weekly_plan` | scaffold (501) |
| POST | `/plan/save-week` | `save_weekly_plan` | scaffold (501) |
| POST | `/plan/generate-week` | `generate_week_plan` | scaffold (501) |
| POST | `/workouts/log` | `log_workout` | scaffold (501) |
| POST | `/weekly-review/complete` | `complete_weekly_review` | scaffold (501) |

All endpoints except `/health` require a Supabase `Authorization: Bearer <jwt>`
header — verified against `${SUPABASE_URL}/auth/v1/user` (same path the edge
function uses; required because the project uses asymmetric ES256 keys).

## Run locally

```bash
cd backend
cp .env.example .env      # then fill in the values (see below)
npm install
npm run dev               # starts on http://localhost:8080
curl localhost:8080/health
```

### Environment values (where to find them)

| Variable | Where |
|---|---|
| `DATABASE_URL` | Supabase → Settings → Database → **Connection string** (use the *pooled*, port 6543) |
| `SUPABASE_URL` | Supabase → Settings → API → Project URL |
| `SUPABASE_ANON_KEY` | Supabase → Settings → API → anon/public key |
| `ANTHROPIC_API_KEY` | Anthropic console — only needed at Phase 4 (agent loop) |

Never commit `.env` — it is gitignored.

## Deploy to Railway

1. Create a Railway account (sign in with GitHub) and a new project.
2. **New → Deploy from GitHub repo** → pick this repo → set the **root
   directory** to `backend`.
3. Railway auto-detects Node and runs `npm install` then `npm run build` then
   `npm start`. (Build = `tsc`, start = `node dist/index.js`.)
4. Under **Variables**, add the four env values from the table above.
5. Railway gives you a public URL. Hit `https://<url>/health` — expect
   `{"status":"ok","db":true}`.

The iOS app keeps working unchanged throughout — it still reads via PostgREST and
calls the existing `chat` edge function. The cutover to these endpoints happens
in a later client change (plan §3.3, §5).
