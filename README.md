# Coach — iOS App

AI-powered training coach built with Swift/SwiftUI and Supabase. Uses Claude as the coaching engine with 15 agentic tools.

## Setup

### Prerequisites
- Xcode 15+ (iOS 17 deployment target)
- Supabase project (free tier works)
- Anthropic API key

### Supabase
1. Create a project at [supabase.com](https://supabase.com)
2. Run `supabase/migrations/001_initial_schema.sql` in the SQL Editor
3. Deploy the Edge Function:
   ```bash
   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
   supabase functions deploy chat
   ```

### Xcode
1. Open `ios/Coach/Coach.xcodeproj`
2. Add `supabase-swift` package (File > Add Package Dependencies)
3. Update credentials in `Services/SupabaseService.swift`
4. Build and run (Cmd+R)

## Project Structure

```
ios/Coach/Coach/
├── CoachApp.swift              # App entry point, auth state
├── Models/                     # Codable data models (14 types)
├── Services/                   # Supabase, Data, Weather, HealthKit
├── AI/                         # Tool definitions, agent loop, prompts, memory
├── Views/                      # SwiftUI views (Auth, Home, Goals, Plan, Log, Coach)
├── Utilities/                  # Helpers (adherence, exercise, dates)
supabase/
├── migrations/                 # Database schema (14 tables with RLS)
├── functions/chat/             # Anthropic API proxy Edge Function
```

## Features

- Periodized training plans with adherence tracking
- Multi-sport workout logging (run, bike, swim, strength, brick)
- AI coaching with 15 tools and tiered memory system
- HealthKit integration for Apple Watch data
- Sign in with Apple authentication
- 4 coaching personalities (Head Coach, Goggins, Hype, Custom)
