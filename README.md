# Coach — iOS App

AI-powered training coach for endurance athletes. Swift/SwiftUI on the
client, Supabase (Postgres + edge functions) on the backend, Claude
Sonnet 4.6 driving the coaching intelligence.

## Documentation

- **[FEATURES.md](./FEATURES.md)** — plain-English walkthrough of what
  the app does. Start here if you want to understand the product.
- **[ARCHITECTURE.md](./ARCHITECTURE.md)** — how the app is built, layer
  by layer. Start here if you're onboarding to the codebase.

## At a glance

- 5 tabs: Home, Goals, Plan, Log, Stats — plus a persistent Coach
  chat bar that's always one tap away from any tab
- Periodized training plans with adherence tracking and lazy per-week
  generation (the coach shapes next week closer to when it starts, not
  months in advance)
- Multi-sport workout logging (run, bike, swim, strength, brick)
- Live strength workout tracker with rest timer and auto PR rolling
- HealthKit auto-matching — imported workouts pair to prescribed
  sessions by sport, duration, time-of-day, and HR zone
- AI coach chat with 21 tools and a tiered memory system that
  remembers injuries, benchmarks, and patterns across conversations
- Weekly check-in / review / preview ritual — Sunday-evening
  conversation produces persistent paired artifacts that frame the
  next week and assess the last one
- CTL/ATL/TSB training-load tracking with per-sport TSS and
  benchmark-versioned thresholds
- Sign in with Apple authentication
- 4 coaching personalities (Head Coach, Goggins, Hype, Custom)

## Setup

### Prerequisites
- Xcode 26+ (iOS 26 deployment target)
- Supabase project (free tier works)
- Anthropic API key

### Supabase
1. Create a project at [supabase.com](https://supabase.com).
2. Apply the migrations: `supabase db push` (requires `supabase` CLI
   and a linked project).
3. Set the Anthropic key and deploy the chat function:
   ```bash
   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
   supabase functions deploy chat --no-verify-jwt
   ```
   The `--no-verify-jwt` flag is intentional: the function verifies the
   JWT itself via a direct call to `/auth/v1/user`, which works with
   projects that use ES256 asymmetric signing keys where supabase-js's
   Deno build falls over.

### Xcode
1. Open `ios/Coach/Coach.xcodeproj`
2. Add the `supabase-swift` Swift Package dependency if not resolved
3. Update the URL + anon key in `Services/SupabaseService.swift` to
   match your Supabase project (both are public identifiers — RLS is
   what protects data)
4. Build and run (Cmd+R)

## Project structure

```
ios/Coach/Coach/
├── CoachApp.swift              # App entry point, auth state
├── Models/                     # Codable data models
├── Services/                   # Supabase, Data, Weather, HealthKit, plan generator
├── AI/                         # Tool definitions, agent loop, prompts, memory extraction
├── Views/                      # SwiftUI views (Auth, Home, Goals, Plan, Log, Coach, Strength, Exercises, Settings, Shared)
└── Utilities/                  # Helpers (adherence, exercise, dates, formatting)

supabase/
├── migrations/                 # Postgres schema (20 tables with RLS + a 234-exercise catalog)
└── functions/chat/             # Anthropic API proxy Edge Function
```

See [ARCHITECTURE.md](./ARCHITECTURE.md) for the layer-by-layer
breakdown and [FEATURES.md](./FEATURES.md) for the product walkthrough.
