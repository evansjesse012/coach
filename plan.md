# Race Planning & Conditions Feature — Implementation Plan

## Overview

Transform the race detail view from a simple info card into a full **race planning hub** with structured planning sections, AI-generated race conditions, and live weather updates. All changes are in the single-file app (`app/page.jsx`) plus one new API route.

---

## Architecture Summary

- **Frontend**: All in `app/page.jsx` — new sections added to `GoalDetailView`, new fields in `EventModal`
- **AI Conditions**: Uses existing `/api/chat/route.js` (Claude API) to generate probable race conditions when a race is created/edited
- **Weather API**: New `/api/weather/route.js` endpoint that fetches forecast data as race day approaches (free OpenWeatherMap or Open-Meteo API — no key required for Open-Meteo)
- **Data**: Extends the existing event object schema stored in localStorage

---

## Data Schema Changes

Extend the event object with new fields:

```js
{
  // ...existing fields (name, date, location, url, racePlan, notes, etc.)

  // NEW: Official race website (already exists as `url`, we just make it more prominent)

  // NEW: AI-generated conditions analysis
  aiConditions: {
    summary: "",        // e.g. "Hot, hilly, coastal wind"
    terrain: "",        // e.g. "Rolling hills with a steep mile-6 climb"
    elevation: "",      // e.g. "~800ft total gain"
    climate: "",        // e.g. "Late June in Phoenix — expect 90°F+ at start"
    tips: [],           // ["Start conservative", "Extra electrolytes", ...]
    generatedAt: "",    // ISO timestamp
  },

  // NEW: Structured race plan sections (replaces single racePlan textarea)
  planSections: {
    strategy: "",       // Pacing strategy, race approach
    nutrition: {
      before: "",       // Pre-race nutrition (night before + morning of)
      during: "",       // During-race fueling plan
      after: "",        // Post-race recovery nutrition
    },
    gear: "",           // Kit, shoes, race-day gear checklist
    travel: "",         // Travel logistics, parking, packet pickup
    warmup: "",        // Pre-race warmup routine
  },

  // NEW: Weather data (auto-updated)
  weather: {
    forecast: null,     // { temp, feelsLike, humidity, wind, conditions, icon }
    updatedAt: "",      // ISO timestamp
  },
}
```

---

## Implementation Steps

### Step 1: Extend Event Schema & Migration (~15 min)

**File**: `app/page.jsx`

- Add default values for new fields when creating/loading events
- Migrate existing `racePlan` string into `planSections.strategy` for backward compat
- Ensure new fields persist through save/load cycle in localStorage

### Step 2: New Weather API Route (~20 min)

**File**: `app/api/weather/route.js` (new)

- Use **Open-Meteo API** (free, no API key needed)
- Accepts `lat`, `lon`, and `date` params
- If race is within 7 days: returns actual forecast data
- If race is further out: returns historical climate averages for that location/date
- Returns: `{ temp, feelsLike, humidity, wind, conditions, precipChance }`

### Step 3: AI Race Conditions Generator (~25 min)

**File**: `app/page.jsx`

- When a user saves a race with name + location + date + type, auto-call the existing `/api/chat` endpoint
- Prompt Claude with race details to generate probable conditions:
  - Terrain profile, elevation, typical weather for that date/location
  - Course-specific tips (e.g. "Boston is net downhill but has Heartbreak Hill at mile 20")
  - Known race characteristics for well-known races
- Display with a "sparkle" icon and subtle AI badge
- Add a "Regenerate" button to refresh
- Runs once on creation, stored in `aiConditions`

### Step 4: Restructured Race Plan UI (~30 min)

**File**: `app/page.jsx` — inside `GoalDetailView`

Replace the single race plan textarea with **tabbed/accordion sections**:

1. **Race Conditions** (AI-generated + weather)
   - AI conditions card (terrain, climate, tips) with sparkle icon
   - Live weather card (updates automatically within 7 days of race)
   - "Weather updates available X days before race" placeholder otherwise

2. **Race Website** (existing, made more prominent)
   - Moved up near the top, below hero section

3. **Strategy & Pacing**
   - Textarea for pacing plan, race approach

4. **Nutrition**
   - Three sub-sections: Before (night before + morning), During (fueling plan), After (recovery)
   - Each is a textarea

5. **Gear & Logistics**
   - Gear checklist textarea
   - Travel/logistics textarea (parking, packet pickup, hotel)

6. **Warmup**
   - Pre-race warmup routine textarea

7. **Notes** (existing, stays at bottom)

Each section is a collapsible card with a header icon. Sections show a dot indicator when they have content.

### Step 5: Weather Auto-Update Logic (~15 min)

**File**: `app/page.jsx`

- In `GoalDetailView`, add a `useEffect` that:
  - Checks if race has a location and date
  - If within 7 days: fetch weather forecast, update event
  - If within 14 days: show "forecast available soon" teaser
  - Throttle: only re-fetch if `weather.updatedAt` is >6 hours old
- Geocode location string to lat/lon using Open-Meteo's geocoding API (also free)

### Step 6: EventModal Updates (~15 min)

**File**: `app/page.jsx` — inside `EventModal`

- URL field already exists — ensure it's labeled "Official Race Website"
- After save: if race has name + location + date, trigger AI conditions generation
- Show a brief loading spinner while AI conditions generate
- No changes to the form fields themselves (planning sections are filled in the detail view, not the creation form)

### Step 7: Visual Polish (~15 min)

- AI conditions card: gradient background with sparkle icon, distinct from user-entered content
- Weather card: temperature in large font, conditions icon, wind/humidity in smaller text
- Section headers with icons: strategy (flag), nutrition (apple/utensils), gear (backpack), travel (map-pin), warmup (activity)
- Dot indicators on section headers when content exists
- Smooth expand/collapse animation on sections

---

## New Icons Needed

Add to existing `Icon` component:
- `sparkle` — for AI-generated content
- `thermometer` — for weather
- `utensils` — for nutrition
- `backpack` / `briefcase` — for gear
- `map-pin` — for travel (may already exist)
- `flag` — for strategy
- `cloud` — for weather conditions
- `droplets` — for humidity/rain

---

## API Flow

```
User creates race with name + location + date
  → POST /api/chat (Claude) → AI conditions analysis → saved to event.aiConditions

User opens race detail view (within 7 days of race)
  → GET /api/weather?lat=X&lon=Y&date=YYYY-MM-DD → weather forecast → saved to event.weather

User opens race detail view (>7 days out)
  → Show "Weather forecast available 7 days before race" placeholder
```

---

## File Change Summary

| File | Change |
|------|--------|
| `app/page.jsx` | Extend event schema, restructure `GoalDetailView` with planning sections, AI conditions UI, weather card, new icons, auto-generation logic |
| `app/api/weather/route.js` | **New** — proxy to Open-Meteo API for weather/geocoding |
| `app/api/chat/route.js` | No changes (reuse existing endpoint) |

---

## Key Design Decisions

1. **Open-Meteo over OpenWeatherMap** — no API key needed, free for all use
2. **AI conditions on creation, not on every view** — avoids unnecessary API calls; user can regenerate manually
3. **Structured plan sections vs. single textarea** — better organization while preserving the existing `racePlan` data via migration
4. **Collapsible sections** — keeps the detail view clean; users expand what they need
5. **Weather auto-refresh throttled to 6 hours** — balances freshness with API courtesy
