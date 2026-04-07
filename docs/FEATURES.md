# Features

How each feature works under the hood.

## Training Plan Creation

**How it starts:** User goes to Plan tab -> "Build my plan" -> selects a goal -> confirms. This opens the `PlanBuilderSheet` in create mode.

**What the AI does:**
1. Silently gathers data (get_goals, get_athlete_profile, get_workouts, get_training_stats, get_plan_history)
2. Checks past plans — if prior plans exist, references adherence patterns and why they ended
3. Presents an assessment of the athlete's current state
4. Proposes a phased plan with rationale
5. Asks only questions the data can't answer (max 5)
6. On confirmation, calls `save_training_plan` then `save_weekly_plan` for week 1

**Phase design:** Each phase includes progression model (linear/step/wave), success criteria (3-5 measurable markers), rules (hard constraints), and strength protocol (focus, rep range, key exercises). Phase advancement is based on readiness, not just calendar.

**Prompt:** `buildPlanBuilderPrompt(goal, 'create')` — separate from the main coaching chat. The plan builder has its own message chain so it doesn't pollute the coach conversation.

**Storage:** `coach_training_plan` in localStorage. Contains phases array, weeklyPlans keyed by week number, currentWeek, currentPhase.

## Weekly Plan Generation

**How it starts:** User taps "Generate this week" on the Plan tab, or the plan builder auto-generates week 1 after creating a plan.

**What the AI does:**
1. Calls `get_week_review(includeMultiWeek=true)` to see last week's adherence
2. Calls `get_training_plan` to see current phase
3. Adapts the new week based on what actually happened — doesn't just repeat the template
4. Calls `save_weekly_plan` with sessions for Mon-Sun

**Each session includes:**
- type, label, duration, zone, targetIntensity
- purpose: why this session matters (what adaptation it builds)
- workout: the actual workout to follow (intervals, sets/reps, paces)
- notes: modification guidance (what to adjust if fatigued/time-crunched/feeling great)
- fuel: pre/during/post nutrition
- priority: red (cannot skip) or yellow (flexible)
- exercises: full exercise array for strength sessions

**Prompt:** `buildPlanBuilderPrompt(goal, 'week')`

## Prescribed vs Actual Tracking

**How adherence is computed:** `computeWeekAdherence()` runs on demand — not stored. For each prescribed session in a week, it:
1. Computes the date for that day from the plan's start date
2. Finds logged workouts on that date (cardio by sport, strength by session name)
3. Classifies: completed (>=80% duration), shortened (<80%), substituted (different sport), missed (no match)

**Multi-week patterns:** `computeMultiWeekPatterns()` looks back 4 weeks and detects:
- Sport-specific miss patterns ("swim missed in 3 of 4 weeks")
- Adherence trends ("adherence declining: 90% -> 65%")

**Where it shows:** Plan tab (adherence bar per week, pattern warnings), get_week_review tool (AI reads it before generating next week).

## Coaching Memory

**When it updates:** After every coaching conversation, `extractMemory()` fires in the background. It sends the last 8 messages to Claude with the `MEMORY_EXTRACTION_PROMPT`, which classifies facts into tiers.

**Tier structure:**
- Permanent: equipment, facilities, schedule, medical history, dietary constraints, communication preferences, safety rules — never pruned
- Benchmarks: FTP, threshold pace, CSS — append-only, update by metric
- Injuries: full history per body area — never deleted, status updates over time
- Observations: patterns, motivators, coaching notes — fuzzy dedup, no caps
- Response profile: how the athlete responds to training — populated from conversation evidence
- Conversation summaries: last 30 verbatim, older compressed into period summaries

**How the coach uses it:** Calls `get_athlete_profile` which returns the full coaching record. The system prompt tells the coach to check safety rules before prescribing, check the response profile to adapt coaching style, and check injuries for severity-based modifications.

**AthleteProfilePage:** Shows all tiers in 6 sections (Setup, Benchmarks, Injuries, Patterns, Response Profile, Coaching History). The "Tell your coach more" chat lets the athlete share info that gets extracted into memory.

## Race Conditions

**How they're generated:** `generateRaceConditions(event)` sends the race name, type, location, and date to Claude with a prompt asking for terrain analysis, elevation profile, expected climate, and 3-5 practical tips. Returns JSON with summary, terrain, elevation, climate, and tips.

**For well-known races** (Boston Marathon, Ironman Kona, etc.) Claude includes course-specific details. For lesser-known races, it provides general analysis based on location and time of year.

**Weather data:** The GoalDetailView also fetches weather via `/api/weather` which proxies to Open-Meteo. If the race is within 16 days, it returns a forecast. Otherwise, it returns climate averages for that location and time of year.

**Storage:** Conditions are stored on the event object in `coach_events`. Weather is fetched fresh each time the goal detail view opens.

## Strength Training

**How workouts are prescribed:** The AI coach includes an `exercises` array in strength sessions within the weekly plan. Each exercise has a name, exerciseType (weighted/bodyweight/banded/timed/cardio-drill), sets, reps/duration/weight/band, rest time, and notes. The coach can prescribe ANY exercise — there is no fixed library.

**How workouts are tracked:** User taps "Start" on a strength session -> opens `StrengthTracker`. The tracker initializes from the prescribed exercises array. UI adapts per exercise type:
- Weighted: weight input + reps input
- Bodyweight: reps input only
- Banded: band selector (light/medium/heavy) + reps input
- Timed: duration input (seconds)
- Cardio-drill: reps input

Each set has a completion button that triggers a rest timer (duration from the exercise's rest field). Previous performance is shown from strength history (matched by exercise name slug).

**PR detection:** On workout completion, each exercise is checked against stored PRs:
- Weighted: estimated 1RM via Epley formula
- Bodyweight/banded/cardio-drill: max reps
- Timed: longest duration

New PRs are highlighted in the summary. PR history is preserved (previous bests stored in a history array) for progression tracking.

**Exercise history:** Log tab has a Workouts/Exercises toggle. Exercise view shows all unique exercises with PR, last performed date, and session count. Tapping an exercise opens `ExerciseDetailSheet` with full history, PR progression timeline, and session-by-session breakdown.

**Backward compatibility:** Old strength data with templateId/exerciseId format still works. Adherence matching falls back to templateId when session label doesn't match. PR keys auto-migrate from old exerciseId format to slug format on app load.

## Plan Archiving

**When it happens:** User taps "End training plan" at the bottom of the Plan tab.

**Flow:**
1. `EndPlanSheet` opens showing plan summary (name, week progress, overall adherence %)
2. User selects reason: completed, switching goals, injury, not working, life, other
3. Optional notes field for context
4. On confirm: full plan archived to `coach_plan_history` with per-week adherence breakdown, missed-by-type stats, phases completed

**What gets saved:** The archive includes the plan structure, all computed adherence data, reason, notes, and dates. A coaching note is written to memory (e.g., "Plan ended: 70.3 Virginia (8/16 weeks, 74% adherence). Reason: Injury.").

**How it's used later:** When the coach builds a new plan, it calls `get_plan_history` and references past patterns: "Last plan you averaged 74% adherence with swim being the most missed — let's structure this differently."

## Daily Push Message

**How it's generated:** `generatePushMessage()` is called on app open (or manual refresh). It gathers the current plan, recent workouts (7 days), stats (2 weeks), and goals, then sends them to Claude with a prompt requesting a brief coaching note.

**Format:** Bold summary line, then 2-3 short paragraphs comparing prescribed vs actual, noting one pattern, and suggesting one action. Styled with the active coaching personality (normal, Goggins, hype coach, custom).

**Storage:** `coach_push_message` in localStorage. Refreshed on demand, not on a schedule (no actual push notifications yet).

## Coaching Personalities

Four modes that change the coach's communication style:

- **Head Coach (normal):** Professional, data-backed, direct. Acknowledges wins and gaps equally.
- **Goggins Mode:** Brutal accountability. "You chose comfort over growth."
- **Hype Coach:** Positive energy grounded in real data. "That Thursday ride was your longest in 3 weeks!"
- **Custom:** Athlete describes their preferred style; coach matches it.

The personality is injected via `getPersonalityPrompt()` at the top of the system prompt. It affects tone only — the coaching logic (safety, adherence, session prescription) is the same regardless of personality.

## Safety Protocol

**Universal rules (always active):**
- Fever or illness -> complete rest
- Sharp joint pain -> stop, modify, suggest medical review
- Chest pain or dizziness -> stop immediately
- Sleep < 5 hours -> easy day only, no intensity

**Athlete-specific rules:** Stored in `permanent.safetyRules` in the coaching record. Non-negotiable. Examples: "shoulder band activation before every swim" (reason: history of impingement).

**Injury-aware prescription:** The coach checks the injuries array before prescribing. Severity determines response: severe -> substitute with safe activities, moderate -> modify per modifications list, mild -> proceed with awareness.

## Context-Calibrated Response

The system prompt teaches the coach to match tool usage to request complexity:

- **QUICK (no tools):** Greetings, motivation, general knowledge, follow-ups
- **LIGHT (1-2 tools):** Log a workout, check today's plan, quick stat check
- **MODERATE (2-3 tools):** "How am I doing?", injury discussion, coaching advice
- **FULL (4+ tools):** Weekly plan generation, plan creation, major adjustments

This prevents the coach from calling 4 tools just to respond to "good morning."

## Nutrition Tracking

**Logging:** The coach or user logs meals via `log_nutrition` with fields: meal description (in their words), timing (pre/during/post/general), related workout, date.

**Coaching approach:** The system prompt says "Do NOT estimate macros or calories. Coach on fueling timing and composition relative to training demands." The coach focuses on pre/during/post workout nutrition rather than daily diet tracking.

**In session prescriptions:** Every prescribed session includes a `fuel` object with pre, during, and post recommendations specific to that workout.

## Quick Capture

**How it works:** User types freeform workout text (e.g., "ran 5 miles easy", "45 min swim") into the quick capture input. `parseQuickCapture()` sends it to Claude to parse into structured JSON (sport, duration, notes, date). If duration needs to be inferred from distance + pace, Claude estimates it.

## Brick Workouts

**What they are:** Multi-sport sessions linking two cardio workouts (bike->run, swim->bike) with transition time and notes.

**Auto-detection:** When a workout is logged, the app checks if there's another workout of a different sport logged on the same day. If so, it prompts the user to link them as a brick.

**In plans:** The AI prescribes bricks using `type:'brick'` with a `legs` array. Each leg has sport, duration, zone, workout detail, and notes.

**Storage:** `coach_bricks` — lightweight link objects with leg workout IDs, transition time, and notes.
