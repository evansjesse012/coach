# Architecture

How the AI coaching system works, why decisions were made, and how to extend it.

## Overview

Coach uses an **agentic tool-use pattern** rather than context stuffing. Instead of cramming all training data into every system prompt, the AI has tools it can call to fetch exactly the data it needs. The system prompt stays at ~300 tokens regardless of how much training data exists.

This was a deliberate architectural choice. Context stuffing works fine for a few weeks of data, but after 6 months of daily training logs, you'd be sending 3000+ tokens of context on every message — most of it irrelevant to the actual question. Tool use scales to years of data with constant prompt size.

## The Agent Loop

The core of the AI system. It handles multi-step tool use: the AI requests data, we execute the tool locally in the browser, send the result back, and repeat until the AI produces a final text response.

```javascript
async function runAgentLoop({ personality, customText, messages, appState, callAI, maxRounds=5 }) {
  let chain=[...messages]; let toolCallCount=0; const workoutsLogged=[];
  for (let round=0; round<maxRounds; round++) {
    const resp=await callAI({
      system: buildSystemPrompt(personality, customText),
      messages: chain,
      tools: TOOLS,
      tool_choice: {type:'auto'},
      max_tokens: 1024
    });

    // Final text response — we're done
    if (resp.stop_reason==='end_turn') {
      return {
        response: resp.content?.filter(b=>b.type==='text')?.map(b=>b.text)?.join('')?.trim() || '',
        workoutsLogged,
        toolCallCount
      };
    }

    // Tool use — execute tools and continue the loop
    if (resp.stop_reason==='tool_use') {
      const toolUses = resp.content?.filter(b=>b.type==='tool_use') || [];
      const toolResults = toolUses.map(tu => {
        toolCallCount++;
        const result = executeTool(tu.name, tu.input, appState);

        // Special handling: extract logged workouts from log_workout calls
        if (tu.name==='log_workout') {
          try {
            const p = JSON.parse(result);
            if (p.logged && p.workout) workoutsLogged.push(p.workout);
          } catch {}
        }

        return { type:'tool_result', tool_use_id:tu.id, content:result };
      });

      // Append the AI's tool request + our results to the conversation chain
      chain = [
        ...chain,
        { role:'assistant', content:resp.content },
        { role:'user',      content:toolResults }
      ];
      continue;
    }
  }
  return { response:'I needed more context. Try asking again.', workoutsLogged, toolCallCount };
}
```

Key design decisions:

- **maxRounds=5** prevents runaway tool loops. In practice, most conversations use 1-3 rounds. The push message (which gathers 4 datasets) uses maxRounds=4.
- **Tool execution is local.** `executeTool()` runs in the browser against localStorage data. No network call. The only network call is to the Anthropic API.
- **Workout logging is extracted** from `log_workout` tool results so the caller can update React state and show confirmation UI.
- **The conversation chain grows** with tool calls. Each round adds an assistant turn (with tool_use blocks) and a user turn (with tool_result blocks). The AI sees its previous tool calls and results, which helps it decide whether it needs more data.

## Tool Definitions

Seven tools that give the AI access to all training data:

```javascript
const TOOLS = [
  { name:'get_workouts',
    description:'Get workout history filtered by sport and date range.',
    input_schema:{type:'object',
      properties:{
        sport:{type:'string',enum:['run','bike','swim','strength','brick','hike','other','all']},
        days:{type:'number'},
        limit:{type:'number'}
      },
      required:['sport']}
  },
  { name:'get_training_plan',
    description:"Get this week's training plan with completion status.",
    input_schema:{type:'object',properties:{}}
  },
  { name:'get_training_stats',
    description:'Get computed training stats: weekly volume, trends, consistency.',
    input_schema:{type:'object',properties:{weeks:{type:'number'}}}
  },
  { name:'get_personal_records',
    description:'Get personal records for exercises.',
    input_schema:{type:'object',properties:{exercise:{type:'string'}}}
  },
  { name:'get_goals',
    description:'Get active training goals with days remaining.',
    input_schema:{type:'object',properties:{include_completed:{type:'boolean'}}}
  },
  { name:'get_athlete_profile',
    description:"Get coaching memory — accumulated facts about the athlete.",
    input_schema:{type:'object',properties:{}}
  },
  { name:'log_workout',
    description:'Log a completed workout. Only use when athlete explicitly describes something they just completed.',
    input_schema:{type:'object',
      properties:{
        sport:{type:'string',enum:['run','bike','swim','strength','brick','hike','other']},
        duration:{type:'number'},
        notes:{type:'string'},
        date:{type:'string'}
      },
      required:['sport','duration']}
  },
];
```

The descriptions are deliberately opinionated about *when* to use each tool. "Only use when athlete explicitly describes something they just completed" prevents the AI from logging hypothetical workouts. These descriptions are the primary lever for controlling AI behavior.

### Adding a New Tool

1. Add the tool definition to the `TOOLS` array (name, description, input_schema)
2. Add a `case` to `executeTool()` that reads from `appState` and returns a JSON string
3. Mention the tool in the system prompt's decision tree if it needs special guidance
4. No other changes needed — the agent loop handles any number of tools

## System Prompt

The system prompt is intentionally lean. It tells the AI its personality, gives it a decision tree for tool usage, and provides today's date. No training data.

```javascript
function buildSystemPrompt(personality, customText) {
  return `${getPersonalityPrompt(personality, customText)}

You have tools to access the athlete's complete training data. Always use them before giving advice.
- Greetings: answer directly, no tools
- Coaching questions: start with get_athlete_profile
- Workout questions: get_workouts with filters
- "How am I doing": get_training_stats + get_goals
- Plan questions: get_training_plan
- Athlete describes completed workout: log_workout

Today: ${new Date().toISOString().split('T')[0]} (${new Date().toLocaleString('en-US',{weekday:'long'})})`;
}
```

The decision tree is critical. Without it, the AI tends to call `get_workouts` for everything. With it, the AI uses the right tool for the right question, which produces better coaching because it has the right context.

## Memory System

After each coaching conversation, a background API call extracts new facts and merges them into a persistent memory document. This runs after the user sees their response — it never blocks the UI.

```javascript
async function extractMemory(messages, callAI) {
  // Only run on ~55% of conversations (cost optimization)
  if (messages.length < 2 || Math.random() > 0.55) return;
  try {
    const conv = messages.slice(-8)
      .map(m => {
        const content = Array.isArray(m.content)
          ? m.content.filter(b=>b.type==='text').map(b=>b.text).join('')
          : m.content;
        return `${m.role==='user' ? 'Athlete' : 'Coach'}: ${content}`;
      })
      .filter(l => l.length > 10)
      .join('\n\n');

    const resp = await callAI({
      system: MEMORY_EXTRACTION_PROMPT,
      messages: [{ role:'user', content:conv }],
      max_tokens: 400
    });

    const raw = resp.content?.filter(b=>b.type==='text')?.map(b=>b.text)?.join('') || '';
    saveMemory(mergeMemory(loadMemory(), JSON.parse(raw.replace(/```json\n?|\n?```/g,'').trim())));
  } catch {} // Best-effort — never surface errors to user
}
```

The memory structure has five sections:
- **profile** — communication style, preferred workout times, equipment
- **physical** — injuries (with status tracking), strengths, limiters
- **behavioral** — patterns, motivators, consistency notes
- **coaching** — open items, current focus, session notes
- **conversationSummaries** — rolling window of the last 10 conversation summaries

The merge logic is additive with deduplication: new injuries update existing entries by body area, behavioral patterns are appended with `Set`-based dedup, and arrays are capped (12 patterns, 10 summaries) to prevent unbounded growth.

### Memory Architecture Limitation

Currently stored in localStorage. This means:

- Safari can purge it after 7 days of PWA inactivity
- No backup or sync
- Lost if the user clears browser data

When Supabase is wired up, memory should move to a `coaching_memory` table with the same JSON structure, loaded on auth and saved after extraction.

## Streaming / Typewriter Effect

The app uses a fake typewriter effect rather than real streaming. The full response is available after the agent loop completes, then revealed character by character using `requestAnimationFrame`:

```javascript
function typewriter(text, onUpdate) {
  return new Promise(resolve => {
    if (!text) { resolve(); return; }
    const targetMs = Math.min(2800, Math.max(600, text.length * 6));
    const charsPerMs = text.length / targetMs;
    let pos = 0, lastTime = null;
    const tick = now => {
      if (!lastTime) lastTime = now;
      pos = Math.min(
        pos + Math.ceil(charsPerMs * (now - lastTime) * (0.8 + Math.random() * .4)),
        text.length
      );
      lastTime = now;
      onUpdate(text.slice(0, pos));
      if (pos < text.length) requestAnimationFrame(tick);
      else { onUpdate(text); resolve(); }
    };
    requestAnimationFrame(tick);
  });
}
```

This gives a better UX than dumping a wall of text at once (which feels jarring on mobile), while being simpler than implementing real SSE streaming through the Vercel proxy. Trade-off: the user waits for the full response before seeing anything. For most coaching responses (1-3 seconds of API time), this is acceptable.

To add real streaming later, you'd need to switch the API route to return a ReadableStream and process SSE events in the browser. The agent loop makes this harder because tool calls require full roundtrips — you can only stream the final text response, not the intermediate tool-calling steps.

## Push Message Generation

The daily coaching analysis on the home screen uses the same agent loop but with a specific prompt that forces 4 tool calls:

```javascript
async function generatePushMessage(personality, customText, appState, callAI) {
  const result = await runAgentLoop({
    personality, customText,
    messages: [{
      role: 'user',
      content: `Generate my daily coaching push message. Use tools to gather:
        get_training_plan(), get_workouts(sport="all", days=7),
        get_training_stats(weeks=2), get_goals().
        Then write 4-6 sentences: compare prescribed vs actual (be specific),
        call out the most important pattern, give one specific action for
        the next 48 hours, reference real dates.
        Style: ${getCommentaryStyle(personality, customText)}. Plain text only.`
    }],
    appState, callAI,
    maxRounds: 4
  });
  return result.response;
}
```

This is cached in localStorage with a staleness check (8 hours) and refreshes when workout count changes. The result is a genuinely useful daily briefing because the AI has full context from 4 different data sources.

## Data Flow

```
User types message
        │
        ▼
  handleSend()
        │
        ├── Add user message to React state
        │
        ▼
  runAgentLoop()
        │
        ├── Build system prompt (personality + date, ~300 tokens)
        ├── Send to /api/chat (Vercel proxy → Anthropic)
        │
        ├── If stop_reason === 'tool_use':
        │     ├── executeTool() runs locally against localStorage
        │     ├── Append tool results to conversation chain
        │     └── Loop back to send again
        │
        └── If stop_reason === 'end_turn':
              ├── Extract final text
              ├── Extract any workoutsLogged from log_workout calls
              └── Return { response, workoutsLogged }
        │
        ▼
  typewriter(response)
        │
        ├── Reveal text character by character
        │
        ▼
  extractMemory() [background, fire-and-forget]
        │
        ├── Send last 8 messages to API for fact extraction
        ├── Merge extracted facts into localStorage memory
        └── Never blocks UI, never surfaces errors
```

## Extending the Architecture

### Adding a new data source (e.g., HealthKit)

1. Add a new tool definition (e.g., `get_health_data`)
2. In `executeTool()`, read from whatever storage HealthKit data lives in
3. The AI will call it when relevant — no prompt changes needed if the tool description is clear

### Adding proactive coaching (pattern detection)

Create a scheduled function that runs daily:
1. Call `get_training_stats(weeks=4)` and `get_goals()` locally
2. Compare actual vs prescribed volume
3. If a gap is detected (e.g., swim sessions < 1/week for 3 weeks), generate a "pattern card" via a focused API call
4. Display on the home screen above the push message

### Moving to Supabase

The tool executor currently reads from `appState` (which is hydrated from localStorage). To move to Supabase:
1. Replace `db.get()`/`db.set()` calls with Supabase queries
2. Hydrate `appState` from Supabase on auth instead of localStorage
3. Tool execution stays local — it reads from the in-memory appState, not directly from the database
4. Writes (workout logging, memory updates) go to Supabase instead of localStorage
