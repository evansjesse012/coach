import { buildSystemPrompt } from './prompts.js';
import { TOOLS } from './tools.js';
import { executeTool } from './tool-execution.js';
import { loadMemory, saveMemory, mergeMemory, MEMORY_EXTRACTION_PROMPT } from './memory.js';
import { getCommentaryStyle } from '../lib/personalities.js';

export async function runAgentLoop({ personality, customText, messages, appState, callAI, maxRounds=5 }) {
  const clean=messages.map(m=>({role:m.role,content:typeof m.content==='string'?m.content:Array.isArray(m.content)?m.content.filter(b=>b.type==='text').map(b=>b.text).join('\n')||'(continued)':String(m.content||'')}));
  let chain=[...clean]; let toolCallCount=0; const workoutsLogged=[]; const nutritionLogged=[]; const planChanges=[];
  for (let round=0; round<maxRounds; round++) {
    const resp=await callAI({system:buildSystemPrompt(personality,customText),messages:chain,tools:TOOLS,tool_choice:{type:'auto'},max_tokens:2048});
    if (resp.stop_reason==='end_turn') return {response:resp.content?.filter(b=>b.type==='text')?.map(b=>b.text)?.join('')?.trim()||'',workoutsLogged,nutritionLogged,planChanges,toolCallCount};
    if (resp.stop_reason==='tool_use') {
      const toolUses=resp.content?.filter(b=>b.type==='tool_use')||[];
      if (!toolUses.length) return {response:resp.content?.filter(b=>b.type==='text')?.map(b=>b.text)?.join('')||'',workoutsLogged,nutritionLogged,planChanges,toolCallCount};
      const toolResults=toolUses.map(tu=>{toolCallCount++;let input;try{input=typeof tu.input==='string'?JSON.parse(tu.input):tu.input;}catch{input={};}const result=executeTool(tu.name,input,appState);if(tu.name==='log_workout'){try{const p=JSON.parse(result);if(p.logged&&p.workout)workoutsLogged.push(p.workout);}catch{}}if(tu.name==='log_nutrition'){try{const p=JSON.parse(result);if(p.logged&&p.nutrition)nutritionLogged.push(p.nutrition);}catch{}}if(tu.name==='save_training_plan'){try{const p=JSON.parse(result);if(p.saved&&p.plan)planChanges.push({type:'plan',data:p.plan});}catch{}}if(tu.name==='save_weekly_plan'){try{const p=JSON.parse(result);if(p.saved&&p.weekPlan)planChanges.push({type:'week',data:p.weekPlan});}catch{}}if(tu.name==='update_plan_progress'){try{const p=JSON.parse(result);if(p.updated)planChanges.push({type:'progress',data:{currentWeek:p.currentWeek,currentPhase:p.currentPhase}});}catch{}}return{type:'tool_result',tool_use_id:tu.id,content:result};});
      chain=[...chain,{role:'assistant',content:resp.content},{role:'user',content:toolResults}];
      continue;
    }
    return {response:resp.content?.filter(b=>b.type==='text')?.map(b=>b.text)?.join('')||'Done.',workoutsLogged,nutritionLogged,planChanges,toolCallCount};
  }
  return {response:'I needed more context. Try asking again.',workoutsLogged,nutritionLogged,planChanges,toolCallCount};
}

export async function compressSummaries(memory, callAI) {
  const toCompress = memory.conversationSummaries.slice(0, 20);
  if (toCompress.length < 20) return;
  try {
    const text = toCompress.map(s => `[${s.date||'?'}] ${s.summary}`).join('\n');
    const resp = await callAI({
      system: 'Compress these coaching conversation summaries into a single paragraph (3-5 sentences) capturing key themes, decisions, progression, and any important turning points. Return ONLY the paragraph, no JSON.',
      messages: [{ role: 'user', content: text }], max_tokens: 300
    });
    const summary = resp.content?.filter(b=>b.type==='text')?.map(b=>b.text)?.join('')?.trim() || '';
    if (summary) {
      memory.periodSummaries = memory.periodSummaries || [];
      memory.periodSummaries.push({
        periodStart: toCompress[0].date || '', periodEnd: toCompress[toCompress.length-1].date || '', summary
      });
      memory.conversationSummaries = memory.conversationSummaries.slice(20);
    }
  } catch {}
}

export async function extractMemory(messages, callAI) {
  if (messages.length<2||messages.length%2!==0) return;
  try {
    const conv=messages.slice(-8).map(m=>{const content=Array.isArray(m.content)?m.content.filter(b=>b.type==='text').map(b=>b.text).join(''):m.content;return `${m.role==='user'?'Athlete':'Coach'}: ${content}`;}).filter(l=>l.length>10).join('\n\n');
    if (!conv.trim()) return;
    const resp=await callAI({system:MEMORY_EXTRACTION_PROMPT,messages:[{role:'user',content:conv}],max_tokens:600});
    const raw=resp.content?.filter(b=>b.type==='text')?.map(b=>b.text)?.join('')||'';
    const merged = mergeMemory(loadMemory(), JSON.parse(raw.replace(/```json\n?|\n?```/g,'').trim()));
    if (merged.conversationSummaries.length > 30) await compressSummaries(merged, callAI);
    saveMemory(merged);
  } catch {}
}

export async function generatePushMessage(personality, customText, appState, callAI) {
  try {
    const result=await runAgentLoop({personality,customText,messages:[{role:'user',content:`Generate my coaching note. Gather context with: get_training_plan(includePhaseDetail=true), get_workouts(sport="all", days=7), get_training_stats(weeks=4), get_goals(), get_week_review(includeMultiWeek=true), get_athlete_profile().

You're an expert athletic coach checking in. Look at the full picture — recent sessions, plan progress, phase timing, goal timeline, multi-week trends. Surface what matters most right now:
- Specific session feedback or what's coming up
- Where they are in their plan — phase progress, readiness, what's next
- A flag if something needs attention (declining adherence, overtraining, stalled progress)
- A question you need answered before prescribing their next session

Lead with what's important. Be specific with real numbers and dates. If everything looks good, keep it short. This is a mobile card — stay concise. Use **bold** sparingly for emphasis.

If — and only if — your note asks the athlete a genuine question or presents a decision, append tappable response buttons as the LAST line:
[ACTIONS: "Button label" -> "response message", "Another label" -> "another response"]
To open full chat instead: [ACTIONS: "Let's discuss" -> CHAT "pre-filled message"]
Rules: 2-3 actions max. Each button must be a direct answer to YOUR question. Never suggest something the data shows already exists (e.g. don't suggest generating a plan when one is loaded). Most notes won't need actions — that's fine.

Style: ${getCommentaryStyle(personality,customText)}.`}],appState,callAI,maxRounds:6});
    return parsePushActions(result.response);
  } catch { return { text: '', actions: [] }; }
}

export function parsePushActions(raw) {
  if (!raw) return { text: '', actions: [] };
  const match = raw.match(/\[ACTIONS:\s*(.+)\]\s*$/);
  if (!match) return { text: raw, actions: [] };
  const text = raw.slice(0, raw.lastIndexOf('[ACTIONS:')).trim();
  const actions = [];
  const re = /"([^"]+)"\s*->\s*(CHAT\s*)?"([^"]+)"/g;
  let m;
  while ((m = re.exec(match[1]))) {
    actions.push({ label: m[1], message: m[3], openChat: !!m[2] });
  }
  return { text, actions };
}

export async function parseQuickCapture(text, callAI) {
  const today=new Date().toISOString().split('T')[0];
  const resp=await callAI({system:`Extract a workout from this message. Return ONLY JSON: {"sport":"run|bike|swim|strength|brick|hike|other","duration":MINUTES,"notes":"brief","date":"${today}"}. Infer duration from distance+pace if given. Default 45 if unclear.`,messages:[{role:'user',content:text}],max_tokens:100});
  return JSON.parse((resp.content?.filter(b=>b.type==='text')?.map(b=>b.text)?.join('')||'').replace(/```json\n?|\n?```/g,'').trim());
}

export function typewriter(text, onUpdate) {
  return new Promise(resolve=>{
    if (!text){resolve();return;}
    const targetMs=Math.min(2800,Math.max(600,text.length*6));
    const charsPerMs=text.length/targetMs;
    let pos=0,lastTime=null;
    const tick=now=>{if(!lastTime)lastTime=now;pos=Math.min(pos+Math.ceil(charsPerMs*(now-lastTime)*(0.8+Math.random()*.4)),text.length);lastTime=now;onUpdate(text.slice(0,pos));if(pos<text.length)requestAnimationFrame(tick);else{onUpdate(text);resolve();}};
    requestAnimationFrame(tick);
  });
}
