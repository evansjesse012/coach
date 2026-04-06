# Coaching Engine Redesign — Implementation Plan

Based on exhaustive audit of `app/page.jsx` (~2100 lines) as of commit `9a83961`.

---

## Current State Summary

**What exists:**
- 12 AI tools, agent loop with tool extraction, 3 system prompts
- Data: cardio (sport/duration/notes/date), strength (sets/reps/weight), events (goals/races/PRs with tri splits), bricks (linked workouts), nutrition (meal/timing), training plan (phases + weekly sessions), coaching memory (profile/physical/behavioral/coaching/summaries)
- Persistence: all localStorage via `db.get`/`db.set`, memory via dedicated `loadMemory`/`saveMemory`
- UI: 5 tabs (Home, Goals, Plan, Log, Coach), PlanBuilderSheet, AthleteProfilePage, WorkoutDetailSheet, BrickDetailSheet

**What's missing for real coaching:**
1. No prescribed-vs-actual tracking (the most critical gap)
2. No workout intensity/zones — just duration and notes
3. Memory prunes critical long-term facts (capped at 10-12 items)
4. No session-level specificity in prescriptions (no warm-up/main set/cool-down structure)
5. No safety rules system
6. No athlete response profiling (volume vs intensity responder, recovery rate)
7. Phases lack dependency logic, success criteria, and progression models
8. No constraint propagation when disruptions happen
9. Plan builder prompt is triathlon-specific, not sport-agnostic

---

## Step 1: Tiered Coaching Record (Memory Redesign)

### What changes and why
The current memory system caps arrays at 10-12 items and treats everything equally. A real coach never forgets that an athlete has a recurring knee issue or only has pool access on weekdays. The memory needs two tiers: **permanent facts** that never get pruned, and **rotating observations** that can.

### Data model changes

```javascript
// Replace defaultMemory() shape:
coachingRecord = {
  // TIER 1: PERMANENT — never pruned, only updated
  permanent: {
    equipment: [],            // ["Wahoo Kickr", "25yd pool", "road bike"]
    facilities: [],           // ["YMCA pool (M-F 6-8am)", "home gym"]
    schedule: {
      availableDays: 5,
      preferredTimes: "",     // "mornings weekdays, long sessions weekends"
      constraints: []         // ["travels for work 1 week/month", "kids Tue/Thu evenings"]
    },
    medicalHistory: [],       // ["asthma — uses inhaler pre-exercise", "ACL repair 2019 left knee"]
    dietaryConstraints: [],   // ["lactose intolerant", "vegetarian"]
    communicationPrefs: "",   // "direct, data-driven, no fluff"
    safetyRules: [            // athlete-specific, never pruned
      // { rule: "shoulder band activation before every swim", reason: "history of impingement", addedDate: "2026-03-15" }
    ]
  },

  // TIER 1.5: BENCHMARKS — tested values with dates, append-only
  benchmarks: [
    // { metric: "FTP", value: "180W", testDate: "2026-03-01", method: "20min test" }
    // { metric: "threshold pace", value: "8:30/mi", testDate: "2026-02-15", method: "3mi time trial" }
    // { metric: "CSS", value: "1:50/100yd", testDate: "2026-03-10", method: "400+200 test" }
  ],

  // TIER 1.5: INJURY HISTORY — never pruned, statuses update
  injuries: [
    // { id: "inj_xx", area: "left knee", status: "monitoring"|"active"|"resolved",
    //   severity: 3,          // 0-10 scale
    //   firstReported: "2026-03-15",
    //   lastUpdated: "2026-04-01",
    //   triggers: "long runs over 7 miles, downhill",
    //   safeActivities: "swimming, cycling, flat running under 5mi",
    //   modifications: "no downhill repeats, ice after runs over 45min",
    //   returnCriteria: "3 consecutive pain-free runs at 45min",
    //   history: [
    //     { date: "2026-03-15", note: "first reported tightness after long run" },
    //     { date: "2026-03-22", note: "still present, reduced run volume" },
    //     { date: "2026-04-01", note: "improving, foam rolling helping" }
    //   ]
    // }
  ],

  // TIER 2: ROTATING OBSERVATIONS — pruned to limits
  observations: {
    patterns: [],             // max 15, behavioral observations
    motivators: [],           // max 8
    consistency: "",
    currentFocus: "",
    openItems: [],            // max 10
    coachingNotes: [],        // max 15, recent coaching insights
  },

  // TIER 2: ATHLETE RESPONSE PROFILE — built over time
  responseProfile: {
    volumeVsIntensity: "",    // "responds better to volume" | "needs intensity" | "unknown"
    recoveryRate: "",         // "fast" | "average" | "slow" | "unknown"
    easyDayDiscipline: "",    // "runs easy days too fast" | "good" | "unknown"
    sessionPreferences: "",   // "prefers variety" | "likes routine" | "unknown"
    skipPatterns: [],         // ["skips swim when tired", "avoids evening sessions"]
    communicationNeeds: "",   // "needs data and rationale" | "needs encouragement"
  },

  // TIER 2: CONVERSATION SUMMARIES — rolling window of 15
  conversationSummaries: [],

  lastUpdated: ""
}
```

### Prompt changes
Update `MEMORY_EXTRACTION_PROMPT` to match new shape. Add instruction: "Classify extracted facts as permanent (equipment, medical, safety) or observation (patterns, notes). Permanent facts use the permanent/injuries/benchmarks sections. Observations use the observations section."

### Tool changes
- `get_athlete_profile` returns the full coaching record (both tiers)
- No new tools needed — the AI reads the whole record and reasons about it

### Persistence chain
- Same pattern: `loadMemory()` / `saveMemory()` / `mergeMemory()`
- `mergeMemory` updated: permanent tier merges additively (never prunes), observation tier prunes as before but with higher caps (15 patterns, 15 notes)
- Migration: on first load, if old memory shape detected, migrate to new shape (move injuries from `physical.injuries` to `coachingRecord.injuries`, move equipment string to `permanent.equipment` array, etc.)

### How to test
- Load seed data, verify profile page shows tiered data
- Chat "I just bought a Garmin watch" → verify it persists in permanent.equipment
- Chat 20+ times → verify permanent facts survive while observations rotate
- Works for any sport: marathon runner's permanent facts (shoes, watch, gym) are the same structure as a powerlifter's (belt, wraps, gym access)

### Implementation prompt

```
Read app/page.jsx fully. Find these sections:
- defaultMemory() at ~line 161
- mergeMemory() at ~line 164-179
- MEMORY_EXTRACTION_PROMPT at ~line 181-187
- loadMemory/saveMemory at ~line 162-163
- get_athlete_profile tool executor at ~line 270
- AthleteProfilePage component at ~line 623

Replace the memory system with a tiered coaching record:

1. Replace defaultMemory() with a new shape that has two tiers:
   - permanent: equipment[], facilities[], schedule{}, medicalHistory[], dietaryConstraints[], communicationPrefs, safetyRules[]
   - benchmarks: [{metric, value, testDate, method}]
   - injuries: [{id, area, status, severity(0-10), firstReported, lastUpdated, triggers, safeActivities, modifications, returnCriteria, history[{date,note}]}]
   - observations: {patterns[], motivators[], consistency, currentFocus, openItems[], coachingNotes[]}
   - responseProfile: {volumeVsIntensity, recoveryRate, easyDayDiscipline, sessionPreferences, skipPatterns[], communicationNeeds}
   - conversationSummaries: [] (keep 15)

2. Update mergeMemory():
   - permanent tier: arrays use additive merge (append new, never prune). Strings replace if non-empty.
   - benchmarks: append new entries (same metric updates existing if newer testDate)
   - injuries: merge by id or area. Update status/severity. Append to history array. Never delete.
   - observations tier: prune patterns to 15, coachingNotes to 15, motivators to 8, skipPatterns to 10
   - responseProfile: replace non-empty strings
   - conversationSummaries: keep last 15

3. Add migration in loadMemory(): if loaded memory has old shape (has physical.injuries, profile.equipment as string), transform to new shape. Map physical.injuries → injuries[], profile.equipment string → permanent.equipment array (split by comma), behavioral.patterns → observations.patterns, etc.

4. Update MEMORY_EXTRACTION_PROMPT to output the new shape. Add instruction: "Classify facts: equipment, medical history, facilities, safety rules → permanent section. Patterns, notes, observations → observations section. Benchmark test results → benchmarks. Injury updates → injuries with history entry."

5. Update AthleteProfilePage to render the new sections: Permanent Facts (equipment, facilities, schedule, medical), Benchmarks (table with metric/value/date), Injuries (with severity badge, history timeline), Response Profile (if any fields populated), Observations (patterns, focus, notes).

6. Do NOT change any other tools or components yet — get_athlete_profile already returns whatever loadMemory() returns, so downstream tools automatically get the new shape.

Test: Load seed data → verify migration works → verify profile page renders → chat to add new equipment → verify it persists in permanent tier → verify old observation data migrated correctly.
```

---

## Step 2: Prescribed-vs-Actual Feedback Loop

### What changes and why
This is the single most impactful change. Currently the AI prescribes sessions via `save_weekly_plan` and workouts are logged via `log_workout`, but there's no connection between them. A real coach's primary ongoing input is: what did I prescribe, and what actually happened? Without this, the AI can't detect missed sessions, can't see patterns in skipping, and can't adapt.

### Data model changes

```javascript
// New: weekly adherence record, computed on demand
weekAdherence = {
  weekNumber: 3,
  phase: 1,
  prescribed: [
    { day: "Monday", sessions: [{type:"strength", label:"Strength A", duration:45, priority:"red"}] },
    { day: "Tuesday", sessions: [{type:"run", label:"Easy Run", duration:45, priority:"red"}, {type:"swim", label:"Swim Drills", duration:30, priority:"yellow"}] },
    // ...
  ],
  actual: [
    { day: "Monday", completed: [{type:"strength", templateId:"str_a", duration:42, match:"full"}] },
    { day: "Tuesday", completed: [{type:"run", duration:40, match:"shortened"}, {type:"swim", duration:0, match:"missed"}] },
    // ...
  ],
  summary: {
    prescribedCount: 8,
    completedCount: 6,
    missedCount: 2,
    shortenedCount: 1,
    adherencePercent: 75,
    missedByType: { swim: 1, run: 0, bike: 0, strength: 0, brick: 1 },
    patterns: ["Missed swim for 3rd week in a row", "All priority sessions completed"]
  }
}
```

### Tool changes

New tool: `get_week_review`
```javascript
{ name: 'get_week_review',
  description: 'Compare prescribed training plan vs actual logged workouts for a specific week. Returns what was prescribed, what was completed, what was missed or shortened, and patterns across recent weeks. ALWAYS call this before generating next week\'s plan.',
  input_schema: {
    type: 'object',
    properties: {
      weekNumber: { type: 'number', description: 'Week to review. Default: last completed week.' },
      includeMultiWeek: { type: 'boolean', description: 'Include 4-week rolling pattern analysis. Default false.' }
    }
  }
}
```

### How executeTool computes it
The tool doesn't read a stored record — it computes adherence on demand by:
1. Getting `weeklyPlans[weekNumber].sessions` (prescribed)
2. Computing the date range for that week from `trainingPlan.startDate`
3. Filtering `cardio` and `strength` logs that fall in that date range
4. Matching logged workouts to prescribed sessions by sport/type and day
5. Categorizing each prescribed session as: completed (full match), shortened (logged but <80% duration), substituted (different sport logged), or missed (no match)
6. If `includeMultiWeek`: repeat for last 4 weeks, detect patterns ("swim missed 3 of 4 weeks")

### Prompt changes
Add to `buildSystemPrompt`:
```
- Before generating any weekly plan: ALWAYS call get_week_review first to see prescribed vs actual from last week
- If adherence < 80%: address it. Ask why, don't just re-prescribe the same thing.
- If a specific session type is consistently missed: restructure, don't just repeat
- If athlete is completing everything easily: consider progression
```

Add to `buildPlanBuilderPrompt` (week mode):
```
1. First call get_week_review(weekNumber=LAST_WEEK, includeMultiWeek=true) to see adherence
2. Then call get_training_plan to see current phase
3. Adapt this week based on what actually happened vs what was prescribed
```

### Persistence chain
No new persistence — computed from existing `trainingPlan.weeklyPlans` + `cardio` + `strengthHistory` on every tool call.

### How to test
- Create a plan with week 1 generated
- Log some but not all prescribed sessions
- Call get_week_review → verify it correctly identifies completed, missed, shortened
- Generate week 2 → verify AI references the adherence data
- Skip all swims for 3 weeks → verify pattern detection ("swim missed 3 of 4 weeks")
- Works for any sport: a marathon runner missing long runs triggers the same pattern detection as a triathlete missing swims

### Implementation prompt

```
Read app/page.jsx fully. Find:
- TOOLS array at ~line 190
- executeTool function at ~line 205
- buildSystemPrompt at ~line 309
- buildPlanBuilderPrompt (week mode) at ~line 355

Add a new tool `get_week_review` that computes prescribed-vs-actual adherence:

1. Add to TOOLS array after update_plan_progress:
   { name:'get_week_review', description:'Compare prescribed vs actual workouts for a week. Returns what was completed, missed, shortened, and multi-week patterns. ALWAYS call before generating next week\'s plan.', input_schema:{type:'object',properties:{weekNumber:{type:'number',description:'Week to review. Default: previous week.'},includeMultiWeek:{type:'boolean',description:'Include 4-week pattern analysis. Default false.'}}} }

2. Add case to executeTool. The logic:
   - Get trainingPlan from appState. If no plan, return error.
   - Default weekNumber to trainingPlan.currentWeek - 1 (last completed week)
   - Get weekPlan = trainingPlan.weeklyPlans[String(weekNumber)]
   - If no weekPlan generated, return "Week {n} was not generated."
   - Compute the Monday date of that week: startDate + (weekNumber-1)*7 days
   - For each day in weekPlan.sessions:
     - Compute the actual date for that day
     - Find cardio/strength logs matching that date
     - For each prescribed session: match by type/sport. Classify as:
       - "completed" if logged with >=80% of prescribed duration
       - "shortened" if logged but <80% duration
       - "substituted" if different sport logged that day
       - "missed" if no matching log
   - Compute summary: prescribedCount, completedCount, missedCount, adherencePercent, missedByType
   - If includeMultiWeek: repeat for last 4 weeks, find patterns (e.g., "swim missed 3/4 weeks")
   - Return JSON with prescribed array, actual array, and summary

3. Update buildSystemPrompt — add to the tool routing list:
   "- Before generating weekly plan: get_week_review(includeMultiWeek=true) to see adherence patterns"
   Add to TRAINING PLAN GENERATION section:
   "- ALWAYS review last week's adherence before prescribing next week. If adherence < 80%, address it — don't just repeat. If a session type is consistently missed, restructure rather than re-prescribe."

4. Update buildPlanBuilderPrompt (week mode) — change step 1 to:
   "1. First call get_week_review(weekNumber=PREVIOUS, includeMultiWeek=true) to see adherence"
   Then get_training_plan, then adapt.

Test: Load seed data, create a plan, generate week 1. Log some sessions but skip swims. Generate week 2 — the AI should reference the missed swims and adapt.
```

---

## Step 3: Enhanced Session Prescriptions

### What changes and why
Currently prescribed sessions are: `{type, label, duration, zone, targetIntensity, fuel, priority, notes}`. A real coach prescribes structured sessions with warm-up, main set, cool-down, and specific execution steps. The AI should output this by default.

### Data model changes

```javascript
// Enhanced session in weekly plan:
session = {
  type: 'run',
  label: 'Threshold Intervals',
  duration: 60,                    // total minutes
  zone: 'Z3-Z4',
  targetIntensity: '8:15-8:30/mi',
  priority: 'red',

  // NEW: structured execution
  structure: [
    { segment: 'Warm-up', duration: 15, description: '15min easy jog, building from walk to Z2' },
    { segment: 'Main set', duration: 30, description: '5x4min at threshold pace (8:15/mi) with 2min jog recovery' },
    { segment: 'Cool-down', duration: 15, description: '15min easy jog back to Z1, then stretch' }
  ],

  // NEW: the "why"
  purpose: 'Building lactate clearance capacity. This is the key workout of the week.',

  fuel: { pre: '...', during: '...', post: '...' },
  notes: 'If legs feel heavy from yesterday\'s ride, drop to 3 intervals.',
  templateId: null               // for strength sessions
}
```

### Prompt changes
Add to `buildSystemPrompt` TRAINING PLAN GENERATION section:
```
SESSION PRESCRIPTION FORMAT:
Every non-rest session must include a `structure` array with warm-up, main set, and cool-down segments. Each segment has: segment name, duration in minutes, and a specific description with target paces/watts/RPE.
Every session must include a `purpose` field — one sentence explaining what adaptation this session builds and why it matters this week.
The `notes` field should include modification guidance: what to do if the athlete is fatigued, time-crunched, or feeling great.
```

### Tool changes
Update `save_weekly_plan` input schema to include `structure` and `purpose` fields in session objects. These are optional in the schema (backward compatible) but the prompt demands them.

### UI changes
`WorkoutDetailSheet` and plan session cards show the structure when present: warm-up → main set → cool-down as distinct sections with duration bars.

### How to test
- Generate a new weekly plan → verify each session has structure array and purpose
- View a session in WorkoutDetailSheet → verify warm-up/main/cool-down display
- Works for strength too: warm-up sets → working sets → cool-down/mobility
- Works for swim: warm-up → drill set → main set → cool-down

### Implementation prompt

```
Read app/page.jsx fully. Find:
- save_weekly_plan tool definition at ~line 201
- buildSystemPrompt at ~line 309
- Session rendering in TrainingPlanTab at ~line 1125
- WorkoutDetailSheet component

Make these changes:

1. In buildSystemPrompt, add after "Every session prescription must include per-session nutrition":

"SESSION PRESCRIPTION FORMAT:
Every non-rest session must include a `structure` array with segments: [{segment:'Warm-up',duration:15,description:'...'},{segment:'Main set',duration:30,description:'...'},{segment:'Cool-down',duration:15,description:'...'}]. Each segment has specific targets (pace, watts, RPE, reps).
Every session must include a `purpose` field — one sentence on what adaptation this builds.
The `notes` field should include modification guidance for fatigue/time-crunch scenarios."

2. Do NOT change the save_weekly_plan tool schema — the structure and purpose fields are already accepted as part of the session object (it's type:'object' with no strict validation). The prompt change is sufficient to make the AI include them.

3. In TrainingPlanTab session rendering (~line 1125), after the notes display and before the fuel button, add:
   - If sess.purpose: show it in a muted italic line
   - If sess.structure: show a collapsible "Session plan ▼" button that expands to show segments as a vertical timeline (segment name in bold, duration, description)

4. In WorkoutDetailSheet, add a "Session Plan" section if the workout was from a plan session that had structure data. (This requires passing the plan session data through — for now, just add the UI for when structure data is present on the workout object itself.)

Test: Generate a weekly plan. Verify each session has structure and purpose in the saved data. View in Plan tab — verify the session plan expands. Verify strength sessions also get structure (warm-up sets, working sets, mobility).
```

---

## Step 4: Phase Intelligence

### What changes and why
Phases are currently calendar blocks with labels and an intensity ceiling string. A real coach's phases encode dependency logic (why this phase exists, what it earns), progression models (how volume changes week to week), and success criteria (how to know when to advance).

### Data model changes

```javascript
// Enhanced phase in training plan:
phase = {
  number: 1,
  name: 'Base + Structural Durability',
  startDate: '2026-04-07',
  endDate: '2026-05-31',
  weeks: 8,

  // EXISTING
  weeklyVolume: '5-7 hrs',
  intensityCeiling: 'Z2 only',
  intensityMix: '95% Z2, 5% strides',
  strengthFreq: '2x/week',
  focus: 'Build aerobic capacity and connective tissue durability',
  keySessionTypes: ['long ride', 'long run', 'swim technique', 'brick intro'],
  deloadWeek: 4,

  // NEW: dependency logic
  prerequisiteFor: 'Phase 2 threshold introduction requires aerobic base to absorb intensity',
  entryRequirements: 'Athlete can train 5 days/week consistently',

  // NEW: progression model
  progression: {
    model: 'linear',            // 'linear'|'step'|'wave'
    volumeProgression: '+10% per week, deload at week 4 to 70%',
    intensityProgression: 'Z2 only for first 6 weeks, introduce strides in week 7',
    strengthProgression: 'Hypertrophy rep range (8-12), increase weight when all sets completed'
  },

  // NEW: success criteria
  successCriteria: [
    'Complete 3 consecutive weeks at target volume without excessive fatigue',
    'Long ride reaches 2.5 hours at Z2',
    'Swim frequency consistently 3x/week',
    'No injury flare-ups from volume increase'
  ],

  // NEW: phase-specific rules
  rules: [
    'No intervals above Z2 except strides',
    'Brick runs capped at 20 minutes',
    'If missed more than 2 days in a week, extend phase by 1 week'
  ],

  // NEW: strength protocol for this phase
  strengthProtocol: {
    focus: 'hypertrophy + structural',
    repRange: '8-12',
    keyExercises: ['split squat', 'RDL', 'pull-up', 'pallof press'],
    notes: 'Building connective tissue tolerance. Keep loads moderate, focus on form.'
  }
}
```

### Prompt changes
Update `buildPlanBuilderPrompt` (create mode) to require these fields when generating phases. Add:
```
Each phase must include:
- prerequisiteFor: what the next phase requires that this one builds
- progression: {model, volumeProgression, intensityProgression, strengthProgression}
- successCriteria: 3-5 measurable criteria for phase completion
- rules: phase-specific hard constraints
- strengthProtocol: {focus, repRange, keyExercises, notes}
```

### Tool changes
No schema changes needed — `save_training_plan` already accepts arbitrary phase fields.

### How to test
- Create a new plan → verify phases have all new fields
- View phase details in Plan tab → verify expanded view shows criteria, progression, rules
- Works for marathon: phases have running-specific progression (mileage, long run distance)
- Works for powerlifting: phases have lift-specific progression (load %, rep schemes)

### Implementation prompt

```
Read app/page.jsx fully. Find:
- buildPlanBuilderPrompt (create mode) at ~line 370
- Phase rendering in TrainingPlanTab at ~line 1200
- Phase detail expansion at ~line 1222

1. In buildPlanBuilderPrompt (create mode), add to the RULES section:

"Each phase must include these fields:
- prerequisiteFor: what the next phase requires that this one creates
- progression: {model:'linear'|'step'|'wave', volumeProgression:'how volume changes week to week', intensityProgression:'when/how intensity increases', strengthProgression:'rep scheme and load changes'}
- successCriteria: array of 3-5 measurable criteria for when this phase is complete
- rules: array of hard constraints for this phase (intensity ceiling enforcement, volume caps, etc)
- strengthProtocol: {focus:'hypertrophy'|'strength'|'maintenance', repRange, keyExercises[], notes}
Phase advancement should be based on readiness (success criteria met), not just calendar."

2. In TrainingPlanTab phase expansion (the expandedPhase section), add after the existing pills (intensityCeiling, strengthFreq, deloadWeek):
   - If ph.successCriteria: render as a checklist with empty circles
   - If ph.progression: show volumeProgression and intensityProgression as mono text
   - If ph.rules: show as muted bullet list
   - If ph.strengthProtocol: show focus + rep range as pills, key exercises as text

3. Do NOT change the save_training_plan tool schema — these fields pass through as arbitrary properties on phase objects.

Test: Create a plan. Verify phases have progression models, success criteria, and rules. Expand a phase in the UI — verify all new fields render. Verify it works for non-triathlon goals too.
```

---

## Step 5: Sport-Agnostic Coaching Engine

### What changes and why
The system prompt and plan builder prompt are currently triathlon-focused ("bike→run bricks", "swim frequency", "earn intensity"). The coaching principles (periodization, progression, recovery, individualization) are universal. The prompts need to teach the AI the framework and let it adapt to the sport, not hardcode triathlon specifics.

### Prompt changes

Replace the sport-specific sections of `buildSystemPrompt` with sport-agnostic coaching principles:

```
COACHING FRAMEWORK:
You coach by these principles regardless of the athlete's sport or goal:

1. ENDPOINT FIRST: Everything works backward from race/goal day. What does the athlete need to be able to do? What are the physical demands?

2. CURRENT STATE: Where is the athlete right now? Fitness, injury history, life stress, recovery capacity, strengths, limiters. The gap between current state and endpoint is the work.

3. DEPENDENCY CHAIN: Adaptations have prerequisites. You can't do VO2 work safely without an aerobic base. You can't taper if you haven't built fitness to preserve. Each phase earns the right to enter the next.

4. WEEKLY DECISION: "Given where this athlete is right now, what is the most valuable thing they can do today to move toward the endpoint, without creating more risk than benefit?"

5. ADJUSTMENT LOOP: The plan is a hypothesis. Prescribed vs actual is the feedback. If adherence < 80%, diagnose why before re-prescribing. If a session type is consistently missed, restructure. If the athlete is ahead, cautiously progress.

6. PROTECTION: Pain above threshold → modify. Illness → rest. Sleep deprivation → reduce intensity. These override the plan.

PERIODIZATION:
Choose the approach based on athlete, sport, and timeline:
- Linear blocks (20+ weeks, single peak): distinct phases with clear transitions
- Undulating (shorter timelines, multiple events): varies intensity within each week
- Block (experienced athletes, limited time): concentrated blocks of single quality

For endurance: base → threshold → race-specific → taper. Earn intensity.
For strength: hypertrophy → max strength → peaking → deload/test.
For general fitness: flexible phases driven by evolving goals.

SPORT-SPECIFIC KNOWLEDGE:
Apply sport-specific knowledge when prescribing:
- Multi-sport (triathlon): manage three disciplines, brick workouts, transition practice, discipline-specific periodization within each phase
- Running (marathon, ultra, 5K-10K): mileage progression, long run as anchor, speed work timing, taper length scales with race distance
- Cycling: power-based training zones, indoor vs outdoor considerations, group ride integration
- Swimming: technique development alongside fitness, pool vs open water, CSS-based intervals
- Strength sports: movement quality, progressive overload, competition peaking, attempt selection
- General fitness: habit formation, variety for adherence, progressive challenge without burnout
```

### How to test
- Create a plan for a marathon goal → verify AI uses running-specific periodization
- Create a plan for a powerlifting goal → verify AI uses strength periodization
- Create a plan for "general fitness" → verify AI creates flexible programming
- Triathlon goals still get triathlon-specific coaching (bricks, multi-discipline)

### Implementation prompt

```
Read app/page.jsx. Find buildSystemPrompt at ~line 309.

Replace the TRAINING PLAN GENERATION, BRICK WORKOUTS, and NUTRITION COACHING sections with a sport-agnostic coaching framework. Keep the tool routing list and the conciseness instruction.

The new sections should be:

COACHING FRAMEWORK:
[The 6 principles from the plan above: endpoint first, current state, dependency chain, weekly decision, adjustment loop, protection]

PERIODIZATION:
[Linear blocks, undulating, block — when to use each. Sport-specific periodization patterns: endurance base→build→peak→taper, strength hypertrophy→max→peak, general fitness flexible phases]

SPORT-SPECIFIC KNOWLEDGE:
[Triathlon: multi-discipline + bricks + transitions. Running: mileage progression + long run anchor. Cycling: power zones + indoor/outdoor. Swimming: technique + CSS. Strength: progressive overload + peaking. General: habits + variety]

SESSION PRESCRIPTION:
[Every session needs structure array, purpose, fuel, modification notes. Priority red/yellow system. Session prescription format from Step 3]

NUTRITION COACHING:
[Keep existing nutrition section — it's already good and sport-agnostic]

SAFETY:
[Universal rules: illness → rest, pain → modify, sleep deprivation → reduce. Check athlete's safety rules from coaching record.]

Keep: tool routing list, "Be concise" instruction, today's date.
Remove: any triathlon-specific hardcoding that prevents the framework from adapting to other sports.

Test: Ask the coach for marathon advice → verify running-specific response. Ask for powerlifting advice → verify strength-specific. Ask triathlon question → still gets bricks and multi-discipline coaching. The AI should adapt its sport knowledge based on the athlete's goals, not because the prompt hardcodes it.
```

---

## Step 6: Safety Rules System

### What changes and why
Safety rules currently exist only as prose in the system prompt ("don't train through illness"). A real coach has both universal rules and athlete-specific rules that come from learning about this particular athlete. The coaching record (Step 1) already has a `safetyRules` array in the permanent tier. This step makes the AI read and follow those rules.

### Data model changes
Already handled in Step 1 (`permanent.safetyRules`). No additional data changes.

### Prompt changes
Add to `buildSystemPrompt`:
```
SAFETY PROTOCOL:
Before prescribing any session, check the athlete's safety rules (in their coaching record under permanent.safetyRules) and current injury state. Apply these in order:

Universal rules (always active):
- Fever or illness symptoms → complete rest, no exceptions
- Sharp joint pain → stop activity, modify plan, flag for medical review
- Chest pain/dizziness → stop immediately
- Sleep < 5 hours → easy day only, no intensity

Athlete-specific rules (from coaching record):
- Read permanent.safetyRules before every prescription
- These are non-negotiable — they exist because of this athlete's history

Injury-aware prescription:
- Check injuries array for any active/monitoring items
- If severity > 5: substitute activity (e.g., swim instead of run for knee)
- If severity 2-5: modify (reduce volume, avoid triggers listed in injury.triggers)
- If severity < 2: proceed with awareness, note in session notes
- Always respect injury.safeActivities and injury.modifications
```

### Tool changes
None. The AI reads safety rules from `get_athlete_profile` which returns the full coaching record.

### How to test
- Add a safety rule "shoulder band activation before every swim" to coaching record
- Generate a weekly plan → verify swim sessions mention the shoulder activation
- Log "my knee hurts, severity 6" → verify AI substitutes rather than modifying
- Say "I have a cold" → verify AI prescribes complete rest regardless of plan

### Implementation prompt

```
Read app/page.jsx. Find buildSystemPrompt at ~line 309.

Add a SAFETY PROTOCOL section (after the coaching framework, before the conciseness instruction):

"SAFETY PROTOCOL:
Before prescribing any session, check the athlete's coaching record for safety rules and injury state.

Universal rules (always active):
- Fever or illness → complete rest, no exceptions
- Sharp joint pain → stop, modify plan, suggest medical review
- Chest pain or dizziness → stop immediately
- Sleep < 5 hours → easy day only, no intensity work

Athlete-specific rules:
- Read permanent.safetyRules from get_athlete_profile before prescribing
- These are non-negotiable — they exist because of this athlete's history

Injury-aware prescription:
- Check injuries array. If any are active/monitoring:
  - severity > 5: substitute with safe activities from injury.safeActivities
  - severity 2-5: modify per injury.modifications, avoid injury.triggers
  - severity < 2: proceed with awareness
- Always note injury considerations in session notes"

Also add to the COACHING FRAMEWORK section under "PROTECTION":
"Check the athlete's safety rules (permanent.safetyRules) and injury state before every prescription. These override the plan."

Test: Add safety rule to seed data memory. Generate plan → verify rule is respected. Report an injury → verify AI modifies based on severity. Report illness → verify complete rest.
```

---

## Step 7: Context-Appropriate Pre-flight

### What changes and why
Currently every chat message runs through the same agent loop with the same system prompt. A question about stretching triggers the same tool-routing as generating a weekly plan. This wastes API calls and makes simple interactions slow.

### Prompt changes
Replace the tool routing list in `buildSystemPrompt` with a graduated system:

```
CONTEXT-CALIBRATED RESPONSE:
Match the depth of your response to what the athlete needs:

QUICK (no tools needed):
- Greetings, simple questions, motivation, general knowledge
- "What should I eat before a race?" → answer from coaching knowledge
- "Good morning" → brief, friendly

LIGHT (1-2 tool calls):
- "What should I do today?" → get_training_plan (today's sessions)
- "I just ran 45 min easy" → log_workout
- "I ate a protein bar" → log_nutrition
- Checking a specific stat → get_training_stats or get_workouts

MODERATE (2-3 tool calls):
- "How am I doing this week?" → get_training_stats + get_goals
- "My knee hurts" → get_athlete_profile (check injury history) + respond
- Coaching questions about training → get_athlete_profile + relevant data

FULL PRE-FLIGHT (4+ tool calls):
- Generating a weekly plan → get_week_review + get_training_plan + get_workouts + get_athlete_profile
- "Create a training plan" → full context gathering
- Major plan adjustments → everything

Do NOT call tools unnecessarily. If you can answer from context already in the conversation, do so.
```

### How to test
- Say "good morning" → verify no tool calls, quick response
- Say "I just ran 30 min" → verify only log_workout called
- Say "How am I doing?" → verify 2-3 tools called
- Say "Generate next week" → verify full pre-flight

### Implementation prompt

```
Read app/page.jsx. Find buildSystemPrompt at ~line 309, specifically the tool routing list that starts with "You have tools to access the athlete's complete training data."

Replace the bullet list of tool routing with a graduated CONTEXT-CALIBRATED RESPONSE section:

"Match your context-gathering to what the athlete needs:

QUICK (no tools): Greetings, motivation, general knowledge questions, simple follow-ups to previous messages. Answer directly.

LIGHT (1-2 tools): Logging a workout (log_workout), logging nutrition (log_nutrition), checking today's plan (get_training_plan), quick stat check (get_training_stats).

MODERATE (2-3 tools): "How am I doing?" (get_training_stats + get_goals), injury discussion (get_athlete_profile), coaching advice (get_athlete_profile + relevant data tool).

FULL (4+ tools): Weekly plan generation (get_week_review + get_training_plan + get_workouts + get_athlete_profile), plan creation, major adjustments.

Do NOT call tools unnecessarily. If the answer is in the current conversation context, respond directly."

Keep the existing TRAINING PLAN GENERATION, NUTRITION COACHING, and SAFETY PROTOCOL sections — they still apply when the AI does go deep. This change only affects the routing decision.

Test: "Good morning" → no tools, fast response. "Log 45 min run" → one tool call. "How's my training going?" → 2-3 tools. "Generate next week" → full pre-flight with get_week_review.
```

---

## Step 8: Athlete Response Profiling (Automatic)

### What changes and why
Step 1 created the `responseProfile` structure. This step makes the AI automatically populate it from observed data rather than requiring explicit input.

### Prompt changes
Add to `MEMORY_EXTRACTION_PROMPT`:
```
Also assess the athlete's response profile from the conversation:
- volumeVsIntensity: if conversation reveals preference or response to volume vs intensity
- recoveryRate: if athlete mentions fatigue duration or bounce-back from hard sessions
- easyDayDiscipline: if athlete's easy run/ride paces suggest running too hard
- skipPatterns: if athlete mentions skipping or avoiding certain sessions
- communicationNeeds: what kind of coaching response they respond to (data? encouragement? accountability?)

Only update fields where you have clear evidence. Use "unknown" for uncertain.
```

Also add to the weekly plan generation prompt:
```
Before prescribing, check the athlete's responseProfile:
- If volumeVsIntensity is "volume responder": favor more easy sessions over fewer hard ones
- If recoveryRate is "slow": add extra recovery between hard days
- If easyDayDiscipline shows they run easy days too fast: add explicit pace caps
- If skipPatterns shows they avoid certain sessions: consider restructuring those sessions to be more appealing or essential
```

### How to test
- Chat over several sessions with patterns (always mention being tired after intervals, consistently skip swims)
- Check coaching record → verify responseProfile fields populate
- Generate a plan → verify the AI adapts prescriptions based on the profile
- Works across sports: a runner who always runs easy days too fast gets pace caps, a lifter who skips accessories gets them restructured

### Implementation prompt

```
Read app/page.jsx. Find:
- MEMORY_EXTRACTION_PROMPT at ~line 181
- buildSystemPrompt at ~line 309

1. Update MEMORY_EXTRACTION_PROMPT to include responseProfile extraction. Add to the JSON structure:
   "responseProfile": {"volumeVsIntensity":"","recoveryRate":"","easyDayDiscipline":"","skipPatterns":[],"communicationNeeds":""}
   Add instruction: "Assess the athlete's response profile from conversation evidence. Only update fields with clear evidence. Examples: if athlete says 'I'm always wiped after intervals' → recoveryRate: 'slow after intensity'. If athlete consistently skips swim → skipPatterns: ['avoids swim sessions']."

2. Update mergeMemory to handle responseProfile: strings replace if non-empty, skipPatterns uses Set-based dedup with cap of 10.

3. Add to buildSystemPrompt after SAFETY PROTOCOL:
   "ATHLETE ADAPTATION:
   Check the athlete's responseProfile from get_athlete_profile:
   - volumeVsIntensity: favor volume or intensity based on response type
   - recoveryRate: space hard days accordingly
   - easyDayDiscipline: add pace caps if they run easy too fast
   - skipPatterns: restructure consistently skipped sessions
   - communicationNeeds: adapt your coaching delivery style"

Test: Have several conversations mentioning fatigue, skipped sessions, preferences. Verify responseProfile populates in coaching record. Generate a plan → verify AI references the profile in its reasoning.
```

---

## Implementation Order & Dependencies

```
Step 1: Tiered Coaching Record ← no dependencies, foundational
Step 2: Prescribed-vs-Actual   ← needs existing plan + workout data
Step 3: Enhanced Sessions       ← independent, prompt-only change
Step 4: Phase Intelligence      ← independent, prompt-only change
Step 5: Sport-Agnostic Engine   ← should follow Steps 3 & 4 (references their formats)
Step 6: Safety Rules            ← needs Step 1 (safetyRules in coaching record)
Step 7: Context Pre-flight      ← independent, prompt-only change
Step 8: Response Profiling      ← needs Step 1 (responseProfile structure)
```

**Recommended order:** 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8

Steps 3, 4, and 7 are prompt-only changes with no data model impact — fast to implement, easy to test, immediately valuable.

Step 1 is the most architecturally significant — it changes the memory system that everything reads from. Do it first, verify migration works, then build on it.

Step 2 is the highest-impact single change — prescribed-vs-actual is the missing feedback loop that makes coaching reactive instead of just prescriptive.

---

## What This Plan Does NOT Cover (By Design)

- Cloud storage / Supabase migration
- iOS native app / HealthKit integration
- Multi-user support
- Real-time biometric data (HRV, sleep)
- Workout intensity/zone capture (depends on HealthKit for real data)
- Progress visualization / charts
- Strava/Garmin import

These are all valuable but belong to different workstreams. This plan focuses exclusively on making the AI think and operate like a real coach within the existing single-user, localStorage, PWA architecture.
