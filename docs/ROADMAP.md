# Roadmap

Phased plan from current state through daily personal use, native iOS, and potential multi-user product.

## Phase 0: Deploy (This Week)

**Goal:** Get the app running and start using it daily.

**Tasks:**
- Deploy CoachFinal.jsx to Vercel via v0.dev
- Set ANTHROPIC_API_KEY environment variable
- Add to iPhone home screen as PWA
- Add your 70.3 Cozumel goal (Sep 20, 2026)
- Log your first real workout

**Decision point:** None. Just do it.

**Risk:** localStorage loss on Safari. Acceptable for the first 2-4 weeks while you validate the app is worth building on. Don't accumulate months of data without Supabase.

---

## Phase 1: Data Persistence (Weeks 2-4)

**Goal:** Protect training data from browser storage loss.

**Tasks:**
- Set up Supabase project
- Run `schema.sql` then `rls.sql` in Supabase SQL editor
- Create a data layer module that abstracts storage:
  ```
  dataLayer.getWorkouts() → reads from Supabase (or localStorage as fallback)
  dataLayer.saveWorkout() → writes to Supabase
  ```
- Replace `db.get()`/`db.set()` calls in CoachFinal.jsx with data layer calls
- Migrate existing localStorage data to Supabase on first authenticated session
- Move coaching memory to Supabase (`coaching_memory` table or JSONB in `user_config`)

**Decision point:** Do you want multi-user auth now, or just use Supabase as a personal database with a hardcoded user ID? Personal database is faster to implement. Auth adds complexity but is required for Phase 5.

**Recommendation:** Add basic Supabase auth now. The schema already has auth triggers. It's 2-3 hours of work and saves you from retrofitting later.

---

## Phase 2: PWA Improvements (Weeks 3-6)

**Goal:** Make the PWA feel reliable and professional.

**Tasks:**
- Add a service worker for offline support (cache the app shell, serve stale data when offline)
- Add a web app manifest (`manifest.json`) with app icon, theme color, display mode
- Implement offline-first reads: load from local cache immediately, sync with Supabase in background
- Add basic error boundaries so the app doesn't white-screen on failures
- Fix the duplicate className bug on the streaming message div
- Refactor the theme system from mutable objects to React state or CSS custom properties

**Decision point:** Is the PWA good enough for daily use, or do you need to go native now?

If the PWA covers 90% of your needs (it probably will for everything except HealthKit), stay on PWA and move to Phase 3. Going native is a significant effort — don't do it until the PWA proves the concept.

---

## Phase 3: Extract Into Modules (Weeks 4-8)

**Goal:** Make the codebase maintainable for adding features.

The single file will be approaching 1000+ lines at this point. Extract into:

```
app/
  page.jsx               ← Thin root: layout, tabs, routing
  api/chat/route.js      ← API proxy (unchanged)
  components/
    HomeTab.jsx
    PlanTab.jsx
    LogTab.jsx
    LearnTab.jsx
    ChatTab.jsx
    Settings.jsx
    StrengthTracker.jsx
    QuickCapture.jsx
    EventModal.jsx
  lib/
    ai.js                ← callAI, runAgentLoop, extractMemory, typewriter
    tools.js             ← TOOLS array + executeTool
    data.js              ← Data layer (Supabase + localStorage fallback)
    memory.js            ← Memory load/save/merge
    theme.js             ← Theme system (refactored to CSS vars or state)
    constants.js         ← SPORT_META, EVENT_PRESETS, STRENGTH_TEMPLATES, EX
    personalities.js     ← PERSONALITIES object
```

**Rule:** Each component file should be importable and testable independently. The data layer should be the only thing that touches storage.

---

## Phase 4: AI Improvements (Ongoing, Weeks 4+)

**Goal:** Make the coaching genuinely better over time.

**Tasks (prioritized):**
1. **Periodization in system prompt** — Add 2-sentence descriptions of each training phase (Base, Build, Peak, Taper) so the AI gives phase-appropriate advice
2. **Adaptive training plans** — Replace `generateWeeklyPlan()` with a function that varies by phase, week number, and training load
3. **Proactive pattern cards** — Detect gaps (e.g., swim < 1x/week for 3 weeks) and surface them on the home screen without the user asking
4. **Swim-specific context** — Include pool dimensions (33-yard) and equipment in `get_athlete_profile` so the AI can plan swim sets properly
5. **Memory conflict resolution** — Update the extraction prompt to explicitly handle conflicting information (e.g., injury status changes)
6. **Deterministic memory sampling** — Replace `Math.random() > 0.55` with a counter-based approach so extraction doesn't randomly skip 5 conversations in a row

**Decision point:** Each of these is independent. Do them as you notice gaps in coaching quality during daily use. The best improvements come from using the app and noticing where the AI fails.

---

## Phase 5: Native iOS (Weeks 8-16)

**Goal:** Real HealthKit integration and native app experience.

**Prerequisites:** Supabase backend (Phase 1), modular codebase (Phase 3).

**Tasks:**
- Set up Expo project with Expo Router
- Port components from React web to React Native (mostly style changes — inline styles map well to React Native StyleSheet)
- Wire up `_layout.jsx` and `auth.jsx` (already designed in the codebase)
- Implement real HealthKit integration:
  - Read workouts on app open
  - Deduplicate against existing sessions (using `external_id` in the schema)
  - Add a `get_health_data` tool so the AI can access HealthKit metrics
- Submit to TestFlight for personal use
- Add push notifications for daily coaching reminders (APNs via Expo)

**Decision point:** Do you need App Store distribution or is TestFlight sufficient?

For personal use + sharing with a few training partners, TestFlight is enough and avoids the App Store review process. You need App Store only if you're going multi-user public (Phase 6).

**Major risk:** React Native + HealthKit requires the `react-native-health` package, which needs a custom dev client (not Expo Go). Plan for this — it adds build complexity.

---

## Phase 6: Multi-User Product (If/When You Decide)

**Goal:** Other athletes can use Coach with their own data and coaching.

**Prerequisites:** Everything in Phases 1-5.

**Tasks:**
- Generalize the system prompt (remove hardcoded "Jesse" references)
- Move athlete profile data to the `profiles` table (the schema already supports this)
- Build an onboarding flow that populates the profile (race, goals, fitness baseline)
- RLS policies are already written — they enforce user isolation at the database level
- Add Stripe for billing (if you want to charge)
- Add usage tracking per user (API calls, token counts) for cost management
- Consider using claude-haiku-4-5-20251001 for routine operations (push messages, memory extraction) and Sonnet for coaching chat — reduces per-user costs by ~5x

**Decision point:** Is this a product or a personal tool?

This decision changes everything: branding, pricing, support, feature priorities, legal (terms of service, privacy policy, HIPAA considerations if you store health data). Don't build for multi-user until you've used the app yourself for 3+ months and genuinely believe other people would pay for it.

---

## Timeline Summary

| Phase | Timeframe | Effort | Depends On |
|-------|-----------|--------|------------|
| 0: Deploy | This week | 1 hour | Nothing |
| 1: Supabase | Weeks 2-4 | 8-12 hours | Phase 0 |
| 2: PWA fixes | Weeks 3-6 | 6-10 hours | Phase 0 |
| 3: Extract modules | Weeks 4-8 | 8-12 hours | Phase 1 |
| 4: AI improvements | Ongoing | 2-4 hours each | Phase 0 |
| 5: Native iOS | Weeks 8-16 | 40-60 hours | Phases 1, 3 |
| 6: Multi-user | TBD | 40+ hours | Phases 1-5 |
