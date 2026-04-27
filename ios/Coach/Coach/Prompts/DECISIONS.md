# Coach AI prompt — architectural decisions

Captured before any prompt rewriting, so future contributors understand the
choices baked into the file structure and the assembled output.

## 1 — One mega-prompt with internal goal-routing
Not user-selected specialty modes. Hybrid athletes are core, not edge. The
coach infers the primary lens (endurance / hypertrophy / strength / fat
loss / hybrid / general fitness) from the athlete's data and the
conversation, not from a settings toggle.

## 2 — Static cacheable block + dynamic per-turn Coach State Pack
Today's date, persona content, recovery picture, and athlete summary live
in a dynamic block rendered every turn. The static block is byte-identical
across turns so Anthropic prompt caching fires (~10% pricing on cached
input). Switching personas or refreshing recovery state must NOT
invalidate the static cache.

## 3 — Persona is voice/register only, never programming
A Goggins-flavored marathon plan is the same plan as a Normal-flavored
one. Persona modulates how the coach delivers a recommendation; it never
changes the recommendation itself. Voice and prescription are
independent axes.

## 4 — Tool argument shapes move out of the prompt into the tools array
JSON shapes for tool inputs live on the `description` fields of each
tool definition and its `input_schema.properties`. The prompt only
documents invariants the schema can't express (e.g. cross-tool ordering,
when NOT to call a tool, multi-step workflows).

## 5 — Recovery picture is delivered as prose narrative, not threshold bands
App-side Swift code generates a paragraph-shaped narrative from
HealthKit data. The prompt reasons from the narrative the way a real
coach reasons from a story — acute vs chronic framing, load context,
data-vs-athlete tension. Not a lookup table of "if HRV < X then Y".

## 6 — Memory writes carry confidence / source / stability
Every memory mutation includes:

- `confidence`: low / medium / high — how certain the coach is.
- `source`: explicit_user_statement / repeated_behavior / coach_inference.
- `stability`: permanent / recurring / temporary — how durable the fact is.

Pattern threshold for memorization is **3 observations** of the same
behavior before it earns a permanent slot. Single occurrences become
temporary observations, not facts.

## 7 — Disagreement posture
- **Hold the line on safety / effort.** No negotiation on chest pain
  protocols, fever rules, hard-stop conditions, or the principle that
  recovery is part of the work.
- **Fold immediately on schedule / equipment.** Athlete says they can't
  train Tuesday, the coach moves the session. The athlete owns their
  calendar and equipment access; the coach owns the prescription within
  those constraints.
- **Engage-then-fold on plan philosophy.** Coach states their reasoning
  once if the athlete pushes back on a periodization choice or training
  approach, then accommodates the athlete's preference. The athlete is
  the customer; persistent debate degrades trust.
