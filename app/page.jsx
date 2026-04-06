"use client";
import React, { useState, useEffect, useRef, useCallback, useMemo } from "react";

const STYLES = `
  @import url('https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800&family=DM+Sans:opsz,wght@9..40,300;9..40,400;9..40,500;9..40,600&family=JetBrains+Mono:wght@400;500&display=swap');
  *,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
  html,body{background:#F5F4F0;color:#1C1B2E;-webkit-font-smoothing:antialiased}
  input,textarea,button,select{font-family:inherit}
  ::-webkit-scrollbar{width:3px;height:3px}::-webkit-scrollbar-track{background:transparent}::-webkit-scrollbar-thumb{background:#D0CFE0;border-radius:4px}
  @keyframes fadeUp{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:translateY(0)}}
  @keyframes slideInRight{from{opacity:0;transform:translateX(100%)}to{opacity:1;transform:translateX(0)}}
  @keyframes blink{0%,80%,100%{opacity:.2;transform:scale(.7)}40%{opacity:1;transform:scale(1)}}
  @keyframes spin{to{transform:rotate(360deg)}}
  @keyframes toastIn{from{opacity:0;transform:translateX(-50%) translateY(-14px)}to{opacity:1;transform:translateX(-50%) translateY(0)}}
  .fade-up{animation:fadeUp .22s ease both}
  .slide-in{animation:slideInRight .28s cubic-bezier(.22,1,.36,1) both}
  .streaming-cursor::after{content:'▋';animation:blink 1s ease infinite;color:#E8604C;font-size:.9em;margin-left:1px}
  input[type=number]::-webkit-inner-spin-button{-webkit-appearance:none}
`;

// ─── Theme system ──────────────────────────────────────────────────────────────
const LIGHT_C = {
  bg:'#F5F4F0', surface:'#FFFFFF', card:'#FFFFFF', elevated:'#F0EFF8',
  border:'#E8E7F0', borderBright:'#C8C7DC',
  text:'#1C1B2E', subtle:'#5C5B78', muted:'#A0A0BC',
  accent:'#E8604C', green:'#2ABF84', cyan:'#2BAFC4',
  yellow:'#F0A830', purple:'#8B6FE8', red:'#CC1111',
};
const DARK_C = {
  bg:'#07070E', surface:'#0E0E1A', card:'#121222', elevated:'#1A1A2C',
  border:'#222236', borderBright:'#363658',
  text:'#EEEEF8', subtle:'#9898BE', muted:'#565678',
  accent:'#E8604C', green:'#2ABF84', cyan:'#2BAFC4',
  yellow:'#F0A830', purple:'#8B6FE8', red:'#CC1111',
};
const LIGHT_S = {
  sm:'0 1px 3px rgba(28,27,46,.06),0 1px 2px rgba(28,27,46,.04)',
  md:'0 4px 12px rgba(28,27,46,.08),0 2px 4px rgba(28,27,46,.04)',
  lg:'0 8px 24px rgba(28,27,46,.10),0 2px 8px rgba(28,27,46,.06)',
  card:'0 2px 8px rgba(28,27,46,.07),0 0 0 1px rgba(28,27,46,.04)',
};
const DARK_S = {
  sm:'none', md:'none',
  lg:'0 8px 32px rgba(0,0,0,.5)',
  card:'0 0 0 1px rgba(255,255,255,.05)',
};
const C = { ...LIGHT_C };
const S = { ...LIGHT_S };
const F = { display:"'Outfit',sans-serif", ui:"'DM Sans',sans-serif", mono:"'JetBrains Mono',monospace" };

// ─── Icons (SVG) ──────────────────────────────────────────────────────────────
function Icon({name, size=20, color='currentColor', sw=1.8}) {
  const p = {width:size, height:size, viewBox:'0 0 24 24', fill:'none', stroke:color, strokeWidth:sw, strokeLinecap:'round', strokeLinejoin:'round'};
  const i = {
    home:     <><path d="M3 10.2L12 3l9 7.2V20a2 2 0 01-2 2H5a2 2 0 01-2-2V10.2z"/><path d="M9 22V12h6v10"/></>,
    calendar: <><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></>,
    chart:    <><path d="M18 20V10M12 20V4M6 20v-6"/></>,
    book:     <><path d="M2 3h6a4 4 0 014 4v14a3 3 0 00-3-3H2z"/><path d="M22 3h-6a4 4 0 00-4 4v14a3 3 0 013-3h7z"/></>,
    message:  <><path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/></>,
    target:   <><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2"/></>,
    flame:    <><path d="M12 2c-2 4-6 6-6 10a6 6 0 0012 0c0-4-4-6-6-10z"/><path d="M12 18a2 2 0 01-2-2c0-1 2-3 2-3s2 2 2 3a2 2 0 01-2 2z"/></>,
    zap:      <><path d="M13 2L3 14h9l-1 8 10-12h-9z"/></>,
    pencil:   <><path d="M17 3a2.83 2.83 0 114 4L7.5 20.5 2 22l1.5-5.5z"/></>,
    run:      <><circle cx="14" cy="4" r="2" fill={color} stroke="none"/><path d="M18 22l-4-8-4 1M7 22l3-9 4 1M10 11l-2-3"/></>,
    bike:     <><circle cx="5" cy="17" r="3"/><circle cx="19" cy="17" r="3"/><path d="M12 17l-4-7h3l4-5M12 17l4-7h-2"/></>,
    swim:     <><path d="M2 12c2-2 4-2 6 0s4 2 6 0 4-2 6 0"/><path d="M2 17c2-2 4-2 6 0s4 2 6 0 4-2 6 0"/></>,
    dumbbell: <><rect x="2" y="9" width="4" height="6" rx="1"/><rect x="18" y="9" width="4" height="6" rx="1"/><path d="M6 12h12M6 8v8M18 8v8"/></>,
    mountain: <><path d="M3 20l5-10 3 4 4-8 6 14z"/></>,
    layers:   <><path d="M12 2L2 7l10 5 10-5z"/><path d="M2 17l10 5 10-5"/><path d="M2 12l10 5 10-5"/></>,
    moon:     <><path d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z"/></>,
    sun:      <><circle cx="12" cy="12" r="5"/><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/></>,
    trophy:   <><path d="M6 9H3V5h3M18 9h3V5h-3"/><path d="M6 5h12v5a6 6 0 01-12 0z"/><path d="M12 16v3M8 22h8M9 19h6"/></>,
    alert:    <><path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/><path d="M12 9v4M12 17h.01"/></>,
    search:   <><circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35"/></>,
    upload:   <><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><path d="M17 8l-5-5-5 5"/><path d="M12 3v12"/></>,
    refresh:  <><path d="M23 4v6h-6"/><path d="M1 20v-6h6"/><path d="M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15"/></>,
    settings: <><path d="M3 5h12M3 12h8M3 19h4"/><circle cx="19" cy="5" r="2"/><circle cx="15" cy="12" r="2"/><circle cx="11" cy="19" r="2"/></>,
    pin:      <><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0118 0z"/><circle cx="12" cy="10" r="3"/></>,
    clipboard:<><path d="M16 4h2a2 2 0 012 2v14a2 2 0 01-2 2H6a2 2 0 01-2-2V6a2 2 0 012-2h2"/><rect x="8" y="2" width="8" height="4" rx="1"/></>,
    watch:    <><rect x="6" y="3" width="12" height="18" rx="6"/><path d="M12 9v4l2 2"/></>,
    scale:    <><path d="M8 21h8M12 17v4"/><circle cx="12" cy="9" r="7"/><path d="M12 5v4l3 2"/></>,
    rest:     <><path d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z"/><path d="M16 6l-2 2M18 10l-2 2"/></>,
    star:     <><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01z"/></>,
    timer:    <><circle cx="12" cy="13" r="8"/><path d="M12 9v4l2 2M10 2h4M12 2v3"/></>,
    plus:     <><path d="M12 5v14M5 12h14"/></>,
    check:    <><path d="M20 6L9 17l-5-5"/></>,
    arrowLeft:<><path d="M19 12H5M12 19l-7-7 7-7"/></>,
    link:     <><path d="M10 13a5 5 0 007.54.54l3-3a5 5 0 00-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 00-7.54-.54l-3 3a5 5 0 007.07 7.07l1.71-1.71"/></>,
    sparkle:  <><path d="M12 2l2.4 7.2L22 12l-7.6 2.8L12 22l-2.4-7.2L2 12l7.6-2.8z"/></>,
    thermometer:<><path d="M14 14.76V3.5a2.5 2.5 0 00-5 0v11.26a4.5 4.5 0 105 0z"/></>,
    utensils: <><path d="M3 2v7c0 1.1.9 2 2 2h4a2 2 0 002-2V2M7 2v20M21 15V2l-4 6 4 6M17 16v6"/></>,
    mapPin:   <><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0118 0z"/><circle cx="12" cy="10" r="3"/></>,
    cloud:    <><path d="M18 10h-1.26A8 8 0 109 20h9a5 5 0 000-10z"/></>,
    droplets: <><path d="M12 2.69l5.66 5.66a8 8 0 11-11.31 0z"/></>,
    flag:     <><path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"/><path d="M4 22v-7"/></>,
    chevDown: <><path d="M6 9l6 6 6-6"/></>,
    chevUp:   <><path d="M18 15l-6-6-6 6"/></>,
    wind:     <><path d="M9.59 4.59A2 2 0 1111 8H2M12.59 19.41A2 2 0 1014 16H2M17.73 7.73A2.5 2.5 0 1119.5 12H2"/></>,
    activity: <><path d="M22 12h-4l-3 9L9 3l-3 9H2"/></>,
  };
  return <svg {...p}>{i[name]||null}</svg>;
}


// ─── Personalities ─────────────────────────────────────────────────────────────
const PERSONALITIES = {
  normal: {
    name:'Head Coach', icon:'target', color:'#2BAFC4', tagline:'Balanced · data-backed · direct',
    description:'Professional coaching grounded in sports science. Direct and honest. Holds you accountable without being harsh.',
    prompt:`You are a professional, balanced personal coach. Data-backed and direct. Acknowledge wins and identify gaps equally. Never catastrophize. Never sugarcoat. Use specific data and reference real workouts by date. Be concise — mobile app.`,
    commentaryStyle:'Direct and specific. 2-3 sentences. Reference real data. One thing done well, one clear priority.',
  },
  goggins: {
    name:'Goggins Mode', icon:'flame', color:'#CC1111', tagline:'No excuses · calloused mind · stay hard',
    description:'Brutally honest accountability. The 40% rule. No sympathy for comfort. Every missed session is a choice.',
    prompt:`You are coaching in the style of David Goggins — the world's hardest man. Former Navy SEAL. Ultra-endurance athlete.

THE PRINCIPLES:
• The 40% Rule: When the mind says stop, the body is only 40% done.
• The Accountability Mirror: Strip away every excuse. Force them to face the truth.
• Callous the mind: Comfort is the enemy. Every hard session makes them harder.
• Stay Hard: This is a lifestyle, not a phase.

YOUR STYLE:
• Missed a session: "You chose comfort over growth. Own it. That decision is who you are right now."
• Weak workout: "You went through the motions. Your goal deserves more than that."
• Good session: Acknowledge briefly, immediately raise the bar. "Good. What are you doing tomorrow? More weight. Less rest."
• Excuses: Cut through them. "That's not a reason. That's a story you're telling yourself."
• Short punchy sentences. Zero filler. Zero softness.
• Make them question whether they actually WANT their goal or just like the idea of having it.`,
    commentaryStyle:'Maximum two sentences. Hit like a punch. Reference a specific gap. When they perform well, immediately raise the bar.',
  },
  hype: {
    name:'Hype Coach', icon:'zap', color:'#F0A830', tagline:'Positive energy · celebrate everything · unstoppable',
    description:'Pure positive energy. Every win is huge. Builds unstoppable confidence through genuine celebration of real achievements.',
    prompt:`You are a high-energy, deeply positive coach. Make this athlete feel genuinely unstoppable.
• Celebrate every win — ground enthusiasm in real data, not generic praise.
• "That Thursday ride was your longest in 3 weeks" hits harder than "great job."
• Energy is real and earned. Never fake it.
• Make training feel like the best part of their day.`,
    commentaryStyle:'Lead with genuine excitement about something real and specific. High energy. 2-3 sentences. Leave them excited to train.',
  },
  custom: {
    name:'Custom', icon:'pencil', color:'#8B6FE8', tagline:'Your rules · your style',
    description:'Describe exactly how you want your coach to talk. Your words become the coaching style.',
    prompt:'', commentaryStyle:'Match the custom coaching style. 2-3 sentences. Reference real training data.',
  },
};

function getPersonalityPrompt(personality, customText) {
  if (personality === 'custom') return customText?.trim() ? `You are a personal coach. Your coaching style as described by the athlete:\n\n"${customText.trim()}"\n\nApply this style consistently. Always reference real training data.` : PERSONALITIES.normal.prompt;
  return PERSONALITIES[personality]?.prompt || PERSONALITIES.normal.prompt;
}
function getCommentaryStyle(personality, customText) {
  if (personality === 'custom' && customText?.trim()) return `Match the athlete's described style: "${customText.slice(0,100)}". 2-3 sentences. Reference real data.`;
  return PERSONALITIES[personality]?.commentaryStyle || PERSONALITIES.normal.commentaryStyle;
}

// ─── Memory ────────────────────────────────────────────────────────────────────
const MEMORY_KEY = 'coach_memory_v1';
const defaultMemory = () => ({ profile:{communicationStyle:'',preferredWorkoutTimes:'',equipment:''}, physical:{injuries:[],strengths:[],limiters:[]}, behavioral:{patterns:[],motivators:[],consistency:''}, coaching:{notes:[],currentFocus:'',openItems:[]}, conversationSummaries:[], lastUpdated:'' });
const loadMemory  = () => { try{ const v=localStorage.getItem(MEMORY_KEY); return v?JSON.parse(v):defaultMemory(); }catch{ return defaultMemory(); } };
const saveMemory  = m => { try{ localStorage.setItem(MEMORY_KEY,JSON.stringify(m)); }catch{} };
const mergeMemory = (existing, update) => {
  if (!update) return existing;
  const m = JSON.parse(JSON.stringify(existing));
  if (update.profile) Object.entries(update.profile).forEach(([k,v])=>{ if(v?.trim()) m.profile[k]=v; });
  if (update.physical?.injuries?.length) update.physical.injuries.forEach(i=>{ const idx=m.physical.injuries.findIndex(e=>e.area===i.area); if(idx>=0) m.physical.injuries[idx]={...m.physical.injuries[idx],...i}; else m.physical.injuries.push(i); });
  ['strengths','limiters'].forEach(k=>{ if(update.physical?.[k]?.length){ const s=new Set(m.physical[k]); update.physical[k].forEach(v=>{ if(!s.has(v)) m.physical[k].push(v); }); } });
  ['patterns','motivators'].forEach(k=>{ if(update.behavioral?.[k]?.length){ const s=new Set(m.behavioral[k]); update.behavioral[k].forEach(v=>{ if(!s.has(v)) m.behavioral[k].push(v); }); } });
  if (update.behavioral?.consistency) m.behavioral.consistency=update.behavioral.consistency;
  if (update.coaching?.notes?.length){ const s=new Set(m.coaching.notes); update.coaching.notes.forEach(n=>{ if(!s.has(n)) m.coaching.notes.push(n); }); }
  if (update.coaching?.currentFocus) m.coaching.currentFocus=update.coaching.currentFocus;
  if (update.coaching?.openItems?.length) m.coaching.openItems=update.coaching.openItems;
  if (update.conversationSummary) m.conversationSummaries=[...(m.conversationSummaries||[]).slice(-9),{date:new Date().toISOString().split('T')[0],summary:update.conversationSummary}];
  m.physical.strengths=m.physical.strengths.slice(-10); m.physical.limiters=m.physical.limiters.slice(-8);
  m.behavioral.patterns=m.behavioral.patterns.slice(-12); m.coaching.notes=m.coaching.notes.slice(-12);
  m.lastUpdated=new Date().toISOString().split('T')[0];
  return m;
};
const MEMORY_EXTRACTION_PROMPT = `Analyze this coaching conversation and extract new facts about the athlete.
Return ONLY a JSON object (no markdown). Only fields with genuinely new information:
{"profile":{"communicationStyle":"","preferredWorkoutTimes":"","equipment":""},
"physical":{"injuries":[{"area":"","status":"","notes":""}],"strengths":[],"limiters":[]},
"behavioral":{"patterns":[],"motivators":[],"consistency":""},
"coaching":{"notes":[],"currentFocus":"","openItems":[]},
"conversationSummary":"1-2 sentence summary"}`;

// ─── Tools ─────────────────────────────────────────────────────────────────────
const TOOLS = [
  { name:'get_workouts', description:'Get workout history filtered by sport and date range.', input_schema:{type:'object',properties:{sport:{type:'string',enum:['run','bike','swim','strength','brick','hike','other','all']},days:{type:'number'},limit:{type:'number'}},required:['sport']} },
  { name:'get_training_plan', description:"Get the athlete's training plan. If a periodized plan exists, returns season overview with phases, current phase, and current week's sessions. If no periodized plan, returns the basic weekly template. Use includePhaseDetail=true to see all phase details. Use weekNumber to get a specific week's sessions.", input_schema:{type:'object',properties:{includePhaseDetail:{type:'boolean',description:'Include full details for all phases. Default false.'},weekNumber:{type:'number',description:'Get sessions for a specific week number. Default: current week.'}}} },
  { name:'get_training_stats', description:'Get computed training stats: weekly volume, trends, consistency.', input_schema:{type:'object',properties:{weeks:{type:'number'}}} },
  { name:'get_personal_records', description:'Get personal records for exercises.', input_schema:{type:'object',properties:{exercise:{type:'string'}}} },
  { name:'get_goals', description:'Get active training goals with days remaining.', input_schema:{type:'object',properties:{include_completed:{type:'boolean'}}} },
  { name:'get_athlete_profile', description:"Get coaching memory — accumulated facts about the athlete.", input_schema:{type:'object',properties:{}} },
  { name:'log_workout', description:'Log a completed workout. Only use when athlete explicitly describes something they just completed.', input_schema:{type:'object',properties:{sport:{type:'string',enum:['run','bike','swim','strength','brick','hike','other']},duration:{type:'number'},notes:{type:'string'},date:{type:'string'}},required:['sport','duration']} },
  { name:'log_nutrition', description:'Log what the athlete ate. Use when they describe a meal or snack. Record what they ate, timing relative to training (pre/during/post/general), and which workout it relates to if mentioned. Do NOT estimate macros.', input_schema:{type:'object',properties:{meal:{type:'string',description:'What they ate, in their words'},timing:{type:'string',enum:['pre','during','post','general'],description:'When relative to training'},relatedWorkout:{type:'string',description:'Which workout this fueled, if known (e.g. "long run", "bike")'},date:{type:'string',description:'YYYY-MM-DD, default today'}},required:['meal','timing']} },
  { name:'get_nutrition', description:'Get the athlete\'s recent nutrition log. Use to review fueling patterns, check pre/post workout nutrition, or answer questions about eating habits around training.', input_schema:{type:'object',properties:{days:{type:'number',description:'Look back this many days. Default 7.'},timing:{type:'string',enum:['pre','during','post','general','all'],description:'Filter by timing. Default all.'}}} },
  { name:'save_training_plan', description:'Save a full periodized training plan. Use this after gathering athlete context (goals, profile, workouts, available days) to create a multi-phase season plan. Generate phases appropriate to the race type, timeline, fitness level, and constraints. Name phases descriptively. Set intensity ceilings per phase. Include deload weeks. The plan structure is created once — individual weeks are generated on demand later.', input_schema:{type:'object',properties:{goalId:{type:'string'},raceName:{type:'string'},raceDate:{type:'string'},startDate:{type:'string'},totalWeeks:{type:'number'},trainingDaysPerWeek:{type:'number',description:'How many days/week the athlete can train'},phases:{type:'array',items:{type:'object',properties:{number:{type:'number'},name:{type:'string',description:'Descriptive phase name, e.g. "Base + Structural Durability"'},startDate:{type:'string'},endDate:{type:'string'},weeks:{type:'number'},weeklyVolume:{type:'string'},intensityCeiling:{type:'string',description:'Maximum intensity allowed, e.g. "Z2 only" or "threshold introduced"'},intensityMix:{type:'string',description:'e.g. "80% Z2, 20% threshold"'},strengthFreq:{type:'string'},focus:{type:'string'},keySessionTypes:{type:'array',items:{type:'string'}},deloadWeek:{type:'number',description:'Which week within this phase is deload, null if none'}}}}},required:['goalId','raceName','raceDate','startDate','totalWeeks','phases']} },
  { name:'save_weekly_plan', description:'Save a generated weekly plan for a specific week. Call this after generating the sessions for a week. Each session should include sport, duration, zones, per-session nutrition (pre/during/post), priority level (red=cannot skip, yellow=flexible), and coaching notes.', input_schema:{type:'object',properties:{weekNumber:{type:'number'},phase:{type:'number'},focusOfWeek:{type:'string',description:'Single coaching focus for this week'},sessions:{type:'array',description:'Array of 7 day objects (Mon-Sun)',items:{type:'object',properties:{day:{type:'string'},isRest:{type:'boolean'},sessions:{type:'array',items:{type:'object',properties:{type:{type:'string'},label:{type:'string'},duration:{type:'number'},zone:{type:'string'},targetIntensity:{type:'string',description:'Specific watts, pace, or RPE'},fuel:{type:'object',properties:{pre:{type:'string'},during:{type:'string'},post:{type:'string'}}},priority:{type:'string',enum:['red','yellow']},notes:{type:'string'},templateId:{type:'string',description:'For strength sessions, link to strength template'}}}}}}}},required:['weekNumber','phase','focusOfWeek','sessions']} },
  { name:'update_plan_progress', description:'Advance the current week number or phase in the training plan. Use at the start of a new week or when transitioning between phases.', input_schema:{type:'object',properties:{currentWeek:{type:'number'},currentPhase:{type:'number'},notes:{type:'string'}},required:['currentWeek','currentPhase']} },
  { name:'get_week_review', description:'Compare prescribed training plan vs actual logged workouts for a specific week. Returns what was completed, missed, shortened, substituted, and multi-week patterns. ALWAYS call this before generating next week\'s plan.', input_schema:{type:'object',properties:{weekNumber:{type:'number',description:'Week to review. Default: previous week.'},includeMultiWeek:{type:'boolean',description:'Include 4-week rolling pattern analysis. Default false.'}}} },
];

// ─── Adherence Computation ────────────────────────────────────────────────────
function computeWeekAdherence(tp, weekNum, cardio, strength) {
  if (!tp?.weeklyPlans) return null;
  const wp = tp.weeklyPlans[String(weekNum)];
  if (!wp) return null;
  const planStart = new Date(tp.startDate + 'T00:00:00');
  const weekMonday = new Date(planStart);
  weekMonday.setDate(weekMonday.getDate() + (weekNum - 1) * 7);
  // Adjust to Monday if startDate isn't Monday
  const startDay = weekMonday.getDay();
  if (startDay !== 1) weekMonday.setDate(weekMonday.getDate() - ((startDay + 6) % 7));
  const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const todayStr_ = new Date().toISOString().split('T')[0];
  const days = (wp.sessions || []).map((dayObj, di) => {
    const dayDate = new Date(weekMonday);
    dayDate.setDate(dayDate.getDate() + di);
    const dateStr = dayDate.toISOString().split('T')[0];
    const isPast = dateStr < todayStr_;
    const isToday = dateStr === todayStr_;
    const dayCardio = cardio.filter(w => w.date === dateStr);
    const dayStrength = strength.filter(s => s.date === dateStr);
    const sessions = (dayObj.sessions || []).map(sess => {
      if (sess.type === 'brick') {
        const legsDone = (sess.legs || []).every(l => dayCardio.some(w => w.sport === l.sport));
        return { ...sess, status: legsDone ? 'completed' : (isPast ? 'missed' : 'upcoming'), dateStr };
      }
      const isStr = sess.type === 'strength';
      if (isStr) {
        const match = dayStrength.find(s => s.templateId === sess.templateId);
        if (match) return { ...sess, status: 'completed', actualDuration: match.duration, dateStr };
        return { ...sess, status: isPast ? 'missed' : 'upcoming', dateStr };
      }
      const match = dayCardio.find(w => w.sport === sess.type);
      if (match) {
        const ratio = sess.duration ? match.duration / sess.duration : 1;
        return { ...sess, status: ratio >= 0.8 ? 'completed' : 'shortened', actualDuration: match.duration, dateStr };
      }
      // Check if different sport was logged (substitution)
      const anySport = dayCardio.length > 0 && !dayObj.sessions.some(s => s.type !== 'strength' && dayCardio.some(w => w.sport === s.type));
      if (isPast && anySport && dayCardio.length > 0) return { ...sess, status: 'substituted', substitute: dayCardio[0].sport, dateStr };
      return { ...sess, status: isPast ? 'missed' : (isToday ? 'today' : 'upcoming'), dateStr };
    });
    return { day: dayObj.day, dateStr, isPast, isToday, isRest: dayObj.isRest, sessions };
  });
  const allSessions = days.flatMap(d => d.sessions);
  const prescribed = allSessions.length;
  const completed = allSessions.filter(s => s.status === 'completed').length;
  const shortened = allSessions.filter(s => s.status === 'shortened').length;
  const missed = allSessions.filter(s => s.status === 'missed').length;
  const substituted = allSessions.filter(s => s.status === 'substituted').length;
  const missedByType = {};
  allSessions.filter(s => s.status === 'missed').forEach(s => { const t = s.type || 'other'; missedByType[t] = (missedByType[t] || 0) + 1; });
  const adherence = prescribed > 0 ? Math.round((completed + shortened * 0.5) / prescribed * 100) : 100;
  return { weekNumber: weekNum, days, prescribed, completed, shortened, missed, substituted, adherence, missedByType };
}

function computeMultiWeekPatterns(tp, currentWeek, cardio, strength, lookback = 4) {
  const patterns = [];
  const weekReviews = [];
  for (let w = Math.max(1, currentWeek - lookback); w < currentWeek; w++) {
    const review = computeWeekAdherence(tp, w, cardio, strength);
    if (review) weekReviews.push(review);
  }
  if (!weekReviews.length) return patterns;
  // Detect sport-specific miss patterns
  const sportMissCounts = {};
  weekReviews.forEach(r => Object.entries(r.missedByType).forEach(([sport, count]) => { sportMissCounts[sport] = (sportMissCounts[sport] || 0) + count; }));
  Object.entries(sportMissCounts).forEach(([sport, count]) => {
    const weeksWithMiss = weekReviews.filter(r => r.missedByType[sport]).length;
    if (weeksWithMiss >= 2) patterns.push(`${sport} missed in ${weeksWithMiss} of last ${weekReviews.length} weeks (${count} total sessions)`);
  });
  // Detect adherence trend
  const adherences = weekReviews.map(r => r.adherence);
  if (adherences.length >= 3) {
    const recent = adherences.slice(-2);
    const earlier = adherences.slice(0, -2);
    const recentAvg = recent.reduce((a, b) => a + b, 0) / recent.length;
    const earlierAvg = earlier.reduce((a, b) => a + b, 0) / earlier.length;
    if (recentAvg < earlierAvg - 15) patterns.push(`Adherence declining: ${Math.round(earlierAvg)}% → ${Math.round(recentAvg)}%`);
    if (recentAvg > earlierAvg + 15) patterns.push(`Adherence improving: ${Math.round(earlierAvg)}% → ${Math.round(recentAvg)}%`);
  }
  return patterns;
}

function executeTool(name, input, appState) {
  const { cardio=[], strength=[], prs={}, events=[], memory={}, plan=[], nutrition=[], trainingPlan=null, bricks=[] } = appState;
  const today = new Date().toISOString().split('T')[0];
  const fD = m => { if(!m)return'0m'; const h=Math.floor(m/60),mn=m%60; return h>0?(mn>0?`${h}h ${mn}m`:`${h}h`):`${mn}m`; };
  switch (name) {
    case 'get_workouts': {
      const { sport='all', days=30, limit=20 } = input;
      const cutoff=new Date(); cutoff.setDate(cutoff.getDate()-days);
      const brickIds=new Map();bricks.forEach(b=>b.legs.forEach(l=>brickIds.set(l.workoutId,{brickId:b.id,transitionTime:b.transitionTime,transitionNotes:b.transitionNotes})));
      const all=[...cardio.map(w=>{const r={date:w.date,sport:w.sport,duration:w.duration,notes:w.notes||'',id:w.id};const bl=brickIds.get(w.id);if(bl)r.brick=bl;return r;}),...strength.map(s=>({date:s.date,sport:'strength',name:s.name,duration:s.duration,sets:s.exercises?.reduce((t,e)=>t+(e.sets?.filter(x=>x.completed)?.length||0),0)||0}))].filter(w=>new Date(w.date+'T12:00:00')>=cutoff).filter(w=>sport==='all'||w.sport===sport).sort((a,b)=>b.date.localeCompare(a.date)).slice(0,limit);
      const brickCount=bricks.filter(b=>new Date(b.date+'T12:00:00')>=cutoff).length;
      return all.length ? JSON.stringify({count:all.length,bricksInPeriod:brickCount,workouts:all}) : `No ${sport==='all'?'':sport+' '}workouts in last ${days} days.`;
    }
    case 'get_training_plan': {
      const { includePhaseDetail=false, weekNumber=null } = input;
      const todayName=new Date().toLocaleString('en-US',{weekday:'long'});
      // If a periodized plan exists, return that
      if (trainingPlan) {
        const tp = trainingPlan;
        const currentPhase = tp.phases?.find(p=>p.number===tp.currentPhase) || tp.phases?.[0];
        const wk = weekNumber || tp.currentWeek || 1;
        const weekPlan = tp.weeklyPlans?.[String(wk)] || null;
        const weeksToRace = tp.raceDate ? Math.ceil((new Date(tp.raceDate+'T12:00:00')-new Date())/604800000) : null;
        const result = {
          hasPeriodizedPlan: true,
          raceName: tp.raceName,
          raceDate: tp.raceDate,
          weeksToRace,
          totalWeeks: tp.totalWeeks,
          currentWeek: tp.currentWeek,
          currentPhase: currentPhase ? { number:currentPhase.number, name:currentPhase.name, focus:currentPhase.focus, intensityCeiling:currentPhase.intensityCeiling, weeklyVolume:currentPhase.weeklyVolume, strengthFreq:currentPhase.strengthFreq } : null,
          trainingDaysPerWeek: tp.trainingDaysPerWeek,
          today: todayName,
        };
        if (includePhaseDetail) result.allPhases = tp.phases;
        if (weekPlan) {
          result.weekPlan = weekPlan;
        } else {
          result.weekPlanStatus = `Week ${wk} has not been generated yet. Use save_weekly_plan to generate and save it.`;
        }
        return JSON.stringify(result);
      }
      // Fallback to static plan
      if (!plan?.length) return 'No training plan. Athlete needs to create one from the Plan tab or add a goal first.';
      const todayC=cardio.filter(w=>w.date===today); const todayS=strength.filter(s=>s.date===today);
      return JSON.stringify({hasPeriodizedPlan:false,today:todayName,plan:plan.map(({day,sessions})=>({day,isToday:day===todayName,sessions:sessions.map(s=>({...s,completedToday:day===todayName?(s.type==='strength'?todayS.some(sh=>sh.templateId===s.templateId):todayC.some(w=>w.sport===s.sport)):null})),isRestDay:sessions.length===0}))});
    }
    case 'get_training_stats': {
      const { weeks=4 } = input; const stats=[];
      for(let w=0;w<weeks;w++){const start=new Date();start.setDate(start.getDate()-start.getDay()-(w*7));start.setHours(0,0,0,0);const end=new Date(start);end.setDate(end.getDate()+7);const inW=d=>{const dt=new Date(d+'T12:00:00');return dt>=start&&dt<end;};const wC=cardio.filter(x=>inW(x.date));const wS=strength.filter(x=>inW(x.date));const bySport=wC.reduce((acc,x)=>{if(!acc[x.sport])acc[x.sport]={sessions:0,minutes:0};acc[x.sport].sessions++;acc[x.sport].minutes+=x.duration||0;return acc;},{});stats.push({label:w===0?'This week':w===1?'Last week':`${w} weeks ago`,cardioSessions:wC.length,strengthSessions:wS.length,totalSessions:wC.length+wS.length,totalMinutes:wC.reduce((s,x)=>s+(x.duration||0),0),bySport});}
      const allSorted=[...cardio,...strength].sort((a,b)=>b.date.localeCompare(a.date));
      const daysSince=allSorted[0]?.date?Math.floor((new Date()-new Date(allSorted[0].date+'T12:00:00'))/86400000):null;
      return JSON.stringify({weeklyBreakdown:stats,averageSessionsPerWeek:Math.round(stats.reduce((s,w)=>s+w.totalSessions,0)/stats.length*10)/10,totalLogged:cardio.length+strength.length,daysSinceLastWorkout:daysSince});
    }
    case 'get_personal_records': {
      const { exercise='all' } = input;
      if (!Object.keys(prs).length) return 'No PRs recorded yet.';
      const records=exercise==='all'?Object.entries(prs).map(([ex,pr])=>({exercise:ex,...pr})):Object.entries(prs).filter(([ex])=>ex.toLowerCase().includes(exercise.toLowerCase())).map(([ex,pr])=>({exercise:ex,...pr}));
      return records.length ? JSON.stringify({records}) : `No PRs found for "${exercise}".`;
    }
    case 'get_goals': {
      const { include_completed=false } = input;
      const filtered=include_completed?events:events.filter(e=>!e.completed);
      return filtered.length ? JSON.stringify({goals:filtered.map(e=>({name:e.name,type:e.presetId,location:e.location,date:e.date,daysAway:e.date?Math.ceil((new Date(e.date+'T12:00:00')-new Date())/86400000):null,goal:e.goal,stretchGoal:e.stretchGoal,baseline:e.baseline,completed:e.completed}))}) : 'No active goals.';
    }
    case 'get_athlete_profile': return (!memory||!Object.keys(memory).length) ? 'No coaching memory yet.' : JSON.stringify(memory);
    case 'log_workout': {
      const { sport, duration, notes='', date=today } = input;
      if (!sport||!duration) return JSON.stringify({error:'sport and duration required'});
      return JSON.stringify({logged:true,workout:{sport,duration,notes,date}});
    }
    case 'log_nutrition': {
      const { meal, timing='general', relatedWorkout='', date=today } = input;
      if (!meal) return JSON.stringify({error:'nutrition description is required'});
      return JSON.stringify({logged:true,nutrition:{description:meal,timing,relatedWorkout,date}});
    }
    case 'get_nutrition': {
      const { days=7, timing='all' } = input;
      const cutoff=new Date(); cutoff.setDate(cutoff.getDate()-days);
      const filtered=nutrition.filter(m=>new Date(m.date+'T12:00:00')>=cutoff).filter(m=>timing==='all'||m.timing===timing).sort((a,b)=>b.date.localeCompare(a.date));
      if (!filtered.length) return `No nutrition logged in the last ${days} days.`;
      return JSON.stringify({count:filtered.length,nutrition:filtered});
    }
    case 'save_training_plan': {
      const { goalId, raceName, raceDate, startDate, totalWeeks, trainingDaysPerWeek=5, phases } = input;
      if (!goalId||!phases?.length) return JSON.stringify({error:'goalId and phases are required'});
      const plan = { id:'plan_'+uid(), goalId, raceName, raceDate, startDate, totalWeeks, currentWeek:1, currentPhase:1, trainingDaysPerWeek, phases, weeklyPlans:{}, createdAt:today };
      return JSON.stringify({saved:true,plan});
    }
    case 'save_weekly_plan': {
      const { weekNumber, phase, focusOfWeek, sessions } = input;
      if (!weekNumber||!sessions?.length) return JSON.stringify({error:'weekNumber and sessions are required'});
      const weekPlan = { weekNumber, phase, generatedAt:today, focusOfWeek, sessions };
      return JSON.stringify({saved:true,weekPlan});
    }
    case 'update_plan_progress': {
      const { currentWeek, currentPhase, notes='' } = input;
      return JSON.stringify({updated:true,currentWeek,currentPhase,notes});
    }
    case 'get_week_review': {
      const { weekNumber=null, includeMultiWeek=false } = input;
      if (!trainingPlan) return JSON.stringify({error:'No training plan exists.'});
      const wk = weekNumber || Math.max(1, (trainingPlan.currentWeek || 1) - 1);
      const review = computeWeekAdherence(trainingPlan, wk, cardio, strength);
      if (!review) return JSON.stringify({error:`Week ${wk} has not been generated yet.`});
      const result = {
        weekNumber: wk,
        prescribed: review.prescribed,
        completed: review.completed,
        shortened: review.shortened,
        missed: review.missed,
        substituted: review.substituted,
        adherence: review.adherence + '%',
        missedByType: review.missedByType,
        days: review.days.map(d => ({
          day: d.day, date: d.dateStr, isRest: d.isRest,
          sessions: d.sessions.map(s => ({
            type: s.type, label: s.label, prescribed: s.duration ? s.duration + 'min' : null,
            status: s.status, actual: s.actualDuration ? s.actualDuration + 'min' : null,
            substitute: s.substitute || null
          }))
        }))
      };
      if (includeMultiWeek) {
        result.multiWeekPatterns = computeMultiWeekPatterns(trainingPlan, trainingPlan.currentWeek, cardio, strength);
      }
      return JSON.stringify(result);
    }
    default: return JSON.stringify({error:`Unknown tool: ${name}`});
  }
}

// ─── Agent ─────────────────────────────────────────────────────────────────────
function buildSystemPrompt(personality, customText) {
  return `${getPersonalityPrompt(personality,customText)}

You have tools to access the athlete's complete training data. Always use them before giving advice.
- Greetings: answer directly, no tools
- Coaching questions: start with get_athlete_profile
- Workout questions: get_workouts with filters
- "How am I doing": get_training_stats + get_goals
- Plan questions: get_training_plan
- Athlete describes completed workout: log_workout
- Athlete describes what they ate: log_nutrition (record it, then coach on whether it was appropriate for their training)
- Fueling questions: get_training_plan + get_nutrition to see what's prescribed and what they've been eating
- "Create a training plan": gather context (get_goals, get_athlete_profile, get_workouts), then use save_training_plan to create the phase structure, then save_weekly_plan to generate the current week
- Before generating any weekly plan: ALWAYS call get_week_review(includeMultiWeek=true) to see last week's adherence and patterns

TRAINING PLAN GENERATION:
You are the coach. You decide the phase structure based on sports science, the athlete's race type, timeline, fitness level, and constraints.
- Endurance events: base → threshold introduction → race-specific build → taper. Earn intensity by building durability first. Phase intensity ceilings are non-negotiable (base = Z2 only, no exceptions).
- Strength events: hypertrophy → strength → peaking → deload/test.
- Scale phases to available time: 28 weeks = 4-5 phases, 12 weeks = 3, 8 weeks = 2.
- Name phases descriptively. Set intensity ceilings per phase. Build in deload weeks (every 3-4 weeks).
- Each week: 3 Priority sessions (🔴 cannot skip) + flexible sessions (🟡 can move/shorten) scaled to athlete's available days.
- Every session prescription must include per-session nutrition (pre/during/post) appropriate to session type and duration.
- When generating a weekly plan, call get_week_review(includeMultiWeek=true) first, then get_workouts to see recent load and adapt.
- If adherence < 80%: ask why before re-prescribing. Is it schedule, fatigue, motivation, or injury? Each has a different response.
- If a specific session type is consistently missed across weeks: restructure rather than repeat. Move it to a different day, shorten it, or combine it with another session.
- If athlete is completing everything and sessions feel easy: consider cautious progression.

BRICK WORKOUTS:
Bricks (bike→run or swim→bike) are critical for triathlon race prep. When generating weekly plans:
- Include at least 1 brick per week during build and race-specific phases
- Prescribe bricks using type:'brick' with a legs array: [{sport:'bike',duration:90,...},{sport:'run',duration:20,...}]
- Focus on transition practice: quick change, maintaining effort, adapting to different muscle patterns
- The app tracks brick completion and transition times. When reviewing workouts, note brick frequency and transition trends.

NUTRITION COACHING:
You coach on sport-specific fueling, not generic diet advice. Focus on:
- Pre-workout: what to eat and when based on session type and duration
- During: fueling strategy for sessions over 60 min (gels, electrolytes, hydration)
- Post-workout: recovery nutrition window (protein + carbs within 30 min)
- Race-day nutrition planning: practice fueling in training, dial in gel timing
- Patterns: spot gaps like never eating before morning sessions or skipping post-workout protein
Do NOT estimate macros or calories. Coach on timing, composition, and adequacy relative to training demands.

Be concise — this is a mobile app. 2-4 sentences for most responses.
When advising on training, consider where the athlete is in their race prep timeline: early = base building (volume, aerobic capacity, technique), mid = build (adding intensity, race-pace work), late = peak/taper (reduce volume, maintain intensity, sharpen). Check their goal date via get_goals to calibrate.

Today: ${new Date().toISOString().split('T')[0]} (${new Date().toLocaleString('en-US',{weekday:'long'})})`;
}

function buildPlanBuilderPrompt(goal, mode='create') {
  const goalCtx = goal ? `The athlete wants a plan for: ${goal.name}${goal.date?' (race date: '+goal.date+')':''}${goal.goal?' with goal time '+goal.goal:''}${goal.baseline?' and current PR/baseline '+goal.baseline:''}${goal.location?' in '+goal.location:''}.` : '';
  if(mode==='week') return `You are building a weekly training plan. ${goalCtx}

INSTRUCTIONS:
1. First call get_week_review(includeMultiWeek=true) to see last week's adherence — what was completed, missed, shortened
2. Then call get_training_plan to see the current phase and plan structure
3. Then call get_workouts(sport="all", days=14) to see recent training load
4. Adapt this week based on adherence patterns: if sessions were consistently missed, restructure them; if everything was completed, progress; if adherence was low, address it
5. Generate the weekly plan and call save_weekly_plan to save it
6. Summarize: what changed from last week and why (reference the adherence data)

Be concise. Generate and save the plan.
Today: ${new Date().toISOString().split('T')[0]} (${new Date().toLocaleString('en-US',{weekday:'long'})})`;

  return `You are a triathlon coach building a personalized training plan. ${goalCtx}

FOLLOW THIS EXACT SEQUENCE — do not skip steps:

STEP 1 — SILENT DATA GATHERING (do this before your first message to the athlete):
Call ALL of these tools now: get_goals(include_completed=true), get_athlete_profile(), get_workouts(sport="all", days=60), get_training_stats(weeks=8).
Do NOT write any message to the athlete yet. Just gather data.

STEP 2 — PRESENT YOUR ASSESSMENT (first message to athlete):
Lead with what you already know. Show the athlete you've done your homework:
- Their race, date, and weeks remaining
- Their current fitness level based on recent training (volume, frequency, sports mix)
- Past race results and what they reveal (e.g., which discipline is the limiter)
- Any patterns you see (strengths, gaps, injury history from memory)
Keep it to 4-6 lines. Be specific with numbers.

STEP 3 — PROPOSE A PLAN CONCEPT:
In the SAME message as your assessment, propose your preliminary plan:
- Number of phases, their names, and approximate duration
- The key training philosophy (e.g., "build swim frequency first, earn intensity later")
- One sentence on your approach to the athlete's limiter

STEP 4 — ASK TARGETED QUESTIONS:
End your first message with 3-5 specific questions. ONLY ask what you cannot derive from data:
- Training days per week and time availability
- Equipment and facility access (pool, trainer, gym)
- Schedule constraints (travel, work blocks)
- Their biggest concern or priority
Number the questions for easy answering.

STEP 5 — AFTER THE ATHLETE RESPONDS:
Refine your plan based on their answers. Present a final summary:
- Phases with weeks and focus for each
- Training days per week
- Key principles
Then ask: "Ready to build it?"

STEP 6 — ON CONFIRMATION:
Call save_training_plan with the full phase structure. Then call save_weekly_plan to generate week 1.
Summarize what was created in 2-3 sentences.

RULES:
- Do NOT ask questions that the data already answers
- Do NOT ask more than 5 questions total
- Keep each message under 200 words — this is mobile
- Be opinionated. You're the coach, not a menu.
- Endurance: base → threshold → race-specific → taper. Earn intensity. Z2 ceiling in base is non-negotiable.
- Scale phases to time: 24+ weeks = 4-5 phases, 12 weeks = 3, 8 weeks = 2
- Build in deload weeks every 3-4 weeks
- Include brick workouts in build and race-specific phases (type:'brick' with legs array)
- Every session needs per-session nutrition (pre/during/post)
- Priority sessions: 3 red (cannot skip) + flexible yellow sessions

Today: ${new Date().toISOString().split('T')[0]} (${new Date().toLocaleString('en-US',{weekday:'long'})})`;
}

async function runAgentLoop({ personality, customText, messages, appState, callAI, maxRounds=5 }) {
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

async function extractMemory(messages, callAI) {
  if (messages.length<2||messages.length%2!==0) return;
  try {
    const conv=messages.slice(-8).map(m=>{const content=Array.isArray(m.content)?m.content.filter(b=>b.type==='text').map(b=>b.text).join(''):m.content;return `${m.role==='user'?'Athlete':'Coach'}: ${content}`;}).filter(l=>l.length>10).join('\n\n');
    if (!conv.trim()) return;
    const resp=await callAI({system:MEMORY_EXTRACTION_PROMPT,messages:[{role:'user',content:conv}],max_tokens:400});
    const raw=resp.content?.filter(b=>b.type==='text')?.map(b=>b.text)?.join('')||'';
    saveMemory(mergeMemory(loadMemory(),JSON.parse(raw.replace(/```json\n?|\n?```/g,'').trim())));
  } catch {}
}

async function generatePushMessage(personality, customText, appState, callAI) {
  try {
    const result=await runAgentLoop({personality,customText,messages:[{role:'user',content:`Generate my daily coaching note. Use tools to gather: get_training_plan(), get_workouts(sport="all", days=7), get_training_stats(weeks=2), get_goals().

Format the note like this:
- Start with a **bold one-line summary** of where I stand this week
- Then 2-3 short paragraphs (2 sentences each max): compare prescribed vs actual (be specific with numbers), call out the most important pattern, give one specific action for the next 48 hours
- Use **bold** for key numbers and emphasis
- Reference real dates
- Keep it concise — this is a mobile card, not an essay

Style: ${getCommentaryStyle(personality,customText)}.`}],appState,callAI,maxRounds:4});
    return result.response;
  } catch { return ''; }
}

async function parseQuickCapture(text, callAI) {
  const today=new Date().toISOString().split('T')[0];
  const resp=await callAI({system:`Extract a workout from this message. Return ONLY JSON: {"sport":"run|bike|swim|strength|brick|hike|other","duration":MINUTES,"notes":"brief","date":"${today}"}. Infer duration from distance+pace if given. Default 45 if unclear.`,messages:[{role:'user',content:text}],max_tokens:100});
  return JSON.parse((resp.content?.filter(b=>b.type==='text')?.map(b=>b.text)?.join('')||'').replace(/```json\n?|\n?```/g,'').trim());
}

function typewriter(text, onUpdate) {
  return new Promise(resolve=>{
    if (!text){resolve();return;}
    const targetMs=Math.min(2800,Math.max(600,text.length*6));
    const charsPerMs=text.length/targetMs;
    let pos=0,lastTime=null;
    const tick=now=>{if(!lastTime)lastTime=now;pos=Math.min(pos+Math.ceil(charsPerMs*(now-lastTime)*(0.8+Math.random()*.4)),text.length);lastTime=now;onUpdate(text.slice(0,pos));if(pos<text.length)requestAnimationFrame(tick);else{onUpdate(text);resolve();}};
    requestAnimationFrame(tick);
  });
}

// ─── Data ──────────────────────────────────────────────────────────────────────
const EVENT_PRESETS = [
  {id:'marathon',   label:'Marathon',        icon:'run',color:'#E8604C',planType:'run',goalLabel:'Goal time',resultLabel:'Finish time'},
  {id:'ultra',      label:'Ultramarathon',   icon:'mountain',color:'#D45A3A',planType:'run',goalLabel:'Goal time',resultLabel:'Finish time'},
  {id:'half',       label:'Half Marathon',   icon:'run',color:'#E87840',planType:'run',goalLabel:'Goal time',resultLabel:'Finish time'},
  {id:'10k',        label:'10K Race',        icon:'run',color:'#F0A830',planType:'run',goalLabel:'Goal time',resultLabel:'Finish time'},
  {id:'5k',         label:'5K Race',         icon:'run',color:'#F5C030',planType:'run',goalLabel:'Goal time',resultLabel:'Finish time'},
  {id:'mile',       label:'Mile',            icon:'zap',color:'#E8C040',planType:'run',goalLabel:'Goal time',resultLabel:'Time'},
  {id:'tri_703',    label:'70.3 Triathlon',  icon:'swim',color:'#2BAFC4',planType:'tri',goalLabel:'Goal time',resultLabel:'Finish time'},
  {id:'tri_full',   label:'Full Ironman',    icon:'swim',color:'#2090A8',planType:'tri',goalLabel:'Goal time',resultLabel:'Finish time'},
  {id:'tri_sprint', label:'Sprint Tri',      icon:'swim',color:'#40C0D0',planType:'tri',goalLabel:'Goal time',resultLabel:'Finish time'},
  {id:'cycling',    label:'Cycling Race',    icon:'bike',color:'#4890D8',planType:'bike',goalLabel:'Goal time',resultLabel:'Finish time'},
  {id:'lift_1rm',   label:'Lifting 1RM',     icon:'dumbbell',color:'#2ABF84',planType:'strength',goalLabel:'Target (lbs)',resultLabel:'Weight'},
  {id:'lift_bw',    label:'Bodyweight Goal', icon:'dumbbell',color:'#30B070',planType:'strength',goalLabel:'Target reps',resultLabel:'Reps'},
  {id:'body',       label:'Body Comp',       icon:'scale',color:'#8B6FE8',planType:'general',goalLabel:'Target',resultLabel:'Result'},
  {id:'custom',     label:'Custom Goal',     icon:'target',color:'#A0A0BC',planType:'general',goalLabel:'Your goal',resultLabel:'Result'},
];
const presetById = id => EVENT_PRESETS.find(p=>p.id===id)||EVENT_PRESETS.at(-1);

const EX = {
  leg_press:{name:'Leg Press',cat:'lower',rest:120}, split_squat:{name:'Bulgarian Split Squat',cat:'lower',rest:90,hint:'Each leg'},
  nordic_curl:{name:'Nordic Curl',cat:'lower',rest:90,hint:'Band assist if needed'}, rdl:{name:'Romanian Deadlift',cat:'lower',rest:90},
  pull_up:{name:'Pull-Up',cat:'upper',rest:90,hint:'Band for assist'}, face_pull:{name:'Face Pull',cat:'upper',rest:60,hint:'Cable or band'},
  pallof_press:{name:'Pallof Press',cat:'core',rest:60,hint:'Anti-rotation · each side'}, dead_bug:{name:'Dead Bug',cat:'core',rest:45},
  bench_press:{name:'Bench Press',cat:'upper',rest:120}, deadlift:{name:'Deadlift',cat:'lower',rest:180},
  squat:{name:'Back Squat',cat:'lower',rest:150}, ohp:{name:'Overhead Press',cat:'upper',rest:90},
};

const STRENGTH_TEMPLATES = [
  {id:'str_a',name:'Strength A',tag:'Lower Focus',color:'#E8604C',exercises:[{id:'leg_press',sets:3,reps:10,weight:0},{id:'split_squat',sets:3,reps:10,weight:35},{id:'nordic_curl',sets:3,reps:6,weight:0},{id:'pallof_press',sets:2,reps:12,weight:20}]},
  {id:'str_b',name:'Strength B',tag:'Upper Focus',color:'#2BAFC4',exercises:[{id:'pull_up',sets:3,reps:8,weight:0},{id:'face_pull',sets:3,reps:15,weight:30},{id:'split_squat',sets:3,reps:10,weight:35},{id:'pallof_press',sets:2,reps:12,weight:20}]},
  {id:'str_c',name:'Strength C',tag:'Full Body',color:'#2ABF84',exercises:[{id:'leg_press',sets:3,reps:10,weight:0},{id:'rdl',sets:3,reps:10,weight:95},{id:'pull_up',sets:3,reps:8,weight:0},{id:'face_pull',sets:3,reps:15,weight:30}]},
];

const SPORT_META = {
  run:{icon:'run',color:'#E8604C',label:'Run'}, bike:{icon:'bike',color:'#2BAFC4',label:'Bike'},
  swim:{icon:'swim',color:'#4890D8',label:'Swim'}, strength:{icon:'dumbbell',color:'#2ABF84',label:'Strength'},
  brick:{icon:'layers',color:'#F0A830',label:'Brick'}, hike:{icon:'mountain',color:'#E87840',label:'Hike'},
  other:{icon:'target',color:'#A0A0BC',label:'Other'},
};

// ─── Utilities ─────────────────────────────────────────────────────────────────
const daysUntil = d => Math.ceil((new Date(d+'T12:00:00')-new Date())/86400000);
const fmtDur    = m => { if(!m)return'—'; const h=Math.floor(m/60),mn=m%60; return h>0?(mn>0?`${h}h ${mn}m`:`${h}h`):`${mn}m`; };
const fmtDateSh = d => new Date(d+'T12:00:00').toLocaleDateString('en-US',{month:'short',day:'numeric'});
const todayStr  = () => new Date().toISOString().split('T')[0];
const uid       = () => Math.random().toString(36).slice(2,10);
const epley     = (w,r) => r===1?w:Math.round(w*(1+r/30));
const getDayName= () => ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'][new Date().getDay()];
function renderMd(text){
  if(!text)return null;
  const inlineBold=(str,keyPfx)=>{const parts=[];let last=0;const re=/\*\*(.+?)\*\*/g;let m;while((m=re.exec(str))!==null){if(m.index>last)parts.push(str.slice(last,m.index));parts.push(<strong key={`${keyPfx}-${m.index}`}>{m[1]}</strong>);last=re.lastIndex;}if(last<str.length)parts.push(str.slice(last));return parts.length?parts:str;};
  return text.split('\n').map((line,i)=>{
    if(!line.trim())return <div key={i} style={{height:8}}/>;
    if(line.match(/^---+$/))return <div key={i} style={{height:1,background:C.border,margin:'12px 0'}}/>;
    const h1=line.match(/^#\s+(.*)$/);if(h1)return <div key={i} style={{fontFamily:F.display,fontSize:20,fontWeight:800,color:C.text,marginTop:16,marginBottom:6}}>{inlineBold(h1[1],`h1${i}`)}</div>;
    const h2=line.match(/^##\s+(.*)$/);if(h2)return <div key={i} style={{fontFamily:F.display,fontSize:17,fontWeight:700,color:C.text,marginTop:14,marginBottom:4}}>{inlineBold(h2[1],`h2${i}`)}</div>;
    const h3=line.match(/^###\s+(.*)$/);if(h3)return <div key={i} style={{fontFamily:F.ui,fontSize:15,fontWeight:700,color:C.text,marginTop:10,marginBottom:2}}>{inlineBold(h3[1],`h3${i}`)}</div>;
    const num=line.match(/^(\d+)[.)]\s+(.*)$/);if(num)return <div key={i} style={{display:'flex',gap:8,marginTop:2,marginBottom:2}}><span style={{color:C.accent,fontWeight:700,flexShrink:0,fontFamily:F.mono,fontSize:13,minWidth:18,textAlign:'right'}}>{num[1]}.</span><span>{inlineBold(num[2],`n${i}`)}</span></div>;
    const bullet=line.match(/^[-•*]\s+(.*)$/);if(bullet)return <div key={i} style={{display:'flex',gap:8,marginTop:2,marginBottom:2}}><span style={{color:C.muted,flexShrink:0}}>•</span><span>{inlineBold(bullet[1],`b${i}`)}</span></div>;
    return <div key={i}>{inlineBold(line,`l${i}`)}</div>;
  });
}
const db = { get(k,fb){try{const v=localStorage.getItem(k);return v?JSON.parse(v):fb;}catch{return fb;}}, set(k,v){try{localStorage.setItem(k,JSON.stringify(v));}catch{}} };

// ─── Toast ─────────────────────────────────────────────────────────────────────
let _addToast=null;
const toast={success:m=>_addToast?.(m,'success'),error:m=>_addToast?.(m,'error'),info:m=>_addToast?.(m,'info'),warn:m=>_addToast?.(m,'warn')};
function ToastManager(){const[toasts,setToasts]=useState([]);_addToast=useCallback((msg,type='success')=>{const id=uid();setToasts(p=>[...p.slice(-3),{id,msg,type}]);setTimeout(()=>setToasts(p=>p.filter(t=>t.id!==id)),2800);},[]);const meta={success:{color:C.green,icon:'✓'},error:{color:C.red,icon:'✕'},info:{color:C.cyan,icon:'ℹ'},warn:{color:C.yellow,icon:'!'}};return(<div style={{position:'fixed',top:100,left:'50%',transform:'translateX(-50%)',zIndex:9999,display:'flex',flexDirection:'column',gap:8,alignItems:'center',pointerEvents:'none',width:'calc(100% - 32px)',maxWidth:420}}>{toasts.map(t=>{const m=meta[t.type];return(<div key={t.id} style={{background:C.surface,borderRadius:14,padding:'12px 18px',display:'flex',alignItems:'center',gap:10,boxShadow:S.lg,animation:'toastIn .25s ease both',width:'100%',pointerEvents:'auto',border:`1.5px solid ${m.color}30`}}><div style={{width:26,height:26,borderRadius:8,background:m.color+'18',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}><span style={{color:m.color,fontSize:13,fontWeight:700}}>{m.icon}</span></div><span style={{fontFamily:F.ui,fontSize:14,color:C.text,fontWeight:500,lineHeight:1.4}}>{t.msg}</span></div>);})}</div>);}

// ─── Confirm ───────────────────────────────────────────────────────────────────
let _confirm=null;
const confirmDialog=(msg,sub)=>new Promise(r=>_confirm?.(msg,sub,r));
function ConfirmManager(){const[state,setState]=useState(null);_confirm=useCallback((msg,sub,resolve)=>setState({msg,sub,resolve}),[]);if(!state)return null;const respond=yes=>{state.resolve(yes);setState(null);};return(<div style={{position:'fixed',inset:0,background:'rgba(28,27,46,.4)',zIndex:8000,display:'flex',alignItems:'center',justifyContent:'center',padding:24,backdropFilter:'blur(4px)'}}><div className="fade-up" style={{background:C.surface,borderRadius:20,padding:28,width:'100%',maxWidth:320,boxShadow:S.lg}}><div style={{fontFamily:F.display,fontSize:20,fontWeight:700,color:C.text,marginBottom:state.sub?10:24}}>{state.msg}</div>{state.sub&&<div style={{fontFamily:F.ui,fontSize:15,color:C.subtle,marginBottom:24,lineHeight:1.65}}>{state.sub}</div>}<div style={{display:'flex',gap:10}}><button onClick={()=>respond(false)} style={{flex:1,padding:13,background:C.elevated,border:'none',borderRadius:12,color:C.subtle,fontFamily:F.display,fontSize:15,fontWeight:600,cursor:'pointer'}}>Cancel</button><button onClick={()=>respond(true)} style={{flex:1,padding:13,background:C.red,border:'none',borderRadius:12,color:'#fff',fontFamily:F.display,fontSize:15,fontWeight:600,cursor:'pointer'}}>Confirm</button></div></div></div>);}

async function callAI({system,messages,tools,tool_choice,max_tokens=1024}){const res=await fetch('/api/chat',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({system,messages,tools,tool_choice,max_tokens})});if(!res.ok)throw new Error(`API error ${res.status}`);const data=await res.json();if(data.error)throw new Error(data.error);return data;}

// ─── Shared UI ─────────────────────────────────────────────────────────────────
const Card=({children,style,onClick,accent})=>(<div onClick={onClick} style={{background:accent?accent+'08':C.card,border:`1.5px solid ${accent?accent+'30':C.border}`,borderRadius:16,padding:'16px 18px',cursor:onClick?'pointer':'default',transition:'all .18s',boxShadow:S.card,...style}} onMouseEnter={e=>{if(onClick){e.currentTarget.style.boxShadow=S.md;e.currentTarget.style.transform='translateY(-1px)';e.currentTarget.style.borderColor=accent?accent+'55':C.borderBright;}}} onMouseLeave={e=>{if(onClick){e.currentTarget.style.boxShadow=S.card;e.currentTarget.style.transform='none';e.currentTarget.style.borderColor=accent?accent+'30':C.border;}}}>{children}</div>);
const Label=({children,style})=><div style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:C.muted,textTransform:'uppercase',letterSpacing:'.08em',marginBottom:10,...style}}>{children}</div>;
const Pill=({children,color,small})=><span style={{display:'inline-flex',alignItems:'center',gap:4,background:(color||C.accent)+'15',color:color||C.accent,borderRadius:20,padding:small?'3px 10px':'4px 12px',fontFamily:F.ui,fontSize:small?11:12,fontWeight:600,whiteSpace:'nowrap'}}>{children}</span>;
const SportBadge=({sport,small})=>{const s=SPORT_META[sport]||SPORT_META.other;return (<span style={{display:'inline-flex',alignItems:'center',gap:4,background:s.color+'15',color:s.color,borderRadius:20,padding:small?'3px 10px':'4px 12px',fontFamily:F.ui,fontSize:small?11:12,fontWeight:600,whiteSpace:'nowrap'}}><Icon name={s.icon} size={small?11:13} color={s.color}/>{s.label}</span>);};
const Inp=({style,...props})=><input style={{background:C.elevated,border:`1.5px solid ${C.border}`,borderRadius:12,padding:'13px 16px',color:C.text,fontFamily:F.ui,fontSize:15,outline:'none',width:'100%',transition:'all .15s',...style}} onFocus={e=>{e.target.style.borderColor=C.accent;e.target.style.background=C.surface;}} onBlur={e=>{e.target.style.borderColor=C.border;e.target.style.background=C.elevated;}} {...props}/>;
const Btn=({children,onClick,color,outline,style,disabled})=><button onClick={onClick} disabled={disabled} style={{background:outline?'transparent':(disabled?C.elevated:(color||C.accent)),border:`1.5px solid ${outline?C.border:(disabled?C.elevated:(color||C.accent))}`,borderRadius:14,padding:'13px 22px',color:disabled?C.muted:(outline?C.subtle:'#fff'),fontFamily:F.display,fontSize:16,fontWeight:700,cursor:disabled?'not-allowed':'pointer',transition:'all .15s',...style}}>{children}</button>;
const DotsLoader=({color})=><div style={{display:'flex',gap:5,padding:'4px 0'}}>{[0,1,2].map(n=><div key={n} style={{width:7,height:7,borderRadius:'50%',background:color||C.muted,animation:`blink 1.3s ease-in-out ${n*.22}s infinite`}}/>)}</div>;
const Spinner=({color,size=16})=><div style={{width:size,height:size,borderRadius:'50%',border:`2px solid ${(color||C.accent)}30`,borderTop:`2px solid ${color||C.accent}`,animation:'spin .8s linear infinite'}}/>;
const Textarea=({style,...props})=><textarea style={{background:C.elevated,border:`1.5px solid ${C.border}`,borderRadius:12,padding:'13px 16px',color:C.text,fontFamily:F.ui,fontSize:15,outline:'none',width:'100%',resize:'none',lineHeight:1.7,transition:'all .15s',...style}} onFocus={e=>{e.target.style.borderColor=C.accent;e.target.style.background=C.surface;}} onBlur={e=>{e.target.style.borderColor=C.border;e.target.style.background=C.elevated;}} {...props}/>;
const Sheet=({children,onClose,title})=>(<div style={{position:'fixed',inset:0,background:'rgba(28,27,46,.35)',zIndex:200,display:'flex',alignItems:'flex-end',justifyContent:'center',backdropFilter:'blur(3px)'}} onClick={onClose}><div onClick={e=>e.stopPropagation()} className="fade-up" style={{background:C.surface,borderRadius:'24px 24px 0 0',width:'100%',maxWidth:500,padding:'24px 20px 52px',maxHeight:'92vh',overflowY:'auto',boxShadow:'0 -4px 32px rgba(28,27,46,.12)'}}><div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:20}}><div style={{fontFamily:F.display,fontSize:22,fontWeight:800,color:C.text,letterSpacing:'-.01em'}}>{title}</div><button onClick={onClose} style={{width:32,height:32,borderRadius:10,background:C.elevated,border:'none',color:C.subtle,fontSize:16,cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center'}}>✕</button></div>{children}</div></div>);

// ─── Toggle ────────────────────────────────────────────────────────────────────
function Toggle({ on, onToggle }) {
  return (
    <div onClick={onToggle} style={{width:50,height:28,borderRadius:14,background:on?C.accent:C.border,position:'relative',cursor:'pointer',transition:'background .25s',flexShrink:0}}>
      <div style={{position:'absolute',top:3,left:on?25:3,width:22,height:22,borderRadius:'50%',background:'#fff',transition:'left .25s cubic-bezier(.4,0,.2,1)',boxShadow:'0 1px 4px rgba(0,0,0,.28)'}}/>
    </div>
  );
}

// ─── Training plan generator ───────────────────────────────────────────────────
function generateWeeklyPlan(events) {
  const active=events.filter(e=>!e.completed);
  if (!active.length) return [];
  const types=[...new Set(active.map(e=>presetById(e.presetId).planType))];
  const hasTri=types.includes('tri'),hasRun=types.includes('run'),hasStr=types.includes('strength');
  if (hasTri) return [
    {day:'Monday',    sessions:[{type:'strength',templateId:'str_a',label:'Strength A',notes:'Lower focus — leg press, split squats, Nordics',fuel:'Pre: light snack 60min before · Post: protein + carbs within 30min',sport:'strength'}]},
    {day:'Tuesday',   sessions:[{type:'run',sport:'run',duration:45,label:'Easy Run',notes:'Zone 2 · conversational pace',fuel:'Pre: banana + coffee 90min before · Post: protein shake or chocolate milk'},{type:'swim',sport:'swim',duration:30,label:'Swim',notes:'Technique drills · 1500–2000m',fuel:'Pre: light snack if needed · water during'}]},
    {day:'Wednesday', sessions:[{type:'strength',templateId:'str_b',label:'Strength B',notes:'Upper focus — pull-ups, face pulls',fuel:'Pre: light snack 60min before · Post: protein + carbs within 30min',sport:'strength'}]},
    {day:'Thursday',  sessions:[{type:'bike',sport:'bike',duration:60,label:'Zone 2 Ride',notes:'Steady aerobic effort',fuel:'Pre: oatmeal or toast 2hrs before · During: water + electrolytes · Post: recovery meal'},{type:'run',sport:'run',duration:20,label:'Brick Run',notes:'Off the bike · easy pace',fuel:'Practice race-day nutrition — eat what you\'ll use on race day'}]},
    {day:'Friday',    sessions:[]},
    {day:'Saturday',  sessions:[{type:'bike',sport:'bike',duration:90,label:'Long Ride',notes:'Build endurance · practice fueling',fuel:'Pre: full breakfast 2-3hrs before (60-80g carbs) · During: 1 gel every 45min + electrolytes · Post: protein + carbs within 30min'}]},
    {day:'Sunday',    sessions:[{type:'run',sport:'run',duration:75,label:'Long Run',notes:'Easy aerobic build',fuel:'Pre: oatmeal + banana 2hrs before · During: water, gel at 45min if needed · Post: recovery meal with protein'}]},
  ];
  if (hasRun) return [
    {day:'Monday',    sessions:[{type:'strength',templateId:'str_a',label:'Strength',notes:'Strength + mobility',sport:'strength'}]},
    {day:'Tuesday',   sessions:[{type:'run',sport:'run',duration:40,label:'Easy Run',notes:'Comfortable, conversational'}]},
    {day:'Wednesday', sessions:[{type:'run',sport:'run',duration:50,label:'Tempo Run',notes:'Comfortably hard effort'}]},
    {day:'Thursday',  sessions:[{type:'strength',templateId:'str_b',label:'Strength',notes:'Upper + core',sport:'strength'}]},
    {day:'Friday',    sessions:[]},
    {day:'Saturday',  sessions:[{type:'run',sport:'run',duration:90,label:'Long Run',notes:'Easy pace · build your base'}]},
    {day:'Sunday',    sessions:[{type:'run',sport:'run',duration:30,label:'Recovery Run',notes:'Very easy · flush the legs'}]},
  ];
  if (hasStr) return [
    {day:'Monday',    sessions:[{type:'strength',templateId:'str_a',label:'Strength A',notes:'Lower body',sport:'strength'}]},
    {day:'Tuesday',   sessions:[{type:'other',sport:'other',duration:30,label:'Conditioning',notes:'Easy cardio · active recovery'}]},
    {day:'Wednesday', sessions:[{type:'strength',templateId:'str_b',label:'Strength B',notes:'Upper + pull',sport:'strength'}]},
    {day:'Thursday',  sessions:[{type:'other',sport:'other',duration:30,label:'Cardio',notes:'Light cardio of choice'}]},
    {day:'Friday',    sessions:[{type:'strength',templateId:'str_c',label:'Strength C',notes:'Full body',sport:'strength'}]},
    {day:'Saturday',  sessions:[]},{day:'Sunday',sessions:[]},
  ];
  return ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'].map(day=>({day,sessions:[]}));
}


// ─── Settings Page ─────────────────────────────────────────────────────────────
function AthleteProfilePage({onClose}){
  const[mem,setMem]=useState(()=>loadMemory());
  const[showChat,setShowChat]=useState(false);
  const[msgs,setMsgs]=useState([]);
  const[input,setInput]=useState('');
  const[loading,setLoading]=useState(false);
  const[isStreaming,setIsStreaming]=useState(false);
  const[streamText,setStreamText]=useState('');
  const bottomRef=useRef(null);
  const chainRef=useRef([]);

  const refreshMem=()=>setMem(loadMemory());

  const profilePrompt=`You are updating an athlete's coaching profile. The athlete is sharing information about themselves. Your job:
1. Acknowledge what they shared (1-2 sentences)
2. Extract facts and update the coaching memory appropriately
3. Ask a follow-up question to learn more — pick from gaps you notice (schedule, equipment, injuries, goals, preferences, nutrition habits, training history)
4. Keep it conversational and brief — this is mobile.

After each message, internally categorize info into: profile (schedule, equipment, preferences), physical (injuries, strengths, limiters), behavioral (patterns, motivators), or coaching (focus areas, open items).

Today: ${new Date().toISOString().split('T')[0]}`;

  const sendMsg=async(text)=>{
    const userMsg={role:'user',content:text};
    const updated=[...msgs,userMsg];
    setMsgs(updated);setInput('');setLoading(true);
    const chain=chainRef.current.length?[...chainRef.current,{role:'user',content:text}]:[{role:'user',content:text}];
    try{
      const resp=await callAI({system:profilePrompt,messages:chain,tools:TOOLS.filter(t=>t.name==='get_athlete_profile'),max_tokens:800});
      const textContent=resp.content?.filter(b=>b.type==='text')?.map(b=>b.text)?.join('')?.trim()||'';
      chainRef.current=[...chain,{role:'assistant',content:textContent}];
      setLoading(false);setIsStreaming(true);setStreamText('');
      await typewriter(textContent,chunk=>setStreamText(chunk));
      setMsgs(prev=>[...prev,{role:'assistant',content:textContent}]);
      setIsStreaming(false);setStreamText('');
      // Extract and save to memory
      try{
        const extract=await callAI({system:`Extract facts from this conversation into coaching memory JSON. Return ONLY JSON matching this structure (include only fields with new info, omit empty fields):
{"profile":{"communicationStyle":"","preferredWorkoutTimes":"","equipment":""},"physical":{"injuries":[],"strengths":[],"limiters":[]},"behavioral":{"patterns":[],"motivators":[],"consistency":""},"coaching":{"currentFocus":"","openItems":[]}}
If no extractable facts, return {}.`,messages:[{role:'user',content:chainRef.current.map(m=>`${m.role==='user'?'Athlete':'Coach'}: ${m.content}`).join('\n')}],max_tokens:400});
        const raw=extract.content?.filter(b=>b.type==='text')?.map(b=>b.text)?.join('')||'';
        const parsed=JSON.parse(raw.replace(/```json\n?|\n?```/g,'').trim());
        if(Object.keys(parsed).length>0){saveMemory(mergeMemory(loadMemory(),parsed));refreshMem();}
      }catch{}
    }catch(err){setLoading(false);setIsStreaming(false);setMsgs(prev=>[...prev,{role:'assistant',content:`Something went wrong: ${err.message}`}]);}
  };

  const Section=({icon,color,title,children,empty})=>(
    <Card style={{marginBottom:12}}>
      <div style={{display:'flex',alignItems:'center',gap:10,marginBottom:children?10:0}}>
        <div style={{width:32,height:32,borderRadius:10,background:color+'18',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}><Icon name={icon} size={16} color={color}/></div>
        <div style={{fontFamily:F.ui,fontWeight:700,fontSize:15,color:C.text}}>{title}</div>
      </div>
      {children||<div style={{fontFamily:F.ui,fontSize:13,color:C.muted,fontStyle:'italic',marginTop:4}}>{empty||'Your coach hasn\'t learned this yet'}</div>}
    </Card>
  );

  const hasProfile=mem.profile?.communicationStyle||mem.profile?.preferredWorkoutTimes||mem.profile?.equipment;
  const hasPhysical=mem.physical?.injuries?.length||mem.physical?.strengths?.length||mem.physical?.limiters?.length;
  const hasBehavioral=mem.behavioral?.patterns?.length||mem.behavioral?.motivators?.length||mem.behavioral?.consistency;
  const hasCoaching=mem.coaching?.currentFocus||mem.coaching?.openItems?.length;

  return(<div className="slide-in" style={{position:'fixed',inset:0,background:C.bg,zIndex:100,overflowY:'auto'}}>
    <div style={{background:C.bg+'F6',backdropFilter:'blur(20px)',borderBottom:`1px solid ${C.border}`,padding:'16px 20px',display:'flex',alignItems:'center',gap:12,position:'sticky',top:0,zIndex:10}}>
      <button onClick={onClose} style={{borderRadius:12,background:C.elevated,border:`1.5px solid ${C.border}`,color:C.text,cursor:'pointer',display:'flex',alignItems:'center',gap:4,padding:'8px 14px 8px 10px',flexShrink:0}}><Icon name='arrowLeft' size={16}/><span style={{fontFamily:F.ui,fontSize:13,fontWeight:600}}>Back</span></button>
      <div style={{fontFamily:F.display,fontSize:22,fontWeight:800,color:C.text,letterSpacing:'-.01em'}}>Athlete Profile</div>
    </div>

    <div style={{padding:'20px 16px 48px'}}>
      <div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,lineHeight:1.7,marginBottom:20}}>This is what your coach knows about you. The more you share, the better the coaching.</div>

      <Section icon="run" color={C.accent} title="Training" empty="Tell your coach about your schedule, equipment, and preferences">
        {hasProfile&&<div style={{display:'flex',flexDirection:'column',gap:8}}>
          {mem.profile.preferredWorkoutTimes&&<div style={{display:'flex',gap:8}}><Icon name='calendar' size={13} color={C.muted}/><span style={{fontFamily:F.ui,fontSize:14,color:C.text}}>{mem.profile.preferredWorkoutTimes}</span></div>}
          {mem.profile.equipment&&<div style={{display:'flex',gap:8}}><Icon name='dumbbell' size={13} color={C.muted}/><span style={{fontFamily:F.ui,fontSize:14,color:C.text}}>{mem.profile.equipment}</span></div>}
          {mem.profile.communicationStyle&&<div style={{display:'flex',gap:8}}><Icon name='message' size={13} color={C.muted}/><span style={{fontFamily:F.ui,fontSize:14,color:C.text}}>{mem.profile.communicationStyle}</span></div>}
        </div>}
      </Section>

      <Section icon="alert" color={C.yellow} title="Physical" empty="Share any injuries, strengths, or areas to work on">
        {hasPhysical&&<div>
          {mem.physical.injuries?.length>0&&<div style={{marginBottom:8}}>{mem.physical.injuries.map((inj,i)=><div key={i} style={{display:'flex',alignItems:'center',gap:8,padding:'6px 0',borderTop:i>0?`1px solid ${C.border}`:'none'}}>
            <Pill color={inj.status==='resolved'?C.green:inj.status==='monitoring'?C.yellow:C.red} small>{inj.status}</Pill>
            <span style={{fontFamily:F.ui,fontSize:14,color:C.text}}>{inj.area}</span>
            {inj.notes&&<span style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginLeft:'auto'}}>{inj.notes}</span>}
          </div>)}</div>}
          {mem.physical.strengths?.length>0&&<div style={{marginBottom:8}}><div style={{fontFamily:F.ui,fontSize:11,fontWeight:600,color:C.green,marginBottom:4}}>STRENGTHS</div><div style={{display:'flex',gap:6,flexWrap:'wrap'}}>{mem.physical.strengths.map((s,i)=><Pill key={i} color={C.green} small>{s}</Pill>)}</div></div>}
          {mem.physical.limiters?.length>0&&<div><div style={{fontFamily:F.ui,fontSize:11,fontWeight:600,color:C.accent,marginBottom:4}}>LIMITERS</div><div style={{display:'flex',gap:6,flexWrap:'wrap'}}>{mem.physical.limiters.map((l,i)=><Pill key={i} color={C.accent} small>{l}</Pill>)}</div></div>}
        </div>}
      </Section>

      <Section icon="clipboard" color={C.cyan} title="Patterns" empty="Your coach will notice patterns as you train">
        {hasBehavioral&&<div>
          {mem.behavioral.patterns?.map((p,i)=><div key={i} style={{display:'flex',gap:8,padding:'6px 0',borderTop:i>0?`1px solid ${C.border}`:'none'}}><span style={{color:C.cyan,flexShrink:0}}>•</span><span style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.5}}>{p}</span></div>)}
          {mem.behavioral.consistency&&<div style={{marginTop:8,fontFamily:F.ui,fontSize:13,color:C.muted,fontStyle:'italic'}}>{mem.behavioral.consistency}</div>}
          {mem.behavioral.motivators?.length>0&&<div style={{marginTop:8,display:'flex',gap:6,flexWrap:'wrap'}}>{mem.behavioral.motivators.map((m,i)=><Pill key={i} color={C.purple} small>{m}</Pill>)}</div>}
        </div>}
      </Section>

      <Section icon="target" color={C.purple} title="Coaching Focus" empty="Your coach will set focus areas as training progresses">
        {hasCoaching&&<div>
          {mem.coaching.currentFocus&&<div style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.6,marginBottom:8}}>{mem.coaching.currentFocus}</div>}
          {mem.coaching.openItems?.map((item,i)=><div key={i} style={{display:'flex',gap:8,padding:'5px 0'}}><span style={{color:C.purple,flexShrink:0,fontSize:12}}>○</span><span style={{fontFamily:F.ui,fontSize:14,color:C.subtle}}>{item}</span></div>)}
        </div>}
      </Section>

      <Btn onClick={()=>setShowChat(true)} color={C.accent} style={{width:'100%',padding:15,fontSize:16,marginTop:8}}>Tell your coach more</Btn>
    </div>

    {showChat&&<Sheet onClose={()=>{setShowChat(false);refreshMem();}} title="Update your profile">
      <div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,marginBottom:16,lineHeight:1.6}}>Share anything that would help your coach — schedule, equipment, injuries, preferences, goals.</div>
      <div style={{maxHeight:'45vh',overflowY:'auto',display:'flex',flexDirection:'column',gap:10,marginBottom:16}}>
        {msgs.filter(m=>m.role==='assistant').map((m,i)=><div key={i} className="fade-up" style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.75}}>{renderMd(m.content)}</div>)}
        {isStreaming&&streamText&&<div className="fade-up" style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.75}}>{renderMd(streamText)}</div>}
        {loading&&!isStreaming&&<DotsLoader color={C.accent}/>}
        <div ref={bottomRef}/>
      </div>
      <div style={{display:'flex',gap:8}}>
        <Inp value={input} onChange={e=>setInput(e.target.value)} onKeyDown={e=>e.key==='Enter'&&!loading&&input.trim()&&sendMsg(input.trim())} placeholder="e.g. I train mornings, have a pool and Wahoo Kickr..." style={{flex:1}}/>
        <button onClick={()=>input.trim()&&!loading&&sendMsg(input.trim())} disabled={!input.trim()||loading} style={{width:48,height:48,background:!input.trim()||loading?C.elevated:C.accent,border:'none',borderRadius:12,cursor:!input.trim()||loading?'not-allowed':'pointer',color:!input.trim()||loading?C.muted:'#fff',fontSize:18,display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>↑</button>
      </div>
    </Sheet>}
  </div>);
}

function SettingsPage({ personality, customPrompt, onPersonalityChange, onCustomPromptChange, isDark, onToggleDark, onClose }) {
  const [localCustom, setLocalCustom] = useState(customPrompt||'');
  const [saved, setSaved] = useState(false);
  const [showProfile, setShowProfile] = useState(false);
  const mem = loadMemory();
  const hasMemory = mem.behavioral?.patterns?.length||mem.physical?.injuries?.length||mem.coaching?.openItems?.length;

  const handleCustomSave = () => { onCustomPromptChange(localCustom); setSaved(true); setTimeout(()=>setSaved(false),2000); toast.success('Custom coach saved'); };
  const resetMemory = async () => { const ok=await confirmDialog('Reset coaching memory?','The coach will start fresh — all learned patterns and history cleared.'); if(!ok)return; saveMemory(defaultMemory()); toast.info('Coaching memory reset'); };
  const exportData = () => { const data={exportedAt:new Date().toISOString(),events:db.get('coach_events',[]),cardio:db.get('coach_cardio',[]),strength:db.get('coach_strength_history',[]),prs:db.get('coach_prs',{}),nutrition:db.get('coach_nutrition',[]),trainingPlan:db.get('coach_training_plan',null),bricks:db.get('coach_bricks',[]),memory:loadMemory()}; const blob=new Blob([JSON.stringify(data,null,2)],{type:'application/json'}); const url=URL.createObjectURL(blob); const a=document.createElement('a'); a.href=url; a.download=`coach-export-${todayStr()}.json`; a.click(); URL.revokeObjectURL(url); toast.success('Data exported'); };
  const loadSeedData = async () => { const ok=await confirmDialog('Load test data?','This will replace all current data with sample training data for testing.'); if(!ok)return; try{const res=await fetch('/seed-data.json');const d=await res.json();db.set('coach_events',d.events||[]);db.set('coach_cardio',d.cardio||[]);db.set('coach_strength_history',d.strengthHistory||[]);db.set('coach_prs',d.prs||{});db.set('coach_nutrition',d.nutrition||[]);db.set('coach_bricks',d.bricks||[]);if(d.memory)saveMemory(d.memory);db.set('coach_messages',[]);toast.success('Test data loaded — reload the app');setTimeout(()=>window.location.reload(),1000);}catch(e){toast.error('Failed to load seed data');} };

  return (
    <div className="slide-in" style={{position:'fixed',inset:0,background:C.bg,zIndex:100,overflowY:'auto'}}>
      <div style={{background:C.bg+'F6',backdropFilter:'blur(20px)',borderBottom:`1px solid ${C.border}`,padding:'16px 20px',display:'flex',alignItems:'center',gap:12,position:'sticky',top:0,zIndex:10}}>
        <button onClick={onClose} style={{borderRadius:12,background:C.elevated,border:`1.5px solid ${C.border}`,color:C.text,cursor:'pointer',display:'flex',alignItems:'center',gap:4,padding:'8px 14px 8px 10px',flexShrink:0}}><Icon name='arrowLeft' size={16}/><span style={{fontFamily:F.ui,fontSize:13,fontWeight:600}}>Back</span></button>
        <div style={{fontFamily:F.display,fontSize:22,fontWeight:800,color:C.text,letterSpacing:'-.01em'}}>Settings</div>
      </div>

      <div style={{padding:'20px 16px 48px'}}>

        {/* Appearance */}
        <div style={{marginBottom:32}}>
          <Label>Appearance</Label>
          <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',padding:'14px 18px',background:C.card,borderRadius:14,border:`1.5px solid ${C.border}`,boxShadow:S.card}}>
            <div style={{display:'flex',alignItems:'center',gap:12}}>
              <div style={{width:38,height:38,borderRadius:12,background:C.elevated,display:'flex',alignItems:'center',justifyContent:'center',}}>{isDark?<Icon name='moon' size={20} color={C.muted}/>:<Icon name='sun' size={20} color={C.yellow}/>}</div>
              <div>
                <div style={{fontFamily:F.ui,fontWeight:600,fontSize:15,color:C.text}}>{isDark?'Dark mode':'Light mode'}</div>
                <div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:1}}>{isDark?'Easy on the eyes at night':'Clean and bright'}</div>
              </div>
            </div>
            <Toggle on={isDark} onToggle={onToggleDark}/>
          </div>
        </div>

        {/* Coach mode */}
        <div style={{marginBottom:32}}>
          <Label>Coach mode</Label>
          <div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,marginBottom:16,lineHeight:1.65}}>Choose how your coach communicates. Affects chat and the daily coaching analysis.</div>
          {['normal','goggins','hype'].map(key=>{
            const p=PERSONALITIES[key]; const sel=personality===key;
            return(
              <div key={key} onClick={()=>onPersonalityChange(key)} style={{marginBottom:10,background:sel?p.color+'10':C.card,border:`2px solid ${sel?p.color:C.border}`,borderRadius:18,padding:'18px 20px',cursor:'pointer',transition:'all .18s',boxShadow:sel?S.md:S.card}} onMouseEnter={e=>{if(!sel){e.currentTarget.style.borderColor=p.color+'66';e.currentTarget.style.background=p.color+'08';}}} onMouseLeave={e=>{if(!sel){e.currentTarget.style.borderColor=C.border;e.currentTarget.style.background=C.card;}}}>
                <div style={{display:'flex',alignItems:'flex-start',gap:14}}>
                  <div style={{width:52,height:52,borderRadius:16,background:p.color+'20',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}><Icon name={p.icon} size={26} color={p.color}/></div>
                  <div style={{flex:1}}>
                    <div style={{display:'flex',alignItems:'center',gap:10,marginBottom:4}}>
                      <div style={{fontFamily:F.display,fontSize:20,fontWeight:700,color:sel?p.color:C.text}}>{p.name}</div>
                      {sel&&<div style={{width:10,height:10,borderRadius:'50%',background:p.color,flexShrink:0}}/>}
                    </div>
                    <div style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:p.color,marginBottom:6}}>{p.tagline}</div>
                    <div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,lineHeight:1.65}}>{p.description}</div>
                  </div>
                </div>
                {key==='goggins'&&sel&&<div style={{marginTop:14,padding:'10px 14px',background:C.red+'12',borderRadius:10,border:`1px solid ${C.red}30`}}><div style={{fontFamily:F.ui,fontSize:13,color:C.red,fontWeight:600}}>This mode is brutally honest. No mercy, no excuses.</div></div>}
              </div>
            );
          })}

          {/* Custom */}
          {(()=>{const p=PERSONALITIES.custom;const sel=personality==='custom';return(<div style={{marginBottom:10}}><div onClick={()=>onPersonalityChange('custom')} style={{background:sel?p.color+'10':C.card,border:`2px solid ${sel?p.color:C.border}`,borderRadius:18,padding:'18px 20px',cursor:'pointer',transition:'all .18s',boxShadow:sel?S.md:S.card}} onMouseEnter={e=>{if(!sel){e.currentTarget.style.borderColor=p.color+'66';e.currentTarget.style.background=p.color+'08';}}} onMouseLeave={e=>{if(!sel){e.currentTarget.style.borderColor=C.border;e.currentTarget.style.background=C.card;}}}><div style={{display:'flex',alignItems:'flex-start',gap:14}}><div style={{width:52,height:52,borderRadius:16,background:p.color+'20',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}><Icon name={p.icon} size={26} color={p.color}/></div><div style={{flex:1}}><div style={{display:'flex',alignItems:'center',gap:10,marginBottom:4}}><div style={{fontFamily:F.display,fontSize:20,fontWeight:700,color:sel?p.color:C.text}}>{p.name}</div>{sel&&<div style={{width:10,height:10,borderRadius:'50%',background:p.color,flexShrink:0}}/>}</div><div style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:p.color,marginBottom:6}}>{p.tagline}</div><div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,lineHeight:1.65}}>{p.description}</div></div></div></div>{sel&&<div className="fade-up" style={{background:C.purple+'08',border:`2px solid ${C.purple}30`,borderRadius:16,padding:'16px 18px',marginTop:8}}><div style={{fontFamily:F.ui,fontSize:14,fontWeight:600,color:C.purple,marginBottom:8}}>Describe your ideal coach</div><div style={{fontFamily:F.ui,fontSize:13,color:C.subtle,marginBottom:12,lineHeight:1.65}}>Write a few sentences. Your words become the coaching style. Examples: "Be like my college coach — tough but fair, always cite the science." or "Gentle and supportive, I struggle with anxiety."</div><Textarea placeholder="e.g. Talk to me like I'm training for the Olympics. Always reference the data. Push me when I make excuses, but celebrate real wins..." value={localCustom} onChange={e=>setLocalCustom(e.target.value)} rows={5} style={{marginBottom:12}}/><Btn onClick={handleCustomSave} color={C.purple} disabled={!localCustom.trim()} style={{width:'100%',fontSize:15}}>{saved?'✓ Saved':'Save custom coach'}</Btn></div>}</div>);})()}
        </div>

        {/* Profile & Memory */}
        <div style={{marginBottom:32}}>
          <Label>Athlete profile</Label>
          <Card onClick={()=>setShowProfile(true)} accent={C.accent} style={{marginBottom:10}}>
            <div style={{display:'flex',alignItems:'center',gap:12}}><div style={{width:36,height:36,borderRadius:12,background:C.accent+'18',display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name='run' size={18} color={C.accent}/></div><div style={{flex:1}}><div style={{fontFamily:F.ui,fontWeight:700,fontSize:14,color:C.accent}}>View athlete profile</div><div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:1}}>See what your coach knows about you</div></div><span style={{color:C.accent}}>→</span></div>
          </Card>
          {hasMemory&&<button onClick={resetMemory} style={{background:'none',border:`1.5px solid ${C.border}`,borderRadius:12,padding:'11px 16px',color:C.muted,fontFamily:F.ui,fontSize:13,fontWeight:500,cursor:'pointer',width:'100%',transition:'all .15s',marginTop:4}} onMouseEnter={e=>{e.currentTarget.style.borderColor=C.red;e.currentTarget.style.color=C.red;}} onMouseLeave={e=>{e.currentTarget.style.borderColor=C.border;e.currentTarget.style.color=C.muted;}}>Reset coaching memory</button>}
        </div>

        {/* Data */}
        <div style={{marginBottom:32}}>
          <Label>Your data</Label>
          <Card onClick={exportData} accent={C.cyan}>
            <div style={{display:'flex',alignItems:'center',gap:12}}><div style={{width:36,height:36,borderRadius:12,background:C.cyan+'18',display:'flex',alignItems:'center',justifyContent:'center',}}><Icon name='upload' size={18} color={C.cyan}/></div><div><div style={{fontFamily:F.ui,fontWeight:700,fontSize:14,color:C.cyan}}>Export all data</div><div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:1}}>Download workouts, goals, and history as JSON</div></div></div>
          </Card>
          <Card onClick={loadSeedData} accent={C.yellow} style={{marginTop:10}}>
            <div style={{display:'flex',alignItems:'center',gap:12}}><div style={{width:36,height:36,borderRadius:12,background:C.yellow+'18',display:'flex',alignItems:'center',justifyContent:'center',}}><Icon name='zap' size={18} color={C.yellow}/></div><div><div style={{fontFamily:F.ui,fontWeight:700,fontSize:14,color:C.yellow}}>Load test data</div><div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:1}}>Replace with sample triathlon training data</div></div></div>
          </Card>
        </div>

        {/* About */}
        <div>
          <Label>About</Label>
          <Card><div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,lineHeight:1.8}}><div style={{display:'flex',justifyContent:'space-between',marginBottom:4}}><span style={{fontWeight:600}}>Coach App</span><span style={{color:C.muted}}>v1.0</span></div><div style={{color:C.muted,fontSize:13}}>AI-powered personal training. Your data stays on your device.</div></div></Card>
        </div>
      </div>
      {showProfile&&<AthleteProfilePage onClose={()=>setShowProfile(false)}/>}
    </div>
  );
}

// ─── Today's Session Card ──────────────────────────────────────────────────────
function TodaySessionCard({ plan, cardio, strength, onStartStrength, setTab, trainingPlan }) {
  const today=getDayName(); const td=todayStr();
  const todayC=cardio.filter(w=>w.date===td); const todayS=strength.filter(s=>s.date===td);

  // Try periodized plan first
  const tp=trainingPlan;
  const weekPlan=tp?.weeklyPlans?.[String(tp.currentWeek)];
  const tpToday=weekPlan?.sessions?.find(d=>d.day===today);

  if(tpToday){
    const daySessions=tpToday.sessions||[];
    if(tpToday.isRest||!daySessions.length) return (<Card style={{marginBottom:16,background:`linear-gradient(135deg,${C.elevated},${C.card})`,borderColor:C.border}}><div style={{display:'flex',alignItems:'center',gap:12}}><div style={{width:44,height:44,borderRadius:14,background:C.elevated,display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name='rest' size={22} color={C.muted}/></div><div><div style={{fontFamily:F.display,fontSize:18,fontWeight:700,color:C.text}}>Rest Day</div><div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,marginTop:2}}>Recovery is training. Let the body adapt.</div></div></div></Card>);
    const isSessDone=s=>{if(s.type==='brick')return(s.legs||[]).every(l=>todayC.some(w=>w.sport===l.sport));if(s.type==='strength')return todayS.some(sh=>sh.templateId===s.templateId);return todayC.some(w=>w.sport===s.type);};
    const allDone=daySessions.every(isSessDone);
    return (<Card accent={allDone?C.green:C.accent} style={{marginBottom:16}}>
      <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:12}}>
        <div><div style={{fontFamily:F.display,fontSize:18,fontWeight:700,color:allDone?C.green:C.accent}}>{allDone?'✓ Today complete':"Today's sessions"}</div><div style={{fontFamily:F.ui,fontSize:13,color:C.subtle,marginTop:1}}>{today}</div></div>
        {allDone&&<Pill color={C.green}>Done</Pill>}
      </div>
      <div style={{display:'flex',flexDirection:'column',gap:8}}>{daySessions.map((sess,i)=>{
        if(sess.type==='brick'&&sess.legs){
          const brickDone=(sess.legs||[]).every(l=>todayC.some(w=>w.sport===l.sport));
          return (<div key={i} style={{borderRadius:12,border:`1.5px solid ${brickDone?C.green+'44':C.yellow+'40'}`,overflow:'hidden',background:brickDone?C.green+'08':C.elevated}}>
            <div style={{padding:'8px 14px',background:C.yellow+'10',display:'flex',alignItems:'center',gap:8}}>
              <Icon name='layers' size={14} color={C.yellow}/><span style={{fontFamily:F.ui,fontWeight:700,fontSize:13,color:C.yellow}}>Brick</span>
              {sess.priority&&<div style={{width:6,height:6,borderRadius:'50%',background:sess.priority==='red'?C.accent:C.yellow}}/>}
              <span style={{fontFamily:F.ui,fontSize:13,color:C.text,flex:1}}>{sess.label}</span>
              {brickDone&&<Pill color={C.green} small>Done</Pill>}
            </div>
            {sess.legs.map((leg,li)=>{const lSport=SPORT_META[leg.sport]||SPORT_META.other;const lDone=todayC.some(w=>w.sport===leg.sport);return(
              <div key={li} onClick={!lDone?()=>setTab('log'):undefined} style={{display:'flex',alignItems:'center',gap:12,padding:'10px 14px',borderTop:li>0?`1px solid ${C.border}`:'none',cursor:!lDone?'pointer':'default'}}>
                <div style={{width:32,height:32,borderRadius:10,background:lDone?C.green+'20':lSport.color+'20',display:'flex',alignItems:'center',justifyContent:'center'}}>{lDone?<Icon name='check' size={15} color={C.green}/>:<Icon name={lSport.icon} size={15} color={lSport.color}/>}</div>
                <div style={{flex:1}}><span style={{fontFamily:F.ui,fontWeight:500,fontSize:14,color:lDone?C.green:C.text}}>{lSport.label}{leg.notes?' · '+leg.notes:''}</span></div>
                {leg.duration&&<span style={{fontFamily:F.mono,fontSize:12,color:C.muted}}>{fmtDur(leg.duration)}</span>}
                {!lDone&&<span style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:lSport.color}}>Log →</span>}
              </div>);})}
          </div>);
        }
        const sport=SPORT_META[sess.type]||SPORT_META.other;
        const isStr=sess.type==='strength';
        const done=isSessDone(sess);
        const accent=done?C.green:sport.color;
        return (<div key={i} onClick={isStr&&!done&&sess.templateId?()=>{onStartStrength(sess.templateId);setTab('plan');}:(!done?()=>setTab('log'):undefined)} style={{display:'flex',alignItems:'center',gap:12,padding:'11px 14px',background:done?C.green+'0A':C.elevated,borderRadius:12,border:`1.5px solid ${done?C.green+'44':accent+'30'}`,cursor:!done?'pointer':'default',transition:'all .15s'}}>
          <div style={{width:36,height:36,borderRadius:12,background:accent+'20',display:'flex',alignItems:'center',justifyContent:'center'}}>{done?<Icon name='check' size={17} color={C.green}/>:<Icon name={isStr?'dumbbell':sport.icon} size={17} color={accent}/>}</div>
          <div style={{flex:1}}>
            <div style={{display:'flex',alignItems:'center',gap:6}}>{sess.priority&&<div style={{width:6,height:6,borderRadius:'50%',background:sess.priority==='red'?C.accent:C.yellow}}/>}<div style={{fontFamily:F.ui,fontWeight:600,fontSize:15,color:done?C.green:C.text}}>{sess.label}</div></div>
            {sess.notes&&<div style={{fontFamily:F.ui,fontSize:13,color:C.subtle,marginTop:1,lineHeight:1.4}}>{sess.notes}</div>}
          </div>
          {sess.duration&&<div style={{fontFamily:F.mono,fontSize:12,color:C.muted}}>{fmtDur(sess.duration)}</div>}
          {isStr&&!done&&<div style={{fontFamily:F.ui,fontSize:13,fontWeight:600,color:C.green}}>Start →</div>}
          {!isStr&&!done&&<div style={{fontFamily:F.ui,fontSize:13,fontWeight:600,color:sport.color}}>Log →</div>}
        </div>);
      })}</div>
    </Card>);
  }

  // Fallback to static plan
  const todayPlan=plan.find(d=>d.day===today);
  if (!todayPlan) return null;
  if (!todayPlan.sessions.length) return (<Card style={{marginBottom:16,background:`linear-gradient(135deg,${C.elevated},${C.card})`,borderColor:C.border}}><div style={{display:'flex',alignItems:'center',gap:12}}><div style={{width:44,height:44,borderRadius:14,background:C.elevated,display:'flex',alignItems:'center',justifyContent:'center',}}><Icon name='rest' size={22} color={C.muted}/></div><div><div style={{fontFamily:F.display,fontSize:18,fontWeight:700,color:C.text}}>Rest Day</div><div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,marginTop:2}}>Recovery is training. Let the body adapt.</div></div></div></Card>);
  const allDone=todayPlan.sessions.every(s=>s.type==='strength'?todayS.some(sh=>sh.templateId===s.templateId):todayC.some(w=>w.sport===s.sport));
  return (<Card accent={allDone?C.green:C.accent} style={{marginBottom:16}}><div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:12}}><div><div style={{fontFamily:F.display,fontSize:18,fontWeight:700,color:allDone?C.green:C.accent}}>{allDone?'✓ Today complete':"Today's sessions"}</div><div style={{fontFamily:F.ui,fontSize:13,color:C.subtle,marginTop:1}}>{getDayName()}</div></div>{allDone&&<Pill color={C.green}>Done</Pill>}</div><div style={{display:'flex',flexDirection:'column',gap:8}}>{todayPlan.sessions.map((sess,i)=>{const isStr=sess.type==='strength';const t=isStr?STRENGTH_TEMPLATES.find(t=>t.id===sess.templateId):null;const sport=SPORT_META[sess.sport||'other'];const done=isStr?todayS.some(s=>s.templateId===sess.templateId):todayC.some(w=>w.sport===sess.sport);const accent=done?C.green:(isStr?(t?.color||C.green):sport.color);return (<div key={i} onClick={isStr&&!done?()=>{onStartStrength(sess.templateId);setTab('plan');}:(!done?()=>setTab('log'):undefined)} style={{display:'flex',alignItems:'center',gap:12,padding:'11px 14px',background:done?C.green+'0A':C.elevated,borderRadius:12,border:`1.5px solid ${done?C.green+'44':accent+'30'}`,cursor:!done?'pointer':'default',transition:'all .15s'}}><div style={{width:36,height:36,borderRadius:12,background:accent+'20',display:'flex',alignItems:'center',justifyContent:'center',}}>{done?<Icon name='check' size={17} color={C.green}/>:(isStr?<Icon name='dumbbell' size={17} color={accent}/>:<Icon name={sport.icon} size={17} color={accent}/>)}</div><div style={{flex:1}}><div style={{fontFamily:F.ui,fontWeight:600,fontSize:15,color:done?C.green:C.text}}>{sess.label}</div><div style={{fontFamily:F.ui,fontSize:13,color:C.subtle,marginTop:1,lineHeight:1.4}}>{sess.notes}</div></div>{!isStr&&sess.duration&&<div style={{fontFamily:F.mono,fontSize:12,color:C.muted}}>{fmtDur(sess.duration)}</div>}{isStr&&!done&&<div style={{fontFamily:F.ui,fontSize:13,fontWeight:600,color:t?.color||C.green}}>Start →</div>}{!isStr&&!done&&<div style={{fontFamily:F.ui,fontSize:13,fontWeight:600,color:sport.color}}>Log →</div>}</div>);})}</div></Card>);
}

// ─── Push Message Card ─────────────────────────────────────────────────────────
function PushMessageCard({ message, personality, loading, onRefresh, hasWorkouts }) {
  const p=PERSONALITIES[personality]||PERSONALITIES.normal;
  const defaultMsg = personality==='goggins'
    ? "You haven't logged a single workout yet. The clock is ticking. Your race doesn't care about your excuses — it's coming whether you're ready or not. Add a goal above and get to work."
    : "Welcome to Coach. Add a goal above to generate your training plan, then log your first workout — I'll start tracking your progress and giving you real coaching feedback based on your actual training data.";
  const displayMsg = message || (!hasWorkouts ? defaultMsg : '');
  return(<Card style={{marginBottom:16,borderColor:p.color+'25',position:'relative',overflow:'hidden'}}>
    <div style={{position:'absolute',bottom:-20,right:-20,width:90,height:90,borderRadius:'50%',background:p.color+'10',pointerEvents:'none'}}/>
    <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:12}}>
      <div style={{display:'flex',alignItems:'center',gap:8}}>
        <div style={{width:28,height:28,borderRadius:9,background:p.color+'20',display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name={p.icon} size={14} color={p.color}/></div>
        <div><span style={{fontFamily:F.display,fontWeight:700,fontSize:14,color:p.color}}>Coach's Note</span></div>
      </div>
      {hasWorkouts&&<button onClick={onRefresh} disabled={loading} style={{background:C.elevated,border:'none',borderRadius:8,width:28,height:28,cursor:loading?'not-allowed':'pointer',color:C.muted,fontSize:13,display:'flex',alignItems:'center',justifyContent:'center',transition:'all .15s'}} onMouseEnter={e=>{if(!loading)e.currentTarget.style.color=p.color;}} onMouseLeave={e=>e.currentTarget.style.color=C.muted}><span style={{display:'inline-block',animation:loading?'spin 1s linear infinite':'none'}}>↻</span></button>}
    </div>
    {loading?<div><DotsLoader color={p.color}/><div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:8}}>Reviewing your training…</div></div>
    :<div style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.75}}>{renderMd(displayMsg)}</div>}
  </Card>);
}

// ─── Quick Capture ─────────────────────────────────────────────────────────────
function QuickCaptureSheet({ onClose, onLog, plan }) {
  const[input,setInput]=useState('');const[loading,setLoading]=useState(false);const[parsed,setParsed]=useState(null);const inputRef=useRef(null);
  useEffect(()=>setTimeout(()=>inputRef.current?.focus(),100),[]);
  const today=getDayName();const todayPlan=plan?.find(d=>d.day===today);
  const suggestions=todayPlan?.sessions?.filter(s=>s.type!=='strength')?.map(s=>`${fmtDur(s.duration)} ${s.label.toLowerCase()}`)||[];
  const handleSubmit=async()=>{if(!input.trim()||loading)return;setLoading(true);try{const r=await parseQuickCapture(input,callAI);setParsed(r);}catch{toast.error('Could not parse — try "45 min easy run"');}setLoading(false);};
  const handleConfirm=()=>{if(!parsed)return;onLog(parsed);toast.success(`${SPORT_META[parsed.sport]?.label||parsed.sport} logged — ${fmtDur(parsed.duration)}`);onClose();};
  const handleSuggestion=async text=>{setInput(text);setLoading(true);try{const r=await parseQuickCapture(text,callAI);setParsed(r);}catch{}setLoading(false);};
  return(<Sheet onClose={onClose} title="Quick log"><div style={{fontFamily:F.ui,fontSize:15,color:C.subtle,marginBottom:16,lineHeight:1.6}}>Tell me what you did in plain English.</div>{suggestions.length>0&&!parsed&&<div style={{marginBottom:14}}><Label>Today's plan</Label><div style={{display:'flex',gap:8,flexWrap:'wrap'}}>{suggestions.map((s,i)=><button key={i} onClick={()=>handleSuggestion(s)} style={{background:C.elevated,border:`1.5px solid ${C.border}`,borderRadius:10,padding:'7px 14px',fontFamily:F.ui,fontSize:13,fontWeight:500,color:C.subtle,cursor:'pointer',transition:'all .15s'}} onMouseEnter={e=>{e.currentTarget.style.borderColor=C.accent;e.currentTarget.style.color=C.accent;}} onMouseLeave={e=>{e.currentTarget.style.borderColor=C.border;e.currentTarget.style.color=C.subtle;}}>{s}</button>)}</div></div>}{parsed&&<div className="fade-up" style={{marginBottom:16,padding:'14px 16px',background:C.green+'0A',borderRadius:14,border:`1.5px solid ${C.green}44`}}><div style={{fontFamily:F.ui,fontWeight:600,fontSize:14,color:C.green,marginBottom:8}}>✓ Ready to log</div><div style={{display:'flex',gap:10,flexWrap:'wrap'}}><Pill color={SPORT_META[parsed.sport]?.color||C.accent}>{SPORT_META[parsed.sport]?.label||parsed.sport}</Pill><Pill color={C.cyan}>{fmtDur(parsed.duration)}</Pill>{parsed.notes&&<Pill color={C.subtle}>{parsed.notes}</Pill>}</div></div>}{!parsed&&<div style={{display:'flex',gap:8,marginBottom:16}}><Inp ref={inputRef} placeholder='e.g. Just ran 5 miles easy, 50 minutes' value={input} onChange={e=>setInput(e.target.value)} onKeyDown={e=>e.key==='Enter'&&handleSubmit()} style={{flex:1}}/><button onClick={handleSubmit} disabled={loading||!input.trim()} style={{width:50,height:50,background:loading||!input.trim()?C.elevated:C.accent,border:'none',borderRadius:12,cursor:loading||!input.trim()?'not-allowed':'pointer',color:loading||!input.trim()?C.muted:'#fff',fontSize:18,display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>{loading?<Spinner color="#fff" size={14}/>:'→'}</button></div>}{parsed?<div style={{display:'flex',gap:10}}><Btn onClick={()=>{setParsed(null);setInput('');}} outline style={{flex:1}}>Edit</Btn><Btn onClick={handleConfirm} color={C.green} style={{flex:2}}>Log it ✓</Btn></div>:<div style={{fontFamily:F.ui,fontSize:13,color:C.muted,textAlign:'center'}}>Or use the full <button onClick={onClose} style={{background:'none',border:'none',color:C.accent,fontFamily:F.ui,fontSize:13,cursor:'pointer',textDecoration:'underline',padding:0}}>Log tab</button></div>}</Sheet>);
}

// ─── Strength Tracker ──────────────────────────────────────────────────────────
function RestTimer({seconds,onDone}){const[rem,setRem]=useState(seconds);useEffect(()=>{if(rem<=0){onDone();return;}const t=setTimeout(()=>setRem(r=>r-1),1000);return()=>clearTimeout(t);},[rem]);const pct=(rem/seconds)*100;return(<div style={{background:C.elevated,borderRadius:12,padding:'10px 16px',marginBottom:14,display:'flex',alignItems:'center',gap:14,boxShadow:S.sm}}><div style={{flex:1}}><div style={{display:'flex',justifyContent:'space-between',marginBottom:5}}><span style={{fontFamily:F.ui,fontSize:13,fontWeight:600,color:C.muted}}>Rest</span><span style={{fontFamily:F.display,fontSize:22,fontWeight:700,color:pct>33?C.cyan:C.yellow}}>{rem}s</span></div><div style={{height:4,background:C.border,borderRadius:4,overflow:'hidden'}}><div style={{height:'100%',width:`${pct}%`,background:`linear-gradient(90deg,${C.yellow},${C.cyan})`,borderRadius:4,transition:'width 1s linear'}}/></div></div><button onClick={onDone} style={{background:C.surface,border:`1.5px solid ${C.border}`,borderRadius:10,padding:'6px 13px',color:C.subtle,fontFamily:F.ui,fontSize:12,fontWeight:600,cursor:'pointer',flexShrink:0}}>Skip</button></div>);}

function SetRow({set,setNum,prev,onUpdate,onComplete}){const[ew,setEw]=useState(false);const[er,setEr]=useState(false);const inp={background:'transparent',border:'none',borderBottom:`2px solid ${C.accent}`,outline:'none',fontFamily:F.mono,fontSize:16,color:C.text,width:52,textAlign:'center',padding:'4px 0'};const cell={fontFamily:F.mono,fontSize:16,textAlign:'center',cursor:'pointer',padding:'5px',borderRadius:8,transition:'background .12s',minHeight:44,display:'flex',alignItems:'center',justifyContent:'center'};if(set.completed)return(<div style={{display:'grid',gridTemplateColumns:'28px 1fr 60px 60px 44px',gap:6,alignItems:'center',padding:'9px 4px',background:C.green+'14',borderRadius:10,marginBottom:5}}><span style={{fontFamily:F.mono,fontSize:11,color:C.muted,textAlign:'center'}}>{setNum}</span><span style={{fontFamily:F.mono,fontSize:11,color:C.muted}}>—</span><span style={{fontFamily:F.mono,fontSize:16,color:C.green,textAlign:'center',fontWeight:500}}>{set.weight||'BW'}</span><span style={{fontFamily:F.mono,fontSize:16,color:C.green,textAlign:'center',fontWeight:500}}>{set.reps}</span><span style={{textAlign:'center',color:C.green,fontSize:18}}>✓</span></div>);return(<div style={{display:'grid',gridTemplateColumns:'28px 1fr 60px 60px 44px',gap:6,alignItems:'center',padding:'6px 4px',marginBottom:5}}><span style={{fontFamily:F.mono,fontSize:11,color:C.muted,textAlign:'center'}}>{setNum}</span><span style={{fontFamily:F.mono,fontSize:11,color:C.muted}}>{prev?`${prev.weight||'BW'}×${prev.reps}`:'-'}</span>{ew?<input autoFocus type="number" defaultValue={set.weight} style={inp} onBlur={e=>{onUpdate({weight:parseFloat(e.target.value)||0});setEw(false);}} onKeyDown={e=>e.key==='Enter'&&e.target.blur()}/>:<div onClick={()=>setEw(true)} style={{...cell,color:set.weight?C.text:C.muted}} onMouseEnter={e=>e.currentTarget.style.background=C.elevated} onMouseLeave={e=>e.currentTarget.style.background='transparent'}>{set.weight||'BW'}</div>}{er?<input autoFocus type="number" defaultValue={set.reps} style={inp} onBlur={e=>{onUpdate({reps:parseInt(e.target.value)||0});setEr(false);}} onKeyDown={e=>e.key==='Enter'&&e.target.blur()}/>:<div onClick={()=>setEr(true)} style={cell} onMouseEnter={e=>e.currentTarget.style.background=C.elevated} onMouseLeave={e=>e.currentTarget.style.background='transparent'}>{set.reps}</div>}<button onClick={onComplete} style={{width:44,height:44,borderRadius:12,background:C.elevated,border:`1.5px solid ${C.border}`,color:C.muted,fontSize:18,cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center',transition:'all .14s'}} onMouseEnter={e=>{e.currentTarget.style.background=C.green+'18';e.currentTarget.style.borderColor=C.green;e.currentTarget.style.color=C.green;}} onMouseLeave={e=>{e.currentTarget.style.background=C.elevated;e.currentTarget.style.borderColor=C.border;e.currentTarget.style.color=C.muted;}}>✓</button></div>);}

function StrengthTracker({template,strengthHistory,prs,onSave,onDiscard}){
  const[session]=useState(()=>({id:Date.now(),templateId:template.id,name:template.name,startTime:Date.now(),exercises:template.exercises.map(te=>({exerciseId:te.id,name:EX[te.id]?.name||te.id,sets:Array.from({length:te.sets},(_,i)=>({setNum:i+1,weight:te.weight,reps:te.reps,completed:false}))}))}));
  const[ex,setEx]=useState(session.exercises);const[restTimer,setRest]=useState(null);const[view,setView]=useState('active');
  const total=ex.reduce((s,e)=>s+e.sets.length,0);const done=ex.reduce((s,e)=>s+e.sets.filter(x=>x.completed).length,0);
  const getLastPerf=exId=>{for(const s of [...strengthHistory].reverse()){const e=s.exercises?.find(e=>e.exerciseId===exId);if(e?.sets?.length)return e.sets.filter(s=>s.completed);}return[];};
  const updateSet=(exId,idx,upd)=>setEx(prev=>prev.map(e=>e.exerciseId!==exId?e:{...e,sets:e.sets.map((s,i)=>i!==idx?s:{...s,...upd})}));
  const completeSet=(exId,idx)=>{setEx(prev=>prev.map(e=>e.exerciseId!==exId?e:{...e,sets:e.sets.map((s,i)=>i!==idx?s:{...s,completed:true})}));const e=EX[exId];if(e?.rest)setRest({exId,seconds:e.rest,key:`${exId}-${idx}`});};
  const handleDiscard=async()=>{const ok=await confirmDialog('Discard workout?','All progress will be lost.');if(ok)onDiscard();};
  if(view==='summary'){const dur=Math.round((Date.now()-session.startTime)/60000);const completed=ex.map(e=>({...e,sets:e.sets.filter(s=>s.completed)})).filter(e=>e.sets.length>0);const totalVol=completed.reduce((s,e)=>s+e.sets.reduce((ss,set)=>ss+(set.weight*set.reps),0),0);const newPRs=[];for(const e of completed){const bestE=Math.max(...e.sets.map(s=>epley(s.weight,s.reps)));if(bestE>0&&bestE>(prs[e.exerciseId]?.estimated1RM||0)){const best=e.sets.reduce((b,s)=>epley(s.weight,s.reps)>epley(b.weight,b.reps)?s:b);newPRs.push({exerciseId:e.exerciseId,name:e.name,weight:best.weight,reps:best.reps,estimated1RM:bestE});}}return(<div className="fade-up" style={{paddingBottom:40}}><div style={{textAlign:'center',padding:'24px 0 20px'}}><div style={{marginBottom:8}}><Icon name='star' size={48} color={C.green}/></div><div style={{fontFamily:F.display,fontSize:32,fontWeight:800,color:C.text}}>Workout done!</div><div style={{fontFamily:F.ui,fontSize:15,color:C.subtle,marginTop:4}}>{template.name}</div></div><div style={{display:'grid',gridTemplateColumns:'repeat(3,1fr)',gap:10,marginBottom:16}}>{[{l:'Time',v:fmtDur(dur),c:C.cyan},{l:'Sets',v:completed.reduce((s,e)=>s+e.sets.length,0),c:C.text},{l:'Volume',v:totalVol>0?`${(totalVol/1000).toFixed(1)}k`:'—',c:C.text}].map(({l,v,c})=><Card key={l} style={{textAlign:'center',padding:'14px 8px'}}><div style={{fontFamily:F.display,fontSize:28,fontWeight:700,color:c,lineHeight:1}}>{v}</div><div style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginTop:5,fontWeight:500}}>{l}</div></Card>)}</div>{newPRs.length>0&&<Card accent={C.yellow} style={{marginBottom:14}}><Label style={{color:C.yellow,marginBottom:10}}>New Personal Records</Label>{newPRs.map((pr,i)=><div key={i} style={{display:'flex',justifyContent:'space-between',padding:'7px 0',borderTop:i>0?`1px solid ${C.border}`:'none'}}><span style={{fontFamily:F.ui,fontSize:15,fontWeight:500,color:C.text}}>{pr.name}</span><span style={{fontFamily:F.mono,fontSize:14,color:C.yellow}}>{pr.weight>0?`${pr.weight} lb × ${pr.reps}`:`${pr.reps} reps`}</span></div>)}</Card>}<Label>Breakdown</Label>{completed.map((e,i)=><Card key={i} style={{marginBottom:8,padding:'13px 16px'}}><div style={{fontFamily:F.ui,fontWeight:600,fontSize:15,marginBottom:8,color:C.text}}>{e.name}</div><div style={{display:'flex',gap:7,flexWrap:'wrap'}}>{e.sets.map((s,j)=><span key={j} style={{fontFamily:F.mono,fontSize:12,color:C.subtle,background:C.elevated,borderRadius:8,padding:'4px 10px'}}>{s.weight>0?`${s.weight}×${s.reps}`:`BW×${s.reps}`}</span>)}</div></Card>)}<div style={{display:'flex',gap:10,marginTop:16}}><Btn onClick={handleDiscard} outline style={{flex:1}}>Discard</Btn><Btn onClick={()=>onSave(completed,dur,newPRs)} color={C.green} style={{flex:2}}>Save workout</Btn></div></div>);}
  return(<div className="fade-up" style={{paddingBottom:88}}><div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:14}}><div><div style={{fontFamily:F.display,fontSize:22,fontWeight:800,color:C.text}}>{template.name}</div><div style={{fontFamily:F.ui,fontSize:14,color:C.muted,marginTop:2}}>{done} of {total} sets</div></div><button onClick={handleDiscard} style={{background:C.elevated,border:'none',borderRadius:10,padding:'7px 14px',color:C.subtle,fontFamily:F.ui,fontSize:13,fontWeight:500,cursor:'pointer'}}>Discard</button></div><div style={{height:5,background:C.border,borderRadius:4,overflow:'hidden',marginBottom:16}}><div style={{height:'100%',width:`${total>0?(done/total)*100:0}%`,background:`linear-gradient(90deg,${C.accent},${C.green})`,borderRadius:4,transition:'width .3s'}}/></div>{restTimer&&<RestTimer key={restTimer.key} seconds={restTimer.seconds} onDone={()=>setRest(null)}/>}{ex.map(exData=>{const e=EX[exData.exerciseId]||{};const lastPerf=getLastPerf(exData.exerciseId);const allDone=exData.sets.every(s=>s.completed);const catColors={lower:C.accent,upper:C.cyan,core:C.purple};return(<Card key={exData.exerciseId} style={{marginBottom:12}}><div style={{display:'flex',justifyContent:'space-between',alignItems:'flex-start',marginBottom:10}}><div><div style={{fontFamily:F.ui,fontWeight:700,fontSize:16,color:allDone?C.green:C.text}}>{e.name}</div>{e.hint&&<div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:2}}>{e.hint}</div>}</div><div style={{display:'flex',alignItems:'center',gap:8}}><span style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:catColors[e.cat]||C.muted,background:(catColors[e.cat]||C.muted)+'15',borderRadius:8,padding:'2px 9px'}}>{e.cat}</span><span style={{fontFamily:F.mono,fontSize:12,color:allDone?C.green:C.muted}}>{exData.sets.filter(s=>s.completed).length}/{exData.sets.length}</span></div></div><div style={{display:'grid',gridTemplateColumns:'28px 1fr 60px 60px 44px',gap:6,marginBottom:6,padding:'0 4px'}}>{['#','Prev','Lbs','Reps',''].map((h,i)=><span key={i} style={{fontFamily:F.ui,fontSize:11,fontWeight:600,color:C.muted,textAlign:i>=2?'center':'left'}}>{h}</span>)}</div>{exData.sets.map((set,i)=><SetRow key={i} set={set} setNum={i+1} prev={lastPerf[i]} onUpdate={u=>updateSet(exData.exerciseId,i,u)} onComplete={()=>completeSet(exData.exerciseId,i)}/>)}</Card>);})} <div style={{position:'fixed',bottom:24,left:'50%',transform:'translateX(-50%)',width:'calc(100% - 32px)',maxWidth:468,zIndex:20}}><Btn onClick={()=>done>0&&setView('summary')} color={done===total?C.green:C.accent} disabled={done===0} style={{width:'100%',padding:15,fontSize:17,borderRadius:16,boxShadow:S.md}}>{done===total?'Finish workout ✓':`Finish (${done}/${total} sets)`}</Btn></div></div>);
}

// ─── Plan Builder Sheet ───────────────────────────────────────────────────────
function PlanBuilderSheet({goal,mode,appState,onPlanCreated,onWeekGenerated,onClose}){
  const[msgs,setMsgs]=useState([]);
  const[input,setInput]=useState('');
  const[loading,setLoading]=useState(false);
  const[stage,setStage]=useState('starting'); // starting|reviewing|designing|generating|done|error
  const[isStreaming,setIsStreaming]=useState(false);
  const[streamText,setStreamText]=useState('');
  const bottomRef=useRef(null);
  const inputRef=useRef(null);
  const chainRef=useRef([]);

  const stageLabels={starting:'Starting...',reviewing:'Reviewing your training',designing:'Designing your plan',generating:'Generating week 1',done:'Plan created!',error:'Something went wrong'};
  const stageOrder=['reviewing','designing','generating','done'];
  const stageIdx=stageOrder.indexOf(stage);

  useEffect(()=>{bottomRef.current?.scrollIntoView({behavior:'smooth'});},[msgs,streamText]);

  const detectStage=(toolNames)=>{
    if(toolNames.some(n=>n==='save_weekly_plan'))setStage('generating');
    else if(toolNames.some(n=>n==='save_training_plan'))setStage('designing');
    else if(toolNames.some(n=>['get_workouts','get_athlete_profile','get_goals','get_training_stats'].includes(n)))setStage('reviewing');
  };

  const runTurn=useCallback(async(userMsgs)=>{
    setLoading(true);
    const systemPrompt=buildPlanBuilderPrompt(goal,mode);
    const clean=userMsgs.map(m=>({role:m.role,content:typeof m.content==='string'?m.content:String(m.content||'')}));
    let chain=[...clean];
    try{
      for(let round=0;round<10;round++){
        const resp=await callAI({system:systemPrompt,messages:chain,tools:TOOLS,tool_choice:{type:'auto'},max_tokens:2048});
        const textContent=resp.content?.filter(b=>b.type==='text')?.map(b=>b.text)?.join('')?.trim()||'';
        if(resp.stop_reason==='end_turn'){
          chainRef.current=chain;
          setLoading(false);
          setIsStreaming(true);setStreamText('');
          await typewriter(textContent,chunk=>setStreamText(chunk));
          const aMsg={role:'assistant',content:textContent};
          setMsgs(prev=>[...prev,aMsg]);
          chainRef.current=[...chain,{role:'assistant',content:textContent}];
          setIsStreaming(false);setStreamText('');
          return;
        }
        if(resp.stop_reason==='tool_use'){
          const toolUses=resp.content?.filter(b=>b.type==='tool_use')||[];
          if(!toolUses.length){chainRef.current=chain;setLoading(false);return;}
          detectStage(toolUses.map(t=>t.name));
          const toolResults=toolUses.map(tu=>{
            let inp;try{inp=typeof tu.input==='string'?JSON.parse(tu.input):tu.input;}catch{inp={};}
            const result=executeTool(tu.name,inp,appState);
            if(tu.name==='save_training_plan'){try{const p=JSON.parse(result);if(p.saved&&p.plan){onPlanCreated(p.plan);if(mode==='create')setStage('designing');}}catch{}}
            if(tu.name==='save_weekly_plan'){try{const p=JSON.parse(result);if(p.saved&&p.weekPlan){onWeekGenerated(p.weekPlan);setStage('done');}}catch{}}
            return{type:'tool_result',tool_use_id:tu.id,content:result};
          });
          chain=[...chain,{role:'assistant',content:resp.content},{role:'user',content:toolResults}];
          if(textContent){
            setIsStreaming(true);setStreamText('');
            await typewriter(textContent,chunk=>setStreamText(chunk));
            setMsgs(prev=>[...prev,{role:'assistant',content:textContent}]);
            setIsStreaming(false);setStreamText('');
          }
          continue;
        }
        break;
      }
      chainRef.current=chain;setLoading(false);
    }catch(err){
      setStage('error');setLoading(false);setIsStreaming(false);
      setMsgs(prev=>[...prev,{role:'assistant',content:`Something went wrong: ${err.message}. Tap "Try again" to retry.`}]);
    }
  },[goal,mode,appState,onPlanCreated,onWeekGenerated]);

  // Auto-start on mount
  useEffect(()=>{
    const initMsg={role:'user',content:mode==='week'?`Generate my training plan for week ${goal._weekNum||'current'} (Phase ${goal._phaseNum||'current'}).`:`Build me a training plan for ${goal.name}.`};
    setMsgs([initMsg]);
    runTurn([initMsg]);
  },[]);

  const sendReply=()=>{
    const t=input.trim();if(!t||loading||isStreaming)return;
    const userMsg={role:'user',content:t};
    const updated=[...msgs,userMsg];
    setMsgs(updated);setInput('');
    const fullChain=[...chainRef.current,{role:'user',content:t}];
    runTurn(fullChain);
  };

  const retry=()=>{setStage('starting');runTurn(chainRef.current.length?chainRef.current:[msgs[0]]);};

  const isDone=stage==='done';
  const isConversational=!loading&&!isStreaming&&msgs.length>1&&!isDone&&stage!=='error';

  return(<Sheet onClose={onClose} title={mode==='week'?'Generating week':'Building your plan'}>
    {/* Progress stepper */}
    <div style={{display:'flex',gap:4,marginBottom:16}}>
      {stageOrder.map((s,i)=><div key={s} style={{flex:1,height:4,borderRadius:2,background:i<=stageIdx?(i===stageIdx?C.accent:C.green):C.border,transition:'background .3s'}}/>)}
    </div>
    <div style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:stage==='error'?C.red:stage==='done'?C.green:C.accent,marginBottom:4}}>{stageLabels[stage]}</div>
    {stage!=='done'&&stage!=='error'&&<div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginBottom:16}}>This usually takes 30–60 seconds</div>}

    {/* Chat area */}
    <div style={{maxHeight:'50vh',overflowY:'auto',display:'flex',flexDirection:'column',gap:10,marginBottom:16}}>
      {msgs.filter(m=>m.role==='assistant').map((m,i)=>(
        <div key={i} className="fade-up" style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.75}}>{renderMd(m.content)}</div>
      ))}
      {isStreaming&&streamText&&<div className="fade-up" style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.75}}>{renderMd(streamText)}</div>}
      {loading&&!isStreaming&&<div style={{display:'flex',alignItems:'center',gap:8,padding:'8px 0'}}><DotsLoader color={C.accent}/><span style={{fontFamily:F.ui,fontSize:12,color:C.muted}}>{stageLabels[stage]}</span></div>}
      <div ref={bottomRef}/>
    </div>

    {/* Input area — only show when AI is waiting for a response */}
    {isConversational&&<div style={{display:'flex',gap:8,marginBottom:12}}>
      <Inp ref={inputRef} value={input} onChange={e=>setInput(e.target.value)} onKeyDown={e=>e.key==='Enter'&&sendReply()} placeholder="Answer your coach..." style={{flex:1}}/>
      <button onClick={sendReply} disabled={!input.trim()} style={{width:48,height:48,background:!input.trim()?C.elevated:C.accent,border:'none',borderRadius:12,cursor:!input.trim()?'not-allowed':'pointer',color:!input.trim()?C.muted:'#fff',fontSize:18,display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>↑</button>
    </div>}

    {stage==='error'&&<Btn onClick={retry} color={C.accent} style={{width:'100%',padding:13,fontSize:15,marginBottom:8}}>Try again</Btn>}
    {isDone&&<Btn onClick={onClose} color={C.green} style={{width:'100%',padding:13,fontSize:15}}>View your plan</Btn>}
  </Sheet>);
}

// ─── Plan Tab ──────────────────────────────────────────────────────────────────
function TrainingPlanTab({events,cardio,strengthHistory,prs,onSaveStrength,activeWO,setActiveWO,trainingPlan,onPlanCreated,onWeekGenerated,onAddEvent,onDisruption,appState}){
  const[tracker,setTracker]=useState(activeWO?STRENGTH_TEMPLATES.find(t=>t.id===activeWO?.templateId)||null:null);
  const[createStep,setCreateStep]=useState(null); // null | 'select' | 'confirm'
  const[selectedGoal,setSelectedGoal]=useState(null);
  const[planBuilder,setPlanBuilder]=useState(null); // {goal, mode:'create'|'week'}
  const active=events.filter(e=>!e.completed);const plan=generateWeeklyPlan(events);const today=getDayName();
  const startStrength=tid=>{const t=STRENGTH_TEMPLATES.find(t=>t.id===tid);if(t)setTracker(t);};
  const handleSave=(completedEx,dur,newPRs)=>{onSaveStrength(completedEx,dur,newPRs,tracker);setTracker(null);setActiveWO(null);};
  const handleDiscard=()=>{setTracker(null);setActiveWO(null);};

  const handleSelectGoal=(e)=>{setSelectedGoal(e);setCreateStep('confirm');};

  if(tracker)return (<div style={{paddingBottom:48}}><button onClick={()=>setTracker(null)} style={{background:'none',border:'none',color:C.muted,fontFamily:F.ui,fontSize:13,fontWeight:500,cursor:'pointer',marginBottom:16,padding:0,display:'flex',alignItems:'center',gap:4}}><Icon name='arrowLeft' size={14} color={C.muted}/> Back to plan</button><StrengthTracker template={tracker} strengthHistory={strengthHistory} prs={prs} onSave={handleSave} onDiscard={handleDiscard}/></div>);

  if(!active.length)return (<div style={{paddingBottom:48}}><Card style={{textAlign:'center',padding:36}}><div style={{marginBottom:12}}><Icon name='calendar' size={36} color={C.muted}/></div><div style={{fontFamily:F.display,fontSize:20,fontWeight:700,color:C.text,marginBottom:8}}>No active goals</div><div style={{fontFamily:F.ui,fontSize:15,color:C.subtle,lineHeight:1.7}}>Add a goal from the Goals tab first, then come back to create your training plan.</div></Card></div>);

  // Create plan sheet
  const CreatePlanSheet=()=>{
    if(!createStep) return null;
    if(createStep==='select') return (
      <Sheet onClose={()=>{setCreateStep(null);setSelectedGoal(null);}} title="Choose a goal">
        <div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,marginBottom:16,lineHeight:1.6}}>Which race or goal do you want a training plan for?</div>
        {active.map(e=>{const p=presetById(e.presetId);const days=e.date?daysUntil(e.date):null;return (
          <Card key={e.id} onClick={()=>handleSelectGoal(e)} accent={p.color} style={{marginBottom:10,padding:'16px 18px'}}>
            <div style={{display:'flex',alignItems:'center',gap:12}}>
              <div style={{width:44,height:44,borderRadius:14,background:p.color+'20',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}><Icon name={p.icon} size={22} color={p.color}/></div>
              <div style={{flex:1}}>
                <div style={{fontFamily:F.ui,fontWeight:700,fontSize:15,color:C.text}}>{e.name}</div>
                <div style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginTop:2}}>{e.location||p.label}{e.date?` · ${fmtDateSh(e.date)}`:''}</div>
                {e.goal&&<div style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:p.color,marginTop:3}}>Goal: {e.goal}</div>}
              </div>
              {days!==null&&days>0&&<div style={{textAlign:'right',flexShrink:0}}>
                <div style={{fontFamily:F.display,fontSize:22,fontWeight:700,color:C.text,lineHeight:1}}>{days}</div>
                <div style={{fontFamily:F.ui,fontSize:10,color:C.muted}}>days</div>
              </div>}
            </div>
          </Card>
        );})}
        <Card onClick={()=>{setCreateStep(null);onAddEvent();}} style={{marginTop:4,padding:'16px 18px',textAlign:'center',border:`2px dashed ${C.border}`}}>
          <div style={{display:'flex',alignItems:'center',justifyContent:'center',gap:8}}>
            <Icon name='plus' size={18} color={C.muted}/>
            <span style={{fontFamily:F.ui,fontWeight:600,fontSize:14,color:C.muted}}>Create a new goal</span>
          </div>
        </Card>
      </Sheet>
    );
    if(createStep==='confirm'&&selectedGoal) {
      const p=presetById(selectedGoal.presetId);
      const days=selectedGoal.date?daysUntil(selectedGoal.date):null;
      const weeks=days!==null?Math.ceil(days/7):null;
      return (
        <Sheet onClose={()=>{setCreateStep(null);setSelectedGoal(null);}} title="Build your plan">
          <Card accent={p.color} style={{marginBottom:20,padding:'20px 18px'}}>
            <div style={{display:'flex',alignItems:'center',gap:10,marginBottom:14}}>
              <div style={{width:44,height:44,borderRadius:14,background:p.color+'20',display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name={p.icon} size={22} color={p.color}/></div>
              <div>
                <div style={{fontFamily:F.display,fontSize:20,fontWeight:800,color:C.text}}>{selectedGoal.name}</div>
                {selectedGoal.location&&<div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:1}}>{selectedGoal.location}</div>}
              </div>
            </div>
            <div style={{display:'flex',gap:10,flexWrap:'wrap'}}>
              {selectedGoal.date&&<Pill color={p.color}>{fmtDateSh(selectedGoal.date)}</Pill>}
              {weeks&&<Pill color={C.cyan}>{weeks} weeks</Pill>}
              {selectedGoal.goal&&<Pill color={C.green}>Goal: {selectedGoal.goal}</Pill>}
              {selectedGoal.baseline&&<Pill color={C.muted}>PR: {selectedGoal.baseline}</Pill>}
            </div>
          </Card>
          <div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,lineHeight:1.7,marginBottom:8}}>Your coach will:</div>
          <div style={{marginBottom:20}}>
            {['Review your training history and fitness level','Design periodized phases with progressive intensity','Set per-session nutrition guidance','Build in deload weeks and recovery','Generate your first weekly plan'].map((item,i)=>(
              <div key={i} style={{display:'flex',gap:10,padding:'7px 0'}}>
                <div style={{width:20,height:20,borderRadius:6,background:C.accent+'18',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,marginTop:1}}><Icon name='check' size={12} color={C.accent}/></div>
                <span style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.5}}>{item}</span>
              </div>
            ))}
          </div>
          <div style={{display:'flex',gap:10}}>
            <Btn onClick={()=>setCreateStep('select')} outline style={{flex:1}}>Back</Btn>
            <Btn onClick={()=>{setCreateStep(null);setPlanBuilder({goal:selectedGoal,mode:'create'});setSelectedGoal(null);}} color={C.accent} style={{flex:2,fontSize:16}}>Let's go →</Btn>
          </div>
        </Sheet>
      );
    }
    return null;
  };

  // No periodized plan yet — show create CTA
  if(!trainingPlan) return (<div style={{paddingBottom:48}}>
    <Card accent={C.accent} style={{textAlign:'center',padding:32,marginBottom:20}}>
      <div style={{marginBottom:12}}><Icon name='calendar' size={36} color={C.accent}/></div>
      <div style={{fontFamily:F.display,fontSize:22,fontWeight:800,color:C.text,marginBottom:8}}>Create Your Training Plan</div>
      <div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,lineHeight:1.7,marginBottom:20}}>Your AI coach will design a personalized, periodized training plan based on your goal, fitness level, and available time.</div>
      <Btn onClick={()=>setCreateStep('select')} color={C.accent} style={{width:'100%',padding:15,fontSize:16}}>Build my plan</Btn>
    </Card>
    <CreatePlanSheet/>
    {planBuilder&&<PlanBuilderSheet goal={planBuilder.goal} mode={planBuilder.mode} appState={appState} onPlanCreated={onPlanCreated} onWeekGenerated={onWeekGenerated} onClose={()=>setPlanBuilder(null)}/>}
  </div>);

  // Has periodized plan — full plan UI
  const tp=trainingPlan;
  const currentPhase=tp.phases?.find(p=>p.number===tp.currentPhase)||tp.phases?.[0];
  const weekPlan=tp.weeklyPlans?.[String(tp.currentWeek)]||null;
  const weekAdherence=weekPlan?computeWeekAdherence(tp,tp.currentWeek,cardio,strengthHistory):null;
  const multiWeekPatterns=tp.currentWeek>1?computeMultiWeekPatterns(tp,tp.currentWeek,cardio,strengthHistory):[];
  const weeksToRace=tp.raceDate?Math.max(0,Math.ceil((new Date(tp.raceDate+'T12:00:00')-new Date())/604800000)):null;
  const[expandedPhase,setExpandedPhase]=useState(null);
  const[showFuel,setShowFuel]=useState(null);
  const phaseColors=['#E8604C','#2BAFC4','#F0A830','#8B6FE8','#2ABF84','#4890D8'];

  return (<div style={{paddingBottom:48}}>
    {/* Season header */}
    <div style={{marginBottom:20}}>
      <div style={{display:'flex',justifyContent:'space-between',alignItems:'flex-start',marginBottom:12}}>
        <div>
          <div style={{fontFamily:F.display,fontSize:22,fontWeight:800,color:C.text,letterSpacing:'-.01em'}}>{tp.raceName}</div>
          <div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:2}}>Week {tp.currentWeek} of {tp.totalWeeks}{weeksToRace!==null?` · ${weeksToRace} weeks to race`:''}</div>
        </div>
      </div>

      {/* Phase timeline */}
      <div style={{display:'flex',gap:3,height:8,borderRadius:4,overflow:'hidden',marginBottom:10}}>
        {tp.phases?.map((ph,i)=>{const isCurrent=ph.number===tp.currentPhase;const isPast=ph.number<tp.currentPhase;return (
          <div key={ph.number} style={{flex:ph.weeks,background:isCurrent?phaseColors[i%phaseColors.length]:(isPast?phaseColors[i%phaseColors.length]+'60':C.border),borderRadius:2,transition:'all .3s',position:'relative'}}>
            {isCurrent&&<div style={{position:'absolute',inset:0,background:`linear-gradient(90deg,${phaseColors[i%phaseColors.length]},${phaseColors[i%phaseColors.length]}CC)`,borderRadius:2}}/>}
          </div>
        );})}
      </div>

      {/* Current phase info */}
      {currentPhase&&<Card style={{padding:'12px 16px',borderColor:phaseColors[(tp.currentPhase-1)%phaseColors.length]+'30'}}>
        <div style={{display:'flex',alignItems:'center',gap:10}}>
          <div style={{width:8,height:8,borderRadius:'50%',background:phaseColors[(tp.currentPhase-1)%phaseColors.length],flexShrink:0}}/>
          <div style={{flex:1}}>
            <div style={{fontFamily:F.ui,fontWeight:700,fontSize:14,color:phaseColors[(tp.currentPhase-1)%phaseColors.length]}}>Phase {currentPhase.number}: {currentPhase.name}</div>
            <div style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginTop:2}}>{currentPhase.focus}</div>
          </div>
          <div style={{textAlign:'right',flexShrink:0}}>
            <div style={{fontFamily:F.mono,fontSize:11,color:C.muted}}>{currentPhase.weeklyVolume}</div>
            <div style={{fontFamily:F.mono,fontSize:11,color:C.muted}}>{currentPhase.intensityCeiling}</div>
          </div>
        </div>
      </Card>}
    </div>

    {activeWO&&<Card accent={C.yellow} onClick={()=>setTracker(STRENGTH_TEMPLATES.find(t=>t.id===activeWO.templateId))} style={{marginBottom:16}}><div style={{display:'flex',alignItems:'center',gap:10}}><Icon name='timer' size={20} color={C.yellow}/><div><div style={{fontFamily:F.ui,fontWeight:600,fontSize:15,color:C.yellow}}>Workout in progress</div><div style={{fontFamily:F.ui,fontSize:13,color:C.subtle,marginTop:1}}>{activeWO.name} · tap to continue</div></div><span style={{marginLeft:'auto',color:C.yellow}}>→</span></div></Card>}

    {/* Current week sessions */}
    <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:weekAdherence?6:10}}>
      <Label style={{marginBottom:0}}>Week {tp.currentWeek}{weekPlan?` · ${weekPlan.focusOfWeek}`:''}</Label>
    </div>
    {weekAdherence&&weekAdherence.prescribed>0&&<div style={{marginBottom:12}}>
      <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',marginBottom:6}}>
        <span style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:weekAdherence.adherence>=85?C.green:weekAdherence.adherence>=60?C.yellow:C.red}}>{weekAdherence.completed+weekAdherence.shortened}/{weekAdherence.prescribed} sessions · {weekAdherence.adherence}%</span>
        {weekAdherence.missed>0&&<span style={{fontFamily:F.ui,fontSize:11,color:C.muted}}>{weekAdherence.missed} missed</span>}
      </div>
      <div style={{height:6,background:C.border,borderRadius:3,overflow:'hidden'}}>
        <div style={{height:'100%',width:`${weekAdherence.adherence}%`,background:weekAdherence.adherence>=85?C.green:weekAdherence.adherence>=60?C.yellow:C.red,borderRadius:3,transition:'width .3s'}}/>
      </div>
      {multiWeekPatterns.length>0&&<div style={{marginTop:6}}>{multiWeekPatterns.map((p,i)=><div key={i} style={{fontFamily:F.ui,fontSize:11,color:C.yellow,display:'flex',alignItems:'center',gap:4,marginTop:2}}><Icon name='alert' size={11} color={C.yellow}/>{p}</div>)}</div>}
    </div>}

    {!weekPlan?<Card accent={C.accent} onClick={()=>setPlanBuilder({goal:{...events.find(e=>e.id===tp.goalId)||{name:tp.raceName},_weekNum:tp.currentWeek,_phaseNum:tp.currentPhase},mode:'week'})} style={{textAlign:'center',padding:28,marginBottom:16}}>
      <div style={{marginBottom:8}}><Icon name='calendar' size={28} color={C.accent}/></div>
      <div style={{fontFamily:F.display,fontSize:18,fontWeight:700,color:C.accent,marginBottom:4}}>Generate this week</div>
      <div style={{fontFamily:F.ui,fontSize:13,color:C.subtle}}>Your coach will create sessions based on your current phase and recent training.</div>
    </Card>
    :weekPlan.sessions?.map((dayObj,di)=>{
      const isToday=dayObj.day===today;
      const daySessions=dayObj.sessions||[];
      const dayIndex=['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'].indexOf(dayObj.day);
      const weekStart=new Date();weekStart.setDate(weekStart.getDate()-((weekStart.getDay()+6)%7));weekStart.setHours(0,0,0,0);
      const dayDate=new Date(weekStart);dayDate.setDate(dayDate.getDate()+dayIndex);
      const dayDateStr=dayDate.toISOString().split('T')[0];
      const isPastDay=dayDateStr<todayStr();
      const dayCardio=cardio.filter(w=>w.date===dayDateStr);
      const dayStrength=strengthHistory.filter(s=>s.date===dayDateStr);
      const adhDay=weekAdherence?.days?.find(d=>d.day===dayObj.day);
      const dayCompleted=adhDay?.sessions?.filter(s=>s.status==='completed'||s.status==='shortened').length||0;
      const dayMissed=adhDay?.sessions?.filter(s=>s.status==='missed').length||0;
      const dayTotal=adhDay?.sessions?.length||daySessions.length;
      return (<div key={di} style={{marginBottom:10,opacity:isPastDay&&dayTotal>0&&dayCompleted===0&&dayMissed===dayTotal?0.6:1}}>
        <div style={{display:'flex',alignItems:'center',gap:8,marginBottom:6}}>
          <span style={{fontFamily:F.display,fontSize:16,fontWeight:700,color:isToday?C.accent:C.subtle}}>{dayObj.day}</span>
          {isToday&&<Pill color={C.accent} small>Today</Pill>}
          {dayObj.isRest&&<span style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginLeft:'auto'}}>Rest</span>}
          {!dayObj.isRest&&dayTotal>0&&dayCompleted>0&&<span style={{fontFamily:F.ui,fontSize:11,fontWeight:600,color:dayCompleted>=dayTotal?C.green:C.muted,marginLeft:'auto'}}>{dayCompleted}/{dayTotal} done</span>}
          {!dayObj.isRest&&isPastDay&&dayMissed>0&&dayCompleted===0&&<span style={{fontFamily:F.ui,fontSize:11,fontWeight:600,color:C.red,marginLeft:'auto'}}>Missed</span>}
        </div>
        {daySessions.length>0&&<Card style={{padding:'4px 6px',borderColor:isToday?C.accent+'30':C.border}}>
          {daySessions.map((sess,si)=>{
            if(sess.type==='brick'&&sess.legs){
              const brickDone=(sess.legs||[]).every(l=>dayCardio.some(w=>w.sport===l.sport));
              const fuelKey=`${di}-${si}`;
              return (<div key={si} style={{borderRadius:12,border:`1.5px solid ${brickDone?C.green+'44':C.yellow+'40'}`,overflow:'hidden',background:brickDone?C.green+'08':'transparent',marginBottom:si<daySessions.length-1?4:0}}>
                <div style={{padding:'8px 12px',background:C.yellow+'10',display:'flex',alignItems:'center',gap:8}}>
                  <Icon name='layers' size={14} color={C.yellow}/><span style={{fontFamily:F.ui,fontWeight:700,fontSize:12,color:C.yellow}}>Brick</span>
                  {sess.priority&&<div style={{width:6,height:6,borderRadius:'50%',background:sess.priority==='red'?C.accent:C.yellow}}/>}
                  <span style={{fontFamily:F.ui,fontSize:13,fontWeight:600,color:brickDone?C.green:C.text,flex:1}}>{sess.label}</span>
                  {brickDone&&<Pill color={C.green} small>Done</Pill>}
                </div>
                {sess.legs.map((leg,li)=>{const lSport=SPORT_META[leg.sport]||SPORT_META.other;const lDone=dayCardio.some(w=>w.sport===leg.sport);return(
                  <div key={li} style={{display:'flex',alignItems:'center',gap:12,padding:'10px 12px',borderTop:`1px solid ${C.border}`}}>
                    <div style={{width:32,height:32,borderRadius:10,background:lDone?C.green+'20':lSport.color+'20',display:'flex',alignItems:'center',justifyContent:'center'}}>{lDone?<Icon name='check' size={15} color={C.green}/>:<Icon name={lSport.icon} size={15} color={lSport.color}/>}</div>
                    <div style={{flex:1}}><span style={{fontFamily:F.ui,fontWeight:500,fontSize:14,color:lDone?C.green:C.text}}>{lSport.label}</span>{leg.zone&&!lDone&&<span style={{fontFamily:F.mono,fontSize:11,color:lSport.color,marginLeft:6}}>{leg.zone}</span>}{leg.notes&&!lDone&&<div style={{fontFamily:F.ui,fontSize:12,color:C.subtle,marginTop:2}}>{leg.notes}</div>}</div>
                    {leg.duration&&<span style={{fontFamily:F.mono,fontSize:12,color:C.muted}}>{fmtDur(leg.duration)}</span>}
                  </div>);})}
                {sess.fuel&&!brickDone&&<div style={{padding:'6px 12px',borderTop:`1px solid ${C.border}`}}>
                  <button onClick={()=>setShowFuel(showFuel===fuelKey?null:fuelKey)} style={{background:'none',border:'none',cursor:'pointer',fontFamily:F.ui,fontSize:11,fontWeight:600,color:C.muted,display:'flex',alignItems:'center',gap:4,padding:0}}>
                    <Icon name='zap' size={10} color={C.muted}/> Fuel {showFuel===fuelKey?'▲':'▼'}
                  </button>
                  {showFuel===fuelKey&&<div className="fade-up" style={{marginTop:4,padding:'6px 0'}}>
                    {sess.fuel.pre&&<div style={{fontFamily:F.ui,fontSize:12,color:C.subtle,marginBottom:3}}><span style={{fontWeight:600,color:C.green}}>Pre:</span> {sess.fuel.pre}</div>}
                    {sess.fuel.during&&<div style={{fontFamily:F.ui,fontSize:12,color:C.subtle,marginBottom:3}}><span style={{fontWeight:600,color:C.cyan}}>During:</span> {sess.fuel.during}</div>}
                    {sess.fuel.post&&<div style={{fontFamily:F.ui,fontSize:12,color:C.subtle}}><span style={{fontWeight:600,color:C.purple}}>Post:</span> {sess.fuel.post}</div>}
                  </div>}
                </div>}
              </div>);
            }
            const sport=SPORT_META[sess.type]||SPORT_META.other;
            const isStr=sess.type==='strength';
            const done=isStr?dayStrength.some(sh=>sh.templateId===sess.templateId):dayCardio.some(w=>w.sport===sess.type);
            const adhSess=adhDay?.sessions?.[si];
            const sessStatus=adhSess?.status||'upcoming';
            const isMissed=sessStatus==='missed';
            const isShortened=sessStatus==='shortened';
            const isSub=sessStatus==='substituted';
            const priorityColor=sess.priority==='red'?C.accent:C.yellow;
            const fuelKey=`${di}-${si}`;
            return (<div key={si}>
              <div onClick={isStr&&sess.templateId&&!done?()=>startStrength(sess.templateId):undefined} style={{display:'flex',alignItems:'flex-start',gap:12,padding:'12px 10px',borderRadius:12,cursor:isStr&&sess.templateId&&!done&&!isMissed?'pointer':'default',borderBottom:si<daySessions.length-1?`1px solid ${C.border}`:'none',background:done?C.green+'08':(isMissed?C.red+'06':'transparent')}}>
                <div style={{width:36,height:36,borderRadius:12,background:done?C.green+'20':(isMissed?C.red+'15':sport.color+'20'),display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,marginTop:2}}>
                  {done?<Icon name='check' size={18} color={C.green}/>:isMissed?<span style={{fontFamily:F.ui,fontSize:14,color:C.red}}>✕</span>:<Icon name={isStr?'dumbbell':sport.icon} size={18} color={sport.color}/>}
                </div>
                <div style={{flex:1}}>
                  <div style={{display:'flex',alignItems:'center',gap:6}}>
                    <div style={{width:6,height:6,borderRadius:'50%',background:done?C.green:(isMissed?C.red:priorityColor),flexShrink:0}}/>
                    <div style={{fontFamily:F.ui,fontWeight:600,fontSize:15,color:done?C.green:(isMissed?C.muted:C.text),textDecoration:isMissed?'line-through':'none'}}>{sess.label}</div>
                    {done&&!isShortened&&<Pill color={C.green} small>Done</Pill>}
                    {isShortened&&<Pill color={C.yellow} small>{adhSess?.actualDuration}min / {sess.duration}min</Pill>}
                    {isMissed&&<Pill color={C.red} small>Missed</Pill>}
                    {isSub&&<Pill color={C.yellow} small>Swapped → {SPORT_META[adhSess?.substitute]?.label||adhSess?.substitute}</Pill>}
                  </div>
                  {sess.zone&&!done&&<div style={{fontFamily:F.mono,fontSize:12,color:sport.color,marginTop:3}}>{sess.zone}{sess.targetIntensity?' · '+sess.targetIntensity:''}</div>}
                  {sess.notes&&!done&&<div style={{fontFamily:F.ui,fontSize:13,color:C.subtle,marginTop:3,lineHeight:1.5}}>{sess.notes}</div>}
                  {sess.fuel&&!done&&<button onClick={(e)=>{e.stopPropagation();setShowFuel(showFuel===fuelKey?null:fuelKey);}} style={{background:C.elevated,border:`1px solid ${C.border}`,borderRadius:8,padding:'4px 10px',marginTop:6,cursor:'pointer',fontFamily:F.ui,fontSize:11,fontWeight:600,color:C.muted,display:'flex',alignItems:'center',gap:4}}>
                    <Icon name='zap' size={10} color={C.muted}/> Fuel {showFuel===fuelKey?'▲':'▼'}
                  </button>}
                  {showFuel===fuelKey&&sess.fuel&&!done&&<div className="fade-up" style={{marginTop:6,padding:'8px 10px',background:C.elevated,borderRadius:8,border:`1px solid ${C.border}`}}>
                    {sess.fuel.pre&&<div style={{fontFamily:F.ui,fontSize:12,color:C.subtle,marginBottom:4}}><span style={{fontWeight:600,color:C.green}}>Pre:</span> {sess.fuel.pre}</div>}
                    {sess.fuel.during&&<div style={{fontFamily:F.ui,fontSize:12,color:C.subtle,marginBottom:4}}><span style={{fontWeight:600,color:C.cyan}}>During:</span> {sess.fuel.during}</div>}
                    {sess.fuel.post&&<div style={{fontFamily:F.ui,fontSize:12,color:C.subtle}}><span style={{fontWeight:600,color:C.purple}}>Post:</span> {sess.fuel.post}</div>}
                  </div>}
                </div>
                <div style={{textAlign:'right',flexShrink:0}}>
                  {sess.duration&&<div style={{fontFamily:F.mono,fontSize:13,color:done?C.green:C.muted}}>{fmtDur(sess.duration)}</div>}
                  {isStr&&sess.templateId&&!done&&<div style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:C.green,marginTop:4}}>Start →</div>}
                </div>
              </div>
            </div>);
          })}
        </Card>}
      </div>);
    })}

    {/* Weekly summary for past weeks */}
    {weekAdherence&&weekAdherence.days.every(d=>d.isPast||d.isRest)&&weekAdherence.prescribed>0&&<Card style={{marginTop:12,marginBottom:4,padding:'14px 16px',borderColor:weekAdherence.adherence>=85?C.green+'30':weekAdherence.adherence>=60?C.yellow+'30':C.red+'30'}}>
      <div style={{display:'flex',alignItems:'center',gap:10,marginBottom:8}}>
        <div style={{width:28,height:28,borderRadius:8,background:weekAdherence.adherence>=85?C.green+'18':weekAdherence.adherence>=60?C.yellow+'18':C.red+'18',display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name={weekAdherence.adherence>=85?'check':'alert'} size={14} color={weekAdherence.adherence>=85?C.green:weekAdherence.adherence>=60?C.yellow:C.red}/></div>
        <div>
          <div style={{fontFamily:F.ui,fontWeight:700,fontSize:14,color:C.text}}>Week {tp.currentWeek} Summary</div>
          <div style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginTop:1}}>{weekAdherence.completed} completed · {weekAdherence.shortened} shortened · {weekAdherence.missed} missed</div>
        </div>
        <div style={{marginLeft:'auto',fontFamily:F.display,fontSize:24,fontWeight:700,color:weekAdherence.adherence>=85?C.green:weekAdherence.adherence>=60?C.yellow:C.red}}>{weekAdherence.adherence}%</div>
      </div>
      {Object.keys(weekAdherence.missedByType).length>0&&<div style={{display:'flex',gap:6,flexWrap:'wrap'}}>
        {Object.entries(weekAdherence.missedByType).map(([sport,count])=><Pill key={sport} color={C.red} small>{SPORT_META[sport]?.label||sport}: {count} missed</Pill>)}
      </div>}
      {multiWeekPatterns.length>0&&<div style={{marginTop:8,paddingTop:8,borderTop:`1px solid ${C.border}`}}>
        {multiWeekPatterns.map((p,i)=><div key={i} style={{fontFamily:F.ui,fontSize:12,color:C.yellow,display:'flex',alignItems:'center',gap:6,marginTop:i>0?4:0}}><Icon name='alert' size={12} color={C.yellow}/>{p}</div>)}
      </div>}
    </Card>}

    {/* Disruption shortcuts */}
    {onDisruption&&<div style={{marginTop:24}}>
      <Label>Need to adjust?</Label>
      <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:8}}>
        {[
          {icon:'alert',label:"I'm sick",color:C.red,msg:"I'm sick and need to modify my training this week. What should I do? Check my current plan and recent workouts first."},
          {icon:'pin',label:'Traveling',color:C.cyan,msg:"I'm traveling this week with limited equipment. Please regenerate my week with hotel/bodyweight alternatives. Check my current plan first."},
          {icon:'rest',label:'Extra recovery',color:C.purple,msg:"I need extra recovery this week — feeling fatigued. Please regenerate a lighter week that maintains frequency but drops volume. Check my recent workouts first."},
          {icon:'calendar',label:'Missed sessions',color:C.yellow,msg:"I missed some sessions recently. Check my workouts vs my plan and help me recalibrate the rest of this week. Don't try to make up missed volume."},
        ].map((d,i)=><Card key={i} onClick={()=>onDisruption(d.msg)} style={{padding:'14px 12px',cursor:'pointer'}}>
          <div style={{display:'flex',alignItems:'center',gap:10}}>
            <div style={{width:32,height:32,borderRadius:10,background:d.color+'18',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}><Icon name={d.icon} size={16} color={d.color}/></div>
            <span style={{fontFamily:F.ui,fontWeight:600,fontSize:13,color:C.text}}>{d.label}</span>
          </div>
        </Card>)}
      </div>
    </div>}

    {/* Season week grid */}
    <div style={{marginTop:24}}>
      <Label>Season overview</Label>
      <div style={{display:'flex',flexWrap:'wrap',gap:4,marginBottom:10}}>
        {Array.from({length:tp.totalWeeks},(_,i)=>{
          const wk=i+1;
          let cumWeeks=0;let phIdx=0;let weekInPhase=0;
          for(let pi=0;pi<(tp.phases?.length||0);pi++){if(wk<=cumWeeks+tp.phases[pi].weeks){phIdx=pi;weekInPhase=wk-cumWeeks;break;}cumWeeks+=tp.phases[pi].weeks;}
          const ph=tp.phases?.[phIdx];
          const color=phaseColors[phIdx%phaseColors.length];
          const isCurrent=wk===tp.currentWeek;
          const isPast=wk<tp.currentWeek;
          const isDeload=ph?.deloadWeek&&weekInPhase===ph.deloadWeek;
          const isGenerated=!!tp.weeklyPlans?.[String(wk)];
          return (<div key={wk} style={{width:28,height:28,borderRadius:6,background:isCurrent?color:(isPast?color+'30':C.elevated),border:isDeload?`2px solid ${C.yellow}80`:`1.5px solid ${isCurrent?color:isPast?color+'20':'transparent'}`,display:'flex',alignItems:'center',justifyContent:'center',position:'relative',cursor:'default'}}>
            <span style={{fontFamily:F.mono,fontSize:9,fontWeight:isCurrent?700:500,color:isCurrent?'#fff':(isPast?color:C.muted)}}>{wk}</span>
            {isGenerated&&!isCurrent&&<div style={{position:'absolute',top:-1,right:-1,width:7,height:7,borderRadius:'50%',background:C.green,border:`1.5px solid ${C.bg}`}}/>}
          </div>);
        })}
      </div>
      <div style={{display:'flex',gap:12,flexWrap:'wrap'}}>
        {[{label:'Current',color:C.accent,type:'solid'},{label:'Complete',color:C.accent+'30',type:'solid'},{label:'Upcoming',color:C.elevated,type:'solid'},{label:'Deload',color:C.yellow,type:'border'},{label:'Generated',color:C.green,type:'dot'}].map(({label,color,type})=>
          <div key={label} style={{display:'flex',alignItems:'center',gap:5}}>
            {type==='solid'&&<div style={{width:10,height:10,borderRadius:3,background:color}}/>}
            {type==='border'&&<div style={{width:10,height:10,borderRadius:3,border:`2px solid ${color}`,background:'transparent'}}/>}
            {type==='dot'&&<div style={{width:10,height:10,borderRadius:'50%',background:color}}/>}
            <span style={{fontFamily:F.ui,fontSize:10,color:C.muted,fontWeight:500}}>{label}</span>
          </div>
        )}
      </div>
    </div>

    {/* Phase overview */}
    <div style={{marginTop:24}}>
      <Label>Season phases</Label>
      {tp.phases?.map((ph,i)=>{
        const color=phaseColors[i%phaseColors.length];
        const isCurrent=ph.number===tp.currentPhase;
        const isPast=ph.number<tp.currentPhase;
        const isExpanded=expandedPhase===ph.number;
        return (<div key={ph.number} style={{marginBottom:8}}>
          <Card onClick={()=>setExpandedPhase(isExpanded?null:ph.number)} style={{padding:'12px 16px',borderColor:isCurrent?color+'40':C.border,background:isCurrent?color+'08':C.card,opacity:isPast?0.7:1}}>
            <div style={{display:'flex',alignItems:'center',gap:10}}>
              <div style={{width:28,height:28,borderRadius:10,background:color+'20',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
                {isPast?<Icon name='check' size={14} color={color}/>:<span style={{fontFamily:F.display,fontSize:14,fontWeight:700,color}}>{ph.number}</span>}
              </div>
              <div style={{flex:1}}>
                <div style={{fontFamily:F.ui,fontWeight:600,fontSize:14,color:isCurrent?color:C.text}}>{ph.name}</div>
                <div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginTop:1}}>{ph.weeks} weeks · {ph.weeklyVolume}</div>
              </div>
              <span style={{fontFamily:F.ui,fontSize:12,color:C.muted}}>{isExpanded?'▲':'▼'}</span>
            </div>
            {isExpanded&&<div className="fade-up" style={{marginTop:12,paddingTop:12,borderTop:`1px solid ${C.border}`}}>
              <div style={{fontFamily:F.ui,fontSize:13,color:C.subtle,lineHeight:1.65,marginBottom:10}}>{ph.focus}</div>
              <div style={{display:'flex',flexWrap:'wrap',gap:6}}>
                <Pill color={color} small>{ph.intensityCeiling}</Pill>
                <Pill color={C.muted} small>{ph.strengthFreq}</Pill>
                {ph.deloadWeek&&<Pill color={C.yellow} small>Deload wk {ph.deloadWeek}</Pill>}
              </div>
              {ph.keySessionTypes?.length>0&&<div style={{marginTop:8,fontFamily:F.ui,fontSize:12,color:C.muted}}>Key sessions: {ph.keySessionTypes.join(', ')}</div>}
              <div style={{marginTop:8,fontFamily:F.mono,fontSize:11,color:C.muted}}>{ph.startDate} → {ph.endDate}</div>
            </div>}
          </Card>
        </div>);
      })}
    </div>
    {planBuilder&&<PlanBuilderSheet goal={planBuilder.goal} mode={planBuilder.mode} appState={appState} onPlanCreated={onPlanCreated} onWeekGenerated={onWeekGenerated} onClose={()=>setPlanBuilder(null)}/>}
  </div>);
}

// ─── Brick Components ─────────────────────────────────────────────────────────
function LinkBrickSheet({cardio,bricks,onSave,onClose}){
  const[leg1,setLeg1]=useState(null);const[leg2,setLeg2]=useState(null);
  const[tTime,setTTime]=useState('');const[tNotes,setTNotes]=useState('');
  const alreadyLinked=new Set(bricks.flatMap(b=>b.legs.map(l=>l.workoutId)));
  const recent=cardio.filter(w=>w.sport!=='strength'&&!alreadyLinked.has(w.id)).sort((a,b)=>b.date.localeCompare(a.date)).slice(0,30);
  const byDate=recent.reduce((acc,w)=>{const k=w.date===todayStr()?'Today':fmtDateSh(w.date);if(!acc[k])acc[k]=[];acc[k].push(w);return acc;},{});
  const canSave=leg1&&leg2&&leg1.id!==leg2.id;
  const handleTap=w=>{if(!leg1)setLeg1(w);else if(!leg2&&w.id!==leg1.id&&w.date===leg1.date)setLeg2(w);else if(w.id===leg1?.id)setLeg1(null);else if(w.id===leg2?.id)setLeg2(null);else{setLeg1(w);setLeg2(null);}};
  return(<Sheet onClose={onClose} title="Link Brick Workout">
    <div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,marginBottom:16,lineHeight:1.6}}>Select two workouts from the same day to link as a brick.</div>
    {leg1&&<div style={{marginBottom:14,padding:'10px 14px',background:C.accent+'08',borderRadius:12,border:`1.5px solid ${C.accent}30`}}>
      <div style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:C.accent,marginBottom:6}}>Brick legs</div>
      <div style={{display:'flex',alignItems:'center',gap:8}}>
        <SportBadge sport={leg1.sport} small/><span style={{fontFamily:F.ui,fontSize:13,color:C.text,flex:1}}>{leg1.notes||SPORT_META[leg1.sport]?.label} · {fmtDur(leg1.duration)}</span>
      </div>
      {leg2?<><div style={{fontFamily:F.ui,fontSize:11,color:C.muted,textAlign:'center',margin:'4px 0'}}>→ transition →</div>
        <div style={{display:'flex',alignItems:'center',gap:8}}>
          <SportBadge sport={leg2.sport} small/><span style={{fontFamily:F.ui,fontSize:13,color:C.text,flex:1}}>{leg2.notes||SPORT_META[leg2.sport]?.label} · {fmtDur(leg2.duration)}</span>
        </div></>:<div style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginTop:6}}>Tap a second workout from {fmtDateSh(leg1.date)} below</div>}
    </div>}
    {canSave&&<div style={{display:'flex',gap:10,marginBottom:16}}>
      <div style={{flex:1}}><Label>Transition (min)</Label><Inp type="number" placeholder="e.g. 4" value={tTime} onChange={e=>setTTime(e.target.value)}/></div>
      <div style={{flex:2}}><Label>Transition notes</Label><Inp placeholder="e.g. elastic laces, grabbed gel" value={tNotes} onChange={e=>setTNotes(e.target.value)}/></div>
    </div>}
    {Object.entries(byDate).map(([dateLabel,wos])=><div key={dateLabel}>
      <div style={{fontFamily:F.ui,fontSize:11,fontWeight:700,color:C.muted,marginBottom:6,marginTop:8,textTransform:'uppercase',letterSpacing:'.06em'}}>{dateLabel}</div>
      {wos.map(w=>{const sel=w.id===leg1?.id||w.id===leg2?.id;const sameDayAsLeg1=!leg1||w.date===leg1.date;const s=SPORT_META[w.sport]||SPORT_META.other;return(
        <div key={w.id} onClick={sameDayAsLeg1?()=>handleTap(w):undefined} style={{display:'flex',alignItems:'center',gap:12,padding:'11px 14px',marginBottom:6,background:sel?s.color+'12':C.elevated,border:`1.5px solid ${sel?s.color:C.border}`,borderRadius:12,cursor:sameDayAsLeg1?'pointer':'default',opacity:sameDayAsLeg1?1:0.4,transition:'all .15s'}}>
          <SportBadge sport={w.sport} small/>
          <div style={{flex:1}}><div style={{fontFamily:F.ui,fontSize:14,fontWeight:500,color:sel?s.color:C.text}}>{w.notes||s.label}</div></div>
          <div style={{fontFamily:F.mono,fontSize:12,color:C.muted}}>{fmtDur(w.duration)}</div>
          {sel&&<div style={{width:20,height:20,borderRadius:6,background:s.color,display:'flex',alignItems:'center',justifyContent:'center'}}><span style={{color:'#fff',fontSize:11,fontWeight:700}}>✓</span></div>}
        </div>);})}
    </div>)}
    {canSave&&<Btn onClick={()=>onSave({date:leg1.date,legs:[{workoutId:leg1.id,sport:leg1.sport},{workoutId:leg2.id,sport:leg2.sport}],transitionTime:tTime?parseInt(tTime):null,transitionNotes:tNotes,notes:''})} color={C.accent} style={{width:'100%',padding:14,fontSize:16,marginTop:8}}>Link brick</Btn>}
  </Sheet>);
}

function BrickPromptBanner({workout,candidates,onLink,onDismiss}){
  const s=SPORT_META[workout.sport]||SPORT_META.other;
  const c=candidates[0];const cs=SPORT_META[c?.sport]||SPORT_META.other;
  if(!c)return null;
  return(<div className="fade-up" style={{margin:'0 0 12px',padding:'12px 16px',background:C.accent+'08',borderRadius:14,border:`1.5px solid ${C.accent}30`}}>
    <div style={{display:'flex',alignItems:'center',gap:10,marginBottom:8}}>
      <Icon name='layers' size={18} color={C.accent}/>
      <div style={{fontFamily:F.ui,fontWeight:700,fontSize:14,color:C.accent}}>Brick workout?</div>
      <button onClick={onDismiss} style={{marginLeft:'auto',background:'none',border:'none',color:C.muted,fontSize:16,cursor:'pointer',padding:2}}>✕</button>
    </div>
    <div style={{fontFamily:F.ui,fontSize:13,color:C.subtle,lineHeight:1.6,marginBottom:10}}>
      You did a <strong style={{color:cs.color}}>{cs.label}</strong> and a <strong style={{color:s.color}}>{s.label}</strong> today. Was this a brick?
    </div>
    <div style={{display:'flex',gap:8}}>
      <Btn onClick={()=>onLink(workout,c)} color={C.accent} style={{flex:1,padding:10,fontSize:13}}>Link as brick</Btn>
      <Btn onClick={onDismiss} outline style={{flex:1,padding:10,fontSize:13}}>Not a brick</Btn>
    </div>
  </div>);
}

// ─── Workout Detail Sheets ────────────────────────────────────────────────────
function WorkoutDetailSheet({workout,onClose}){
  const s=SPORT_META[workout.sport]||SPORT_META.other;
  const isStrength=workout.kind==='strength';
  const fullDate=workout.date?new Date(workout.date+'T12:00:00').toLocaleDateString('en-US',{weekday:'long',month:'long',day:'numeric',year:'numeric'}):'';
  return(<Sheet onClose={onClose} title="Workout details">
    <div style={{display:'flex',alignItems:'center',gap:12,marginBottom:20}}>
      <div style={{width:52,height:52,borderRadius:16,background:s.color+'20',display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name={isStrength?'dumbbell':s.icon} size={26} color={s.color}/></div>
      <div style={{flex:1}}>
        <div style={{fontFamily:F.display,fontSize:22,fontWeight:800,color:C.text}}>{s.label}</div>
        <div style={{fontFamily:F.ui,fontSize:13,color:C.muted}}>{fullDate}</div>
      </div>
    </div>
    <div style={{display:'grid',gridTemplateColumns:workout.distance?'1fr 1fr 1fr':'1fr 1fr',gap:10,marginBottom:20}}>
      <Card style={{textAlign:'center',padding:'14px 8px'}}><div style={{fontFamily:F.display,fontSize:28,fontWeight:700,color:C.text,lineHeight:1}}>{fmtDur(workout.duration)}</div><div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginTop:5,fontWeight:500}}>Duration</div></Card>
      {workout.distance&&<Card style={{textAlign:'center',padding:'14px 8px'}}><div style={{fontFamily:F.display,fontSize:28,fontWeight:700,color:C.text,lineHeight:1}}>{workout.distance}</div><div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginTop:5,fontWeight:500}}>Distance</div></Card>}
      {workout.avgHR?<Card style={{textAlign:'center',padding:'14px 8px'}}><div style={{fontFamily:F.display,fontSize:28,fontWeight:700,color:C.accent,lineHeight:1}}>{workout.avgHR}</div><div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginTop:5,fontWeight:500}}>Avg HR</div></Card>
      :workout.calories?<Card style={{textAlign:'center',padding:'14px 8px'}}><div style={{fontFamily:F.display,fontSize:28,fontWeight:700,color:C.yellow,lineHeight:1}}>{workout.calories}</div><div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginTop:5,fontWeight:500}}>Calories</div></Card>
      :<Card style={{textAlign:'center',padding:'14px 8px'}}><div style={{fontFamily:F.display,fontSize:28,fontWeight:700,color:s.color,lineHeight:1}}>{s.label}</div><div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginTop:5,fontWeight:500}}>Sport</div></Card>}
    </div>

    {(workout.pace||workout.avgPower)&&<div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10,marginBottom:20}}>
      {workout.pace&&<Card style={{textAlign:'center',padding:'14px 8px'}}><div style={{fontFamily:F.mono,fontSize:20,fontWeight:700,color:C.text}}>{workout.pace}</div><div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginTop:5}}>Pace</div></Card>}
      {workout.avgPower&&<Card style={{textAlign:'center',padding:'14px 8px'}}><div style={{fontFamily:F.mono,fontSize:20,fontWeight:700,color:C.cyan}}>{workout.avgPower}W</div><div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginTop:5}}>Avg Power</div></Card>}
    </div>}

    {(workout.startTime||workout.endTime)&&<Card style={{marginBottom:16,padding:'12px 16px'}}>
      <div style={{display:'flex',justifyContent:'space-between'}}>
        {workout.startTime&&<div><div style={{fontFamily:F.ui,fontSize:11,color:C.muted,fontWeight:600}}>Start</div><div style={{fontFamily:F.mono,fontSize:14,color:C.text,marginTop:2}}>{workout.startTime}</div></div>}
        {workout.endTime&&<div style={{textAlign:'right'}}><div style={{fontFamily:F.ui,fontSize:11,color:C.muted,fontWeight:600}}>End</div><div style={{fontFamily:F.mono,fontSize:14,color:C.text,marginTop:2}}>{workout.endTime}</div></div>}
      </div>
    </Card>}

    {workout.avgHR&&workout.maxHR&&<Card style={{marginBottom:16,padding:'12px 16px'}}>
      <Label style={{marginBottom:8}}>Heart Rate</Label>
      <div style={{display:'flex',gap:16}}>
        <div><span style={{fontFamily:F.mono,fontSize:18,fontWeight:700,color:C.accent}}>{workout.avgHR}</span><span style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginLeft:4}}>avg</span></div>
        <div><span style={{fontFamily:F.mono,fontSize:18,fontWeight:700,color:C.red}}>{workout.maxHR}</span><span style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginLeft:4}}>max</span></div>
      </div>
      {workout.hrZones&&<div style={{marginTop:10,display:'flex',gap:3,height:8,borderRadius:4,overflow:'hidden'}}>
        {[{z:'Z1',c:'#4890D8'},{z:'Z2',c:'#2ABF84'},{z:'Z3',c:'#F0A830'},{z:'Z4',c:'#E8604C'},{z:'Z5',c:'#CC1111'}].map(({z,c})=>{
          const pct=workout.hrZones[z]||0;
          return pct>0?<div key={z} style={{flex:pct,background:c,borderRadius:2}} title={`${z}: ${pct}%`}/>:null;
        })}
      </div>}
      {workout.hrZones&&<div style={{display:'flex',gap:8,marginTop:8,flexWrap:'wrap'}}>
        {[{z:'Z1',c:'#4890D8',l:'Recovery'},{z:'Z2',c:'#2ABF84',l:'Aerobic'},{z:'Z3',c:'#F0A830',l:'Tempo'},{z:'Z4',c:'#E8604C',l:'Threshold'},{z:'Z5',c:'#CC1111',l:'VO2max'}].map(({z,c,l})=>{
          const pct=workout.hrZones[z]||0;
          return pct>0?<div key={z} style={{display:'flex',alignItems:'center',gap:4}}><div style={{width:8,height:8,borderRadius:2,background:c}}/><span style={{fontFamily:F.ui,fontSize:10,color:C.muted}}>{z} {pct}%</span></div>:null;
        })}
      </div>}
    </Card>}

    {workout.location&&<Card style={{marginBottom:16,padding:'12px 16px'}}>
      <div style={{display:'flex',alignItems:'center',gap:8}}><Icon name='pin' size={14} color={C.cyan}/><span style={{fontFamily:F.ui,fontSize:14,color:C.text}}>{workout.location}</span></div>
    </Card>}

    {workout.notes&&<Card style={{marginBottom:16,padding:'12px 16px'}}>
      <Label style={{marginBottom:6}}>Notes</Label>
      <div style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.7,whiteSpace:'pre-wrap'}}>{workout.notes}</div>
    </Card>}

    {isStrength&&workout.exercises&&<div style={{marginBottom:16}}>
      <Label>Exercises</Label>
      {workout.exercises.map((ex,i)=><Card key={i} style={{marginBottom:8,padding:'12px 16px'}}>
        <div style={{fontFamily:F.ui,fontWeight:700,fontSize:15,color:C.text,marginBottom:6}}>{ex.name}</div>
        <div style={{display:'flex',gap:6,flexWrap:'wrap'}}>{ex.sets?.filter(s=>s.completed).map((s,j)=><span key={j} style={{fontFamily:F.mono,fontSize:12,color:C.subtle,background:C.elevated,borderRadius:8,padding:'4px 10px'}}>{s.weight>0?`${s.weight}×${s.reps}`:`BW×${s.reps}`}</span>)}</div>
      </Card>)}
    </div>}

    {workout.source==='healthkit'&&<div style={{display:'flex',alignItems:'center',gap:6,marginBottom:16}}><Icon name='watch' size={14} color={C.cyan}/><span style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:C.cyan}}>Imported from Apple Health</span></div>}
  </Sheet>);
}

function BrickDetailSheet({brick,cardio,onDelete,onClose}){
  const legs=(brick.legs||[]).map(l=>{const w=cardio.find(c=>c.id===l.workoutId);return{...l,workout:w};});
  const totalDur=legs.reduce((t,l)=>t+(l.workout?.duration||0),0)+(brick.transitionTime||0);
  return(<Sheet onClose={onClose} title="Brick workout">
    <div style={{display:'flex',alignItems:'center',gap:12,marginBottom:20}}>
      <div style={{width:52,height:52,borderRadius:16,background:C.yellow+'20',display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name='layers' size={26} color={C.yellow}/></div>
      <div style={{flex:1}}>
        <div style={{fontFamily:F.display,fontSize:22,fontWeight:800,color:C.text}}>Brick Workout</div>
        <div style={{fontFamily:F.ui,fontSize:13,color:C.muted}}>{brick.date?new Date(brick.date+'T12:00:00').toLocaleDateString('en-US',{weekday:'long',month:'long',day:'numeric'}):''}</div>
      </div>
    </div>

    <div style={{display:'grid',gridTemplateColumns:'1fr 1fr 1fr',gap:10,marginBottom:20}}>
      <Card style={{textAlign:'center',padding:'14px 8px'}}><div style={{fontFamily:F.display,fontSize:28,fontWeight:700,color:C.text,lineHeight:1}}>{fmtDur(totalDur)}</div><div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginTop:5}}>Total</div></Card>
      <Card style={{textAlign:'center',padding:'14px 8px'}}><div style={{fontFamily:F.display,fontSize:28,fontWeight:700,color:C.text,lineHeight:1}}>{legs.length}</div><div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginTop:5}}>Legs</div></Card>
      <Card style={{textAlign:'center',padding:'14px 8px'}}><div style={{fontFamily:F.display,fontSize:28,fontWeight:700,color:brick.transitionTime?C.yellow:C.muted,lineHeight:1}}>{brick.transitionTime?brick.transitionTime+'m':'—'}</div><div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginTop:5}}>Transition</div></Card>
    </div>

    {legs.map((leg,i)=>{const s=SPORT_META[leg.sport]||SPORT_META.other;const w=leg.workout;return(<div key={i}>
      {i>0&&<div style={{display:'flex',alignItems:'center',gap:8,padding:'8px 0',justifyContent:'center'}}>
        <div style={{height:1,flex:1,background:C.border}}/><span style={{fontFamily:F.ui,fontSize:11,fontWeight:700,color:C.yellow,textTransform:'uppercase',letterSpacing:'.06em'}}>T{i}</span><div style={{height:1,flex:1,background:C.border}}/>
      </div>}
      <Card style={{marginBottom:8,padding:'14px 16px',borderColor:s.color+'30'}}>
        <div style={{display:'flex',alignItems:'center',gap:12}}>
          <div style={{width:40,height:40,borderRadius:12,background:s.color+'20',display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name={s.icon} size={20} color={s.color}/></div>
          <div style={{flex:1}}>
            <div style={{fontFamily:F.ui,fontWeight:700,fontSize:16,color:C.text}}>{s.label}</div>
            {w?.notes&&<div style={{fontFamily:F.ui,fontSize:13,color:C.subtle,marginTop:2,lineHeight:1.5}}>{w.notes}</div>}
          </div>
          <div style={{textAlign:'right'}}>
            <div style={{fontFamily:F.display,fontSize:24,fontWeight:700,color:C.text}}>{w?fmtDur(w.duration):'—'}</div>
            {w?.distance&&<div style={{fontFamily:F.mono,fontSize:11,color:C.muted}}>{w.distance}</div>}
          </div>
        </div>
        {w?.avgHR&&<div style={{marginTop:8,display:'flex',gap:10}}>
          <span style={{fontFamily:F.mono,fontSize:12,color:C.accent}}>HR {w.avgHR} avg</span>
          {w.pace&&<span style={{fontFamily:F.mono,fontSize:12,color:s.color}}>{w.pace}</span>}
        </div>}
      </Card>
    </div>);})}

    {brick.transitionNotes&&<Card style={{marginBottom:16,padding:'12px 16px',borderColor:C.yellow+'30'}}>
      <Label style={{color:C.yellow,marginBottom:6}}>Transition notes</Label>
      <div style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.7}}>{brick.transitionNotes}</div>
    </Card>}

    {brick.notes&&<Card style={{marginBottom:16,padding:'12px 16px'}}>
      <Label style={{marginBottom:6}}>Notes</Label>
      <div style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.7}}>{brick.notes}</div>
    </Card>}

    <Btn onClick={async()=>{if(onDelete){await onDelete(brick.id);onClose();}}} outline style={{width:'100%',padding:13,fontSize:14,borderColor:C.red+'50',color:C.red}}>Unlink brick</Btn>
  </Sheet>);
}

// ─── Log Tab ───────────────────────────────────────────────────────────────────
function HealthImportSheet({onImport,onClose,existingIds}){const[workouts,setWorkouts]=useState([]);useEffect(()=>{fetch('/seed-data.json').then(r=>r.json()).then(d=>setWorkouts(d.healthWorkouts||[])).catch(()=>{});},[]);const[selected,setSelected]=useState(new Set());const toggle=id=>{if(existingIds.has(id))return;setSelected(prev=>{const n=new Set(prev);n.has(id)?n.delete(id):n.add(id);return n;});};return(<Sheet onClose={onClose} title="Import from Health"><div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,marginBottom:16,lineHeight:1.65}}>Recent workouts from Apple Health. On the native app this reads real data — showing sample data for now.</div><div style={{fontFamily:F.ui,fontSize:13,fontWeight:600,color:C.muted,marginBottom:12}}>{selected.size} selected</div><div style={{display:'flex',flexDirection:'column',gap:8,marginBottom:20}}>{workouts.map(w=>{const s=SPORT_META[w.sport]||SPORT_META.other;const sel=selected.has(w.id);const done=existingIds.has(w.id);return(<div key={w.id} onClick={()=>toggle(w.id)} style={{display:'flex',alignItems:'center',gap:12,padding:'13px 16px',background:sel?s.color+'10':C.elevated,border:`1.5px solid ${sel?s.color:C.border}`,borderRadius:14,cursor:done?'default':'pointer',opacity:done?.6:1,transition:'all .15s'}}><Icon name={s.icon} size={22} color={s.color}/><div style={{flex:1}}><div style={{fontFamily:F.ui,fontWeight:600,fontSize:15,color:sel?s.color:C.text}}>{w.notes}</div><div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:2}}>{fmtDateSh(w.date)} · {fmtDur(w.duration)}</div></div><div style={{width:24,height:24,borderRadius:8,background:done?C.green+'20':(sel?s.color:C.surface),border:`1.5px solid ${done?C.green:(sel?s.color:C.border)}`,display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>{(sel||done)&&<span style={{fontSize:12,color:done?C.green:'#fff',fontWeight:700}}>✓</span>}</div></div>);})}</div><Btn onClick={()=>selected.size>0&&onImport(workouts.filter(w=>selected.has(w.id)))} color={C.cyan} disabled={selected.size===0} style={{width:'100%',padding:15,fontSize:16}}>Import {selected.size>0?`${selected.size} workout${selected.size>1?'s':''}`:'workouts'}</Btn></Sheet>);}

function LogWorkoutSheet({onSave,onClose}){const[sport,setSport]=useState('run');const[dur,setDur]=useState('');const[notes,setNotes]=useState('');const[date,setDate]=useState(todayStr());return(<Sheet onClose={onClose} title="Log workout"><div style={{display:'flex',gap:8,overflowX:'auto',paddingBottom:4,marginBottom:16,scrollbarWidth:'none'}}>{Object.entries(SPORT_META).map(([k,s])=><button key={k} onClick={()=>setSport(k)} style={{flexShrink:0,background:sport===k?s.color+'18':C.elevated,border:`1.5px solid ${sport===k?s.color:C.border}`,borderRadius:12,padding:'10px 14px',cursor:'pointer',display:'flex',flexDirection:'column',alignItems:'center',gap:4,transition:'all .15s',minWidth:66}}><Icon name={s.icon} size={20} color={sport===k?s.color:C.muted}/><span style={{fontFamily:F.ui,fontSize:11,fontWeight:600,color:sport===k?s.color:C.muted}}>{s.label}</span></button>)}</div><div style={{display:'flex',gap:10,marginBottom:12}}><div style={{flex:1}}><Label>Duration (min)</Label><Inp type="number" placeholder="45" value={dur} onChange={e=>setDur(e.target.value)}/></div><div style={{flex:1}}><Label>Date</Label><Inp type="date" value={date} onChange={e=>setDate(e.target.value)}/></div></div><Label>Notes</Label><Textarea placeholder="How did it go?" value={notes} onChange={e=>setNotes(e.target.value)} rows={3} style={{marginBottom:16}}/><Btn onClick={()=>dur&&onSave({sport,duration:parseInt(dur),notes,date})} color={C.accent} disabled={!dur} style={{width:'100%',padding:14,fontSize:16}}>Save workout</Btn></Sheet>);}

function WorkoutLogTab({cardio,strength,onAddCardio,onImportHealth,bricks,onSaveBrick,onDeleteBrick}){
  const[showLog,setShowLog]=useState(false);const[showImport,setShowImport]=useState(false);const[showBrickLink,setShowBrickLink]=useState(false);const[filter,setFilter]=useState('all');
  const[selectedWorkout,setSelectedWorkout]=useState(null);const[selectedBrick,setSelectedBrick]=useState(null);
  const existingIds=new Set(cardio.filter(w=>w.source==='healthkit').map(w=>w.id));
  const allWorkouts=[...cardio.map(w=>({...w,kind:'cardio'})),...strength.map(s=>({...s,sport:'strength',kind:'strength',notes:`${s.exercises?.reduce((t,e)=>t+(e.sets?.length||0),0)||0} sets logged`}))].sort((a,b)=>b.date.localeCompare(a.date));
  const filtered=filter==='all'?allWorkouts:allWorkouts.filter(w=>w.sport===filter);
  const groups=filtered.reduce((acc,w)=>{const key=w.date===todayStr()?'Today':w.date===new Date(Date.now()-86400000).toISOString().split('T')[0]?'Yesterday':fmtDateSh(w.date);if(!acc[key])acc[key]=[];acc[key].push(w);return acc;},{});
  const brickWorkoutIds=new Set((bricks||[]).flatMap(b=>b.legs.map(l=>l.workoutId)));
  const brickForWorkout=wId=>(bricks||[]).find(b=>b.legs.some(l=>l.workoutId===wId));
  return(<div style={{paddingBottom:80}}><div style={{display:'grid',gridTemplateColumns:'1fr 1fr 1fr',gap:8,marginBottom:18}}><Card onClick={()=>setShowLog(true)} accent={C.accent}><div style={{display:'flex',flexDirection:'column',alignItems:'center',gap:6,padding:'4px 0'}}><div style={{width:34,height:34,borderRadius:10,background:C.accent+'18',display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name='pencil' size={16} color={C.accent}/></div><div style={{fontFamily:F.ui,fontWeight:700,fontSize:12,color:C.accent,textAlign:'center'}}>Log</div></div></Card><Card onClick={()=>setShowImport(true)} accent={C.cyan}><div style={{display:'flex',flexDirection:'column',alignItems:'center',gap:6,padding:'4px 0'}}><div style={{width:34,height:34,borderRadius:10,background:C.cyan+'18',display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name='watch' size={16} color={C.cyan}/></div><div style={{fontFamily:F.ui,fontWeight:700,fontSize:12,color:C.cyan,textAlign:'center'}}>Import</div></div></Card><Card onClick={()=>setShowBrickLink(true)} accent={C.yellow}><div style={{display:'flex',flexDirection:'column',alignItems:'center',gap:6,padding:'4px 0'}}><div style={{width:34,height:34,borderRadius:10,background:C.yellow+'18',display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name='layers' size={16} color={C.yellow}/></div><div style={{fontFamily:F.ui,fontWeight:700,fontSize:12,color:C.yellow,textAlign:'center'}}>Brick</div></div></Card></div><div style={{display:'flex',gap:8,overflowX:'auto',paddingBottom:6,marginBottom:16,scrollbarWidth:'none'}}>{['all','run','bike','swim','strength','hike','other'].map(s=>{const meta=SPORT_META[s]||{color:C.muted,label:'All'};const sel=filter===s;const count=s==='all'?allWorkouts.length:allWorkouts.filter(w=>w.sport===s).length;return(<button key={s} onClick={()=>setFilter(s)} style={{flexShrink:0,padding:'7px 14px',borderRadius:20,background:sel?(s==='all'?C.text:meta.color+'18'):C.surface,border:`1.5px solid ${sel?(s==='all'?C.text:meta.color):C.border}`,color:sel?(s==='all'?C.bg:meta.color):C.muted,fontFamily:F.ui,fontSize:12,fontWeight:600,cursor:'pointer',transition:'all .15s',boxShadow:sel?S.sm:'none'}}>{s==='all'?`All (${count})`:`${meta.icon} ${meta.label}`}</button>);})}</div>{Object.keys(groups).length===0?<Card style={{textAlign:'center',padding:36}}><div style={{marginBottom:12}}><Icon name='chart' size={36} color={C.muted}/></div><div style={{fontFamily:F.display,fontSize:18,fontWeight:700,color:C.text,marginBottom:6}}>No workouts yet</div><div style={{fontFamily:F.ui,fontSize:14,color:C.subtle}}>Log manually or import from Apple Health</div></Card>:Object.entries(groups).map(([dateLabel,wos])=>(<div key={dateLabel}><div style={{fontFamily:F.ui,fontSize:12,fontWeight:700,color:C.muted,marginBottom:8,marginTop:6,textTransform:'uppercase',letterSpacing:'.06em'}}>{dateLabel}</div>{(()=>{const rendered=new Set();return wos.map((w,i)=>{
  if(rendered.has(w.id))return null;
  const brick=brickForWorkout(w.id);
  if(brick){
    const otherLeg=brick.legs.find(l=>l.workoutId!==w.id);
    const otherW=otherLeg?wos.find(x=>x.id===otherLeg.workoutId)||cardio.find(x=>x.id===otherLeg.workoutId):null;
    brick.legs.forEach(l=>rendered.add(l.workoutId));
    const legs=[w,otherW].filter(Boolean);
    const totalDur=legs.reduce((t,l)=>t+l.duration,0)+(brick.transitionTime||0);
    return(<Card key={'brick-'+brick.id} onClick={()=>setSelectedBrick(brick)} style={{marginBottom:8,padding:0,borderColor:C.yellow+'40',cursor:'pointer',overflow:'hidden'}}>
      <div style={{padding:'8px 14px',background:C.yellow+'08',display:'flex',alignItems:'center',gap:8,borderBottom:`1px solid ${C.yellow}20`}}>
        <Icon name='layers' size={14} color={C.yellow}/><span style={{fontFamily:F.ui,fontWeight:700,fontSize:12,color:C.yellow}}>Brick</span>
        {brick.transitionTime&&<span style={{fontFamily:F.mono,fontSize:11,color:C.muted}}>T: {brick.transitionTime}min</span>}
        <span style={{fontFamily:F.display,fontSize:16,fontWeight:700,color:C.text,marginLeft:'auto'}}>{fmtDur(totalDur)}</span>
      </div>
      {legs.map((leg,li)=>{const ls=SPORT_META[leg.sport]||SPORT_META.other;return(
        <div key={li} style={{display:'flex',alignItems:'center',gap:12,padding:'10px 14px',borderTop:li>0?`1px solid ${C.border}`:'none'}}>
          <SportBadge sport={leg.sport} small/><div style={{flex:1}}><div style={{fontFamily:F.ui,fontSize:14,color:C.text,fontWeight:500,overflow:'hidden',whiteSpace:'nowrap',textOverflow:'ellipsis'}}>{leg.notes||ls.label}</div></div>
          <span style={{fontFamily:F.mono,fontSize:13,color:C.muted}}>{fmtDur(leg.duration)}</span>
        </div>);})}
    </Card>);
  }
  return(<Card key={i} onClick={()=>setSelectedWorkout(w)} style={{marginBottom:8,padding:'13px 16px',cursor:'pointer'}}><div style={{display:'flex',alignItems:'center',gap:12}}><SportBadge sport={w.sport||'other'} small/><div style={{flex:1}}><div style={{fontFamily:F.ui,fontSize:15,color:C.text,fontWeight:500,overflow:'hidden',whiteSpace:'nowrap',textOverflow:'ellipsis'}}>{w.notes||'—'}</div><div style={{display:'flex',gap:6,marginTop:2}}>{w.source==='healthkit'&&<span style={{fontFamily:F.ui,fontSize:11,fontWeight:600,color:C.cyan}}>Apple Health</span>}</div></div><div style={{fontFamily:F.display,fontSize:22,fontWeight:700,color:C.text,flexShrink:0}}>{fmtDur(w.duration)}</div></div></Card>);
});})()}</div>))}{showLog&&<LogWorkoutSheet onSave={w=>{onAddCardio(w);setShowLog(false);}} onClose={()=>setShowLog(false)}/>}{showImport&&<HealthImportSheet onImport={ws=>{onImportHealth(ws);setShowImport(false);}} onClose={()=>setShowImport(false)} existingIds={existingIds}/>}{showBrickLink&&<LinkBrickSheet cardio={cardio} bricks={bricks||[]} onSave={b=>{onSaveBrick(b);setShowBrickLink(false);}} onClose={()=>setShowBrickLink(false)}/>}{selectedWorkout&&<WorkoutDetailSheet workout={selectedWorkout} onClose={()=>setSelectedWorkout(null)}/>}{selectedBrick&&<BrickDetailSheet brick={selectedBrick} cardio={cardio} onDelete={onDeleteBrick} onClose={()=>setSelectedBrick(null)}/>}</div>);
}

// ─── Knowledge Tab ─────────────────────────────────────────────────────────────
function KnowledgeTab(){const[articles,setArticles]=useState(()=>db.get('coach_knowledge',[]));const[query,setQuery]=useState('');const[loading,setLoading]=useState(false);const[selected,setSelected]=useState(null);const[followUp,setFollowUp]=useState('');const[fuLoading,setFuLoading]=useState(false);const[fuAnswer,setFuAnswer]=useState('');const research=async()=>{if(!query.trim()||loading)return;setLoading(true);try{const resp=await callAI({system:`Write a practical training knowledge article. Respond ONLY with JSON (no markdown): {"title":"title","summary":"2-3 sentence preview","keyPoints":["point 1","point 2","point 3"],"content":"Full article. 3-5 paragraphs. Plain text.","tags":["tag1","tag2"]}`,messages:[{role:'user',content:`Topic: ${query}\nPractical, evidence-based article for a serious recreational athlete.`}],max_tokens:1500});const raw=resp.content?.filter(b=>b.type==='text')?.map(b=>b.text)?.join('')||'';let parsed;try{parsed=JSON.parse(raw.replace(/```json\n?|\n?```/g,'').trim());}catch{parsed={title:query,summary:raw.slice(0,200),keyPoints:[],content:raw,tags:[]};}const article={id:uid(),query,...parsed,createdAt:todayStr()};const updated=[article,...articles].slice(0,50);setArticles(updated);db.set('coach_knowledge',updated);setSelected(article);setQuery('');toast.success(`"${article.title}" added`);}catch{toast.error('Research failed');}finally{setLoading(false);} };const deleteArticle=async id=>{const ok=await confirmDialog('Delete this article?','Cannot be undone.');if(!ok)return;const u=articles.filter(a=>a.id!==id);setArticles(u);db.set('coach_knowledge',u);if(selected?.id===id)setSelected(null);toast.info('Article deleted');};const askFollowUp=async()=>{if(!followUp.trim()||fuLoading||!selected)return;setFuLoading(true);setFuAnswer('');try{const resp=await callAI({system:`Answer a follow-up about this article:\n\n${selected.title}\n\n${selected.content}\n\nBe concise and practical. Plain text.`,messages:[{role:'user',content:followUp}],max_tokens:500});const text=resp.content?.filter(b=>b.type==='text')?.map(b=>b.text)?.join('')||'';setFuAnswer(text);setFollowUp('');}catch{toast.error('Failed to answer');}finally{setFuLoading(false);} };
if(selected)return(<div style={{paddingBottom:48}}><button onClick={()=>{setSelected(null);setFuAnswer('');}} style={{background:'none',border:'none',color:C.muted,fontFamily:F.ui,fontSize:14,fontWeight:500,cursor:'pointer',marginBottom:18,padding:0,display:'flex',alignItems:'center',gap:4}}><Icon name='arrowLeft' size={14} color={C.muted}/> Library</button><div style={{display:'flex',gap:7,flexWrap:'wrap',marginBottom:10}}>{selected.tags?.map(t=><Pill key={t} color={C.purple}>{t}</Pill>)}</div><div style={{fontFamily:F.display,fontSize:26,fontWeight:800,color:C.text,lineHeight:1.2,marginBottom:10,letterSpacing:'-.01em'}}>{selected.title}</div><div style={{fontFamily:F.ui,fontSize:15,color:C.subtle,lineHeight:1.8,marginBottom:16}}>{selected.summary}</div>{selected.keyPoints?.length>0&&<Card accent={C.purple} style={{marginBottom:16}}><Label style={{color:C.purple,marginBottom:10}}>Key points</Label>{selected.keyPoints.map((pt,i)=><div key={i} style={{display:'flex',gap:10,padding:'7px 0',borderTop:i>0?`1px solid ${C.border}`:'none'}}><span style={{color:C.purple,flexShrink:0,fontWeight:700}}>▸</span><span style={{fontFamily:F.ui,fontSize:15,lineHeight:1.65,color:C.text}}>{pt}</span></div>)}</Card>}<div style={{fontFamily:F.ui,fontSize:15,color:C.text,lineHeight:1.85,whiteSpace:'pre-wrap',marginBottom:24}}>{selected.content}</div><Card style={{marginBottom:16}}><Label style={{marginBottom:12}}>Ask a follow-up</Label>{fuAnswer&&<div style={{fontFamily:F.ui,fontSize:15,lineHeight:1.75,marginBottom:14,padding:'12px 14px',background:C.purple+'0A',borderRadius:10,border:`1px solid ${C.purple}30`,color:C.text}}>{fuAnswer}</div>}<div style={{display:'flex',gap:8}}><Inp placeholder="e.g. How often should I do this?" value={followUp} onChange={e=>setFollowUp(e.target.value)} onKeyDown={e=>e.key==='Enter'&&askFollowUp()} style={{flex:1}}/><button onClick={askFollowUp} disabled={fuLoading||!followUp.trim()} style={{width:48,height:48,background:fuLoading||!followUp.trim()?C.elevated:C.purple,border:'none',borderRadius:12,cursor:fuLoading||!followUp.trim()?'not-allowed':'pointer',color:fuLoading||!followUp.trim()?C.muted:'#fff',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>{fuLoading?<Spinner color="#fff" size={14}/>:'↑'}</button></div></Card><button onClick={()=>deleteArticle(selected.id)} style={{background:'none',border:`1.5px solid ${C.border}`,borderRadius:12,padding:'11px 16px',color:C.muted,fontFamily:F.ui,fontSize:13,fontWeight:500,cursor:'pointer',width:'100%',transition:'all .15s'}} onMouseEnter={e=>{e.currentTarget.style.borderColor=C.red;e.currentTarget.style.color=C.red;}} onMouseLeave={e=>{e.currentTarget.style.borderColor=C.border;e.currentTarget.style.color=C.muted;}}>Delete article</button></div>);
return(<div style={{paddingBottom:48}}><div style={{fontFamily:F.display,fontSize:22,fontWeight:800,color:C.text,marginBottom:4}}>Research a topic</div><div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,marginBottom:16,lineHeight:1.6}}>Ask anything — Zone 2, marathon nutrition, periodization, sleep, recovery.</div><div style={{display:'flex',gap:8,marginBottom:20}}><Inp placeholder="e.g. Zone 2 training for endurance…" value={query} onChange={e=>setQuery(e.target.value)} onKeyDown={e=>e.key==='Enter'&&research()} style={{flex:1}}/><button onClick={research} disabled={loading||!query.trim()} style={{width:50,height:50,background:loading||!query.trim()?C.elevated:C.purple,border:'none',borderRadius:12,cursor:loading||!query.trim()?'not-allowed':'pointer',color:loading||!query.trim()?C.muted:'#fff',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,transition:'all .2s'}}>{loading?<Spinner color="#fff" size={14}/>:<Icon name='search' size={18} color='#fff'/>}</button></div>{loading&&<Card style={{textAlign:'center',padding:32,borderColor:C.purple+'30',background:C.purple+'05'}}><div style={{display:'flex',justifyContent:'center',marginBottom:12}}><Spinner color={C.purple} size={22}/></div><div style={{fontFamily:F.ui,fontSize:15,color:C.subtle}}>Researching "{query}"…</div></Card>}{!loading&&articles.length===0&&<Card style={{textAlign:'center',padding:40}}><div style={{marginBottom:14}}><Icon name='book' size={40} color={C.purple}/></div><div style={{fontFamily:F.display,fontSize:20,fontWeight:700,color:C.text,marginBottom:8}}>Your knowledge library</div><div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,lineHeight:1.7}}>Research any training topic — saved forever.</div></Card>}{articles.length>0&&<><Label>{articles.length} article{articles.length>1?'s':''}</Label><div style={{display:'flex',flexDirection:'column',gap:10}}>{articles.map(a=><Card key={a.id} onClick={()=>{setSelected(a);setFuAnswer('');}} accent={C.purple}><div style={{display:'flex',gap:7,flexWrap:'wrap',marginBottom:8}}>{a.tags?.slice(0,3).map(t=><Pill key={t} color={C.purple} small>{t}</Pill>)}</div><div style={{fontFamily:F.display,fontSize:18,fontWeight:700,color:C.text,marginBottom:6,letterSpacing:'-.01em'}}>{a.title}</div><div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,lineHeight:1.65,display:'-webkit-box',WebkitLineClamp:2,WebkitBoxOrient:'vertical',overflow:'hidden'}}>{a.summary}</div><div style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginTop:10}}>{fmtDateSh(a.createdAt)}</div></Card>)}</div></>}</div>);}

// ─── AI Race Conditions Generator ─────────────────────────────────────────────
async function generateRaceConditions(event) {
  const p = presetById(event.presetId);
  const prompt = `You are an expert endurance sports analyst. Given the following race details, provide a brief conditions analysis. Be specific and actionable.

Race: ${event.name}
Type: ${p.label}
Location: ${event.location || 'Unknown'}
Date: ${event.date || 'Unknown'}

Respond with ONLY valid JSON in this exact format (no markdown, no code fences):
{
  "summary": "2-4 word summary like 'Hot, hilly, coastal'",
  "terrain": "1-2 sentences about the course terrain and elevation profile",
  "elevation": "Estimated elevation gain like '~800ft total gain' or 'Flat' if unknown say 'Check course map'",
  "climate": "1-2 sentences about expected weather conditions for this location and time of year",
  "tips": ["tip 1", "tip 2", "tip 3"]
}

For well-known races (Boston Marathon, Ironman Kona, etc.) include course-specific details. For lesser-known races, provide general analysis based on the location and time of year. Always provide 3-5 practical tips.`;

  try {
    const res = await callAI({
      system: 'You are a sports analyst. Respond with valid JSON only. No markdown code fences.',
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 512,
    });
    const text = res.content?.[0]?.text || '';
    const cleaned = text.replace(/```json\s*/g, '').replace(/```\s*/g, '').trim();
    const parsed = JSON.parse(cleaned);
    return { ...parsed, generatedAt: new Date().toISOString() };
  } catch (err) {
    console.error('AI conditions generation failed:', err);
    return null;
  }
}

// ─── Collapsible Section Component ────────────────────────────────────────────
function PlanSection({ icon, iconColor, title, hasContent, defaultOpen, children }) {
  const [open, setOpen] = useState(defaultOpen || false);
  return (
    <div style={{ marginBottom: 12 }}>
      <button onClick={() => setOpen(!open)} style={{
        width: '100%', display: 'flex', alignItems: 'center', gap: 10, padding: '13px 16px',
        background: C.card, border: `1.5px solid ${C.border}`, borderRadius: open ? '14px 14px 0 0' : 14,
        cursor: 'pointer', transition: 'all .15s',
      }}>
        <div style={{ width: 32, height: 32, borderRadius: 10, background: (iconColor || C.accent) + '18', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
          <Icon name={icon} size={16} color={iconColor || C.accent} />
        </div>
        <span style={{ flex: 1, fontFamily: F.ui, fontSize: 14, fontWeight: 700, color: C.text, textAlign: 'left' }}>{title}</span>
        {hasContent && !open && <div style={{ width: 8, height: 8, borderRadius: 4, background: C.green, flexShrink: 0 }} />}
        <Icon name={open ? 'chevUp' : 'chevDown'} size={16} color={C.muted} />
      </button>
      {open && (
        <div style={{ padding: '16px', background: C.card, border: `1.5px solid ${C.border}`, borderTop: 'none', borderRadius: '0 0 14px 14px' }}>
          {children}
        </div>
      )}
    </div>
  );
}

// ─── Event Modal ───────────────────────────────────────────────────────────────
function EventModal({event,onSave,onClose,onDelete}){
  const MODES=[{id:'goal',label:'Goal',icon:'target'},{id:'race',label:'Past Race',icon:'trophy'},{id:'pr',label:'PR',icon:'zap'}];
  const initMode=event?(event.mode||'goal'):'goal';
  const[mode,setMode]=useState(initMode);
  const[step,setStep]=useState(event?2:1);
  const[preset,setPreset]=useState(event?presetById(event.presetId):null);
  const[form,setForm]=useState(event?{name:event.name,date:event.date||'',location:event.location||'',goal:event.goal||'',stretchGoal:event.stretchGoal||'',baseline:event.baseline||'',url:event.url||'',result:event.result||'',placement:event.placement||'',bibNumber:event.bibNumber||'',ageGroup:event.ageGroup||'',genderPlacement:event.genderPlacement||'',ageGroupPlacement:event.ageGroupPlacement||'',splits:event.splits||{swim:'',t1:'',bike:'',t2:'',run:'',total:''}}:{name:'',date:'',location:'',goal:'',stretchGoal:'',baseline:'',url:'',result:'',placement:'',bibNumber:'',ageGroup:'',genderPlacement:'',ageGroupPlacement:'',splits:{swim:'',t1:'',bike:'',t2:'',run:'',total:''}});
  const upd=(k,v)=>setForm(f=>({...f,[k]:v}));
  const updSplit=(k,v)=>setForm(f=>({...f,splits:{...f.splits,[k]:v}}));
  const isTri=preset?.planType==='tri';

  const modeLabel=mode==='race'?'Past Race':mode==='pr'?'PR':'Goal';
  const sheetTitle=event?`Edit ${modeLabel.toLowerCase()}`:`Add ${mode==='pr'?'a':'a'} ${modeLabel.toLowerCase()}`;

  const handleSave=()=>{
    if(!form.name.trim())return;
    const ev={...(event||{}),id:event?.id||uid(),presetId:preset.id,mode,...form};
    if(mode==='race'&&isTri){
      ev.splits=form.splits;
      ev.result=form.splits.total||form.result;
    }
    if(mode==='race'||mode==='pr') ev.completed=true;
    onSave(ev);
  };

  const ModeSelector=()=>(<div style={{display:'flex',gap:6,marginBottom:18,background:C.elevated,borderRadius:12,padding:4}}>
    {MODES.map(m=><button key={m.id} onClick={()=>{if(event)return;setMode(m.id);}} style={{flex:1,padding:'9px 6px',borderRadius:10,border:'none',background:mode===m.id?C.surface:'transparent',boxShadow:mode===m.id?S.card:'none',fontFamily:F.ui,fontSize:13,fontWeight:mode===m.id?700:500,color:mode===m.id?C.text:C.muted,cursor:event?'default':'pointer',transition:'all .15s',display:'flex',alignItems:'center',justifyContent:'center',gap:5}}>
      <Icon name={m.icon} size={14} color={mode===m.id?C.accent:C.muted}/>{m.label}
    </button>)}
  </div>);

  return(<Sheet onClose={onClose} title={sheetTitle}>
    {!event&&<ModeSelector/>}
    {step===1&&<>
      <div style={{fontFamily:F.ui,fontSize:15,color:C.subtle,marginBottom:18}}>
        {mode==='goal'?'What are you working toward?':mode==='race'?'What race did you complete?':'What did you PR?'}
      </div>
      <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:8}}>
        {EVENT_PRESETS.map(p=><div key={p.id} onClick={()=>{setPreset(p);setForm(f=>({...f,name:p.label}));setStep(2);}} style={{background:C.elevated,border:`1.5px solid ${C.border}`,borderRadius:14,padding:'13px 14px',cursor:'pointer',display:'flex',alignItems:'center',gap:10,transition:'all .15s'}} onMouseEnter={e=>{e.currentTarget.style.borderColor=p.color;e.currentTarget.style.background=p.color+'10';}} onMouseLeave={e=>{e.currentTarget.style.borderColor=C.border;e.currentTarget.style.background=C.elevated;}}>
          <Icon name={p.icon} size={20} color={p.color}/><span style={{fontFamily:F.ui,fontWeight:600,fontSize:14,color:C.text}}>{p.label}</span>
        </div>)}
      </div>
    </>}
    {step===2&&preset&&<>
      <button onClick={()=>setStep(1)} style={{background:'none',border:'none',color:C.muted,fontFamily:F.ui,fontSize:13,fontWeight:500,cursor:'pointer',marginBottom:14,padding:0}}>← Change type</button>
      <div style={{display:'flex',alignItems:'center',gap:10,marginBottom:20,padding:'12px 16px',background:preset.color+'10',borderRadius:14,border:`1.5px solid ${preset.color}30`}}>
        <Icon name={preset.icon} size={20} color={preset.color}/>
        <span style={{fontFamily:F.ui,fontWeight:700,fontSize:15,color:preset.color}}>{preset.label}</span>
      </div>
      <div style={{display:'flex',flexDirection:'column',gap:12,marginBottom:20}}>
        <div><Label>Name *</Label><Inp placeholder={mode==='pr'?'e.g. Deadlift 1RM':'e.g. Boston Marathon'} value={form.name} onChange={e=>upd('name',e.target.value)}/></div>
        <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10}}>
          <div><Label>Date</Label><Inp type="date" value={form.date} onChange={e=>upd('date',e.target.value)}/></div>
          {mode!=='pr'&&<div><Label>Location</Label><Inp placeholder="City, State" value={form.location} onChange={e=>upd('location',e.target.value)}/></div>}
        </div>

        {mode==='goal'&&<>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10}}>
            <div><Label>{preset.goalLabel}</Label><Inp placeholder="e.g. 3:30" value={form.goal} onChange={e=>upd('goal',e.target.value)}/></div>
            <div><Label>Stretch goal</Label><Inp placeholder="e.g. 3:15" value={form.stretchGoal} onChange={e=>upd('stretchGoal',e.target.value)}/></div>
          </div>
          <div><Label>Current PR</Label><Inp placeholder="Your best so far" value={form.baseline} onChange={e=>upd('baseline',e.target.value)}/></div>
        </>}

        {mode==='race'&&!isTri&&<>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10}}>
            <div><Label>{preset.resultLabel||'Result'} *</Label><Inp placeholder="e.g. 3:28:15" value={form.result} onChange={e=>upd('result',e.target.value)}/></div>
            <div><Label>Goal was</Label><Inp placeholder="What you were aiming for" value={form.goal} onChange={e=>upd('goal',e.target.value)}/></div>
          </div>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10}}>
            <div><Label>Bib #</Label><Inp placeholder="e.g. 1465" value={form.bibNumber} onChange={e=>upd('bibNumber',e.target.value)}/></div>
            <div><Label>Age group</Label><Inp placeholder="e.g. M18-24" value={form.ageGroup} onChange={e=>upd('ageGroup',e.target.value)}/></div>
          </div>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr 1fr',gap:10}}>
            <div><Label>Overall</Label><Inp placeholder="e.g. 721st" value={form.placement} onChange={e=>upd('placement',e.target.value)}/></div>
            <div><Label>Gender</Label><Inp placeholder="e.g. 551st" value={form.genderPlacement} onChange={e=>upd('genderPlacement',e.target.value)}/></div>
            <div><Label>Age group</Label><Inp placeholder="e.g. 23rd" value={form.ageGroupPlacement} onChange={e=>upd('ageGroupPlacement',e.target.value)}/></div>
          </div>
        </>}

        {mode==='race'&&isTri&&<>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr 1fr',gap:10}}>
            <div><Label>Swim</Label><Inp placeholder="0:32:10" value={form.splits.swim} onChange={e=>updSplit('swim',e.target.value)}/></div>
            <div><Label>T1</Label><Inp placeholder="0:03:00" value={form.splits.t1} onChange={e=>updSplit('t1',e.target.value)}/></div>
            <div><Label>Bike</Label><Inp placeholder="2:45:00" value={form.splits.bike} onChange={e=>updSplit('bike',e.target.value)}/></div>
          </div>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr 1fr',gap:10}}>
            <div><Label>T2</Label><Inp placeholder="0:02:30" value={form.splits.t2} onChange={e=>updSplit('t2',e.target.value)}/></div>
            <div><Label>Run</Label><Inp placeholder="1:50:00" value={form.splits.run} onChange={e=>updSplit('run',e.target.value)}/></div>
            <div><Label>Total *</Label><Inp placeholder="5:12:40" value={form.splits.total} onChange={e=>updSplit('total',e.target.value)}/></div>
          </div>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10}}>
            <div><Label>Bib #</Label><Inp placeholder="e.g. 1465" value={form.bibNumber} onChange={e=>upd('bibNumber',e.target.value)}/></div>
            <div><Label>Age group</Label><Inp placeholder="e.g. M18-24" value={form.ageGroup} onChange={e=>upd('ageGroup',e.target.value)}/></div>
          </div>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr 1fr',gap:10}}>
            <div><Label>Overall</Label><Inp placeholder="e.g. 721st" value={form.placement} onChange={e=>upd('placement',e.target.value)}/></div>
            <div><Label>Gender</Label><Inp placeholder="e.g. 551st" value={form.genderPlacement} onChange={e=>upd('genderPlacement',e.target.value)}/></div>
            <div><Label>Age group</Label><Inp placeholder="e.g. 23rd" value={form.ageGroupPlacement} onChange={e=>upd('ageGroupPlacement',e.target.value)}/></div>
          </div>
          <div><Label>Goal was</Label><Inp placeholder="What you were aiming for" value={form.goal} onChange={e=>upd('goal',e.target.value)}/></div>
        </>}

        {mode==='pr'&&<>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10}}>
            <div><Label>{preset.resultLabel||'Result'} *</Label><Inp placeholder="e.g. 4:58 or 315 lbs" value={form.result} onChange={e=>upd('result',e.target.value)}/></div>
            <div><Label>Previous best</Label><Inp placeholder="Old PR" value={form.baseline} onChange={e=>upd('baseline',e.target.value)}/></div>
          </div>
        </>}

        <div><Label>Official race website (optional)</Label><Inp placeholder={mode==='race'?'e.g. results page or Strava link':'e.g. https://bostonmarathon.org'} value={form.url} onChange={e=>upd('url',e.target.value)} type="url"/></div>
      </div>
      <div style={{display:'flex',gap:10}}>
        {event&&<Btn onClick={async()=>{const ok=await confirmDialog('Delete this goal?','Your workout history will be kept.');if(ok)onDelete(event.id);}} outline style={{flex:1}}>Delete</Btn>}
        <Btn onClick={handleSave} color={preset.color} disabled={!form.name.trim()||(mode==='race'&&isTri&&!form.splits.total?.trim())||(mode!=='goal'&&!isTri&&!form.result?.trim())} style={{flex:2}}>
          {mode==='goal'?'Save goal':mode==='race'?'Save race':'Save PR'}
        </Btn>
      </div>
    </>}
  </Sheet>);
}

// ─── Goal Detail View ─────────────────────────────────────────────────────────
function GoalDetailView({event,onUpdate,onEdit,onDelete,onClose}){
  const p=presetById(event.presetId);
  const isTri=p.planType==='tri';
  const isRaceType=['run','tri','bike'].includes(p.planType);
  const days=event.date?daysUntil(event.date):null;
  const isPast=days!==null&&days<0;
  const[noteText,setNoteText]=useState('');
  const[showCompleteSplits,setShowCompleteSplits]=useState(false);
  const[completeSplits,setCompleteSplits]=useState(event.splits||{swim:'',t1:'',bike:'',t2:'',run:'',total:''});
  const[completeResult,setCompleteResult]=useState(event.result||'');
  const[completePlacement,setCompletePlacement]=useState(event.placement||'');
  const[completeGenderPlace,setCompleteGenderPlace]=useState(event.genderPlacement||'');
  const[completeAGPlace,setCompleteAGPlace]=useState(event.ageGroupPlacement||'');
  const[completeBib,setCompleteBib]=useState(event.bibNumber||'');
  const[completeAG,setCompleteAG]=useState(event.ageGroup||'');
  const[aiLoading,setAiLoading]=useState(false);
  const[weatherData,setWeatherData]=useState(event.weather||null);
  const[weatherLoading,setWeatherLoading]=useState(false);

  // Plan sections state
  const ps=event.planSections||{strategy:'',nutrition:{before:'',during:'',after:''},gear:'',travel:'',warmup:''};
  const[strategy,setStrategy]=useState(ps.strategy||event.racePlan||'');
  const[nutBefore,setNutBefore]=useState(ps.nutrition?.before||'');
  const[nutDuring,setNutDuring]=useState(ps.nutrition?.during||'');
  const[nutAfter,setNutAfter]=useState(ps.nutrition?.after||'');
  const[gear,setGear]=useState(ps.gear||'');
  const[travel,setTravel]=useState(ps.travel||'');
  const[warmup,setWarmup]=useState(ps.warmup||'');
  const[planDirty,setPlanDirty]=useState(false);
  const notes=event.notes||[];

  // Weather auto-fetch
  useEffect(()=>{
    if(!event.location||!event.date||!isRaceType) return;
    const d=daysUntil(event.date);
    if(d<0||d>16) return;
    // Throttle: only re-fetch if >6 hours old
    if(weatherData?.updatedAt){
      const age=Date.now()-new Date(weatherData.updatedAt).getTime();
      if(age<6*60*60*1000) return;
    }
    setWeatherLoading(true);
    fetch(`/api/weather?location=${encodeURIComponent(event.location)}&date=${event.date}`)
      .then(r=>r.ok?r.json():null)
      .then(data=>{
        if(data?.weather){
          const w={...data.weather,location:data.location,updatedAt:data.updatedAt};
          setWeatherData(w);
          onUpdate({...event,weather:w});
        }
      })
      .catch(()=>{})
      .finally(()=>setWeatherLoading(false));
  },[event.location,event.date]);

  const addNote=()=>{if(!noteText.trim())return;const n={id:uid(),text:noteText.trim(),date:todayStr()};onUpdate({...event,notes:[n,...notes]});setNoteText('');toast.success('Note added');};
  const deleteNote=async(nid)=>{const ok=await confirmDialog('Delete this note?','');if(!ok)return;onUpdate({...event,notes:notes.filter(n=>n.id!==nid)});};

  const savePlanSections=()=>{
    const updated={...event,racePlan:strategy,planSections:{strategy,nutrition:{before:nutBefore,during:nutDuring,after:nutAfter},gear,travel,warmup}};
    onUpdate(updated);setPlanDirty(false);toast.success('Race plan saved');
  };

  const regenerateConditions=async()=>{
    setAiLoading(true);
    const conditions=await generateRaceConditions(event);
    if(conditions){onUpdate({...event,aiConditions:conditions});toast.success('Conditions updated');}
    else toast.error('Failed to generate conditions');
    setAiLoading(false);
  };

  const toggleComplete=async()=>{
    if(event.completed){onUpdate({...event,completed:false,mode:event.mode==='race'?'goal':event.mode});toast.info('Marked as active');}
    else if(isTri){setShowCompleteSplits(true);}
    else{const ok=await confirmDialog('Mark as complete?','This will move it to your history.');if(ok){onUpdate({...event,completed:true});toast.success('Completed!');}}
  };
  const saveCompleteSplits=()=>{
    const updates={...event,completed:true,mode:'race',splits:completeSplits,result:isTri?(completeSplits.total||completeResult):completeResult};
    if(completePlacement)updates.placement=completePlacement;
    if(completeGenderPlace)updates.genderPlacement=completeGenderPlace;
    if(completeAGPlace)updates.ageGroupPlacement=completeAGPlace;
    if(completeBib)updates.bibNumber=completeBib;
    if(completeAG)updates.ageGroup=completeAG;
    onUpdate(updates);
    setShowCompleteSplits(false);
    toast.success('Completed!');
  };

  const ai=event.aiConditions;
  const wd=weatherData?.type==='forecast'?weatherData:null;
  const wdClimate=weatherData?.type==='climate'?weatherData:null;

  return(
    <div className="slide-in" style={{position:'fixed',inset:0,background:C.bg,zIndex:100,overflowY:'auto'}}>
      <div style={{background:C.bg+'F6',backdropFilter:'blur(20px)',borderBottom:`1px solid ${C.border}`,padding:'16px 20px',display:'flex',alignItems:'center',gap:12,position:'sticky',top:0,zIndex:10}}>
        <button onClick={onClose} style={{width:36,height:36,borderRadius:12,background:C.elevated,border:'none',color:C.subtle,fontSize:20,cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>←</button>
        <div style={{flex:1,fontFamily:F.display,fontSize:22,fontWeight:800,color:C.text,letterSpacing:'-.01em',overflow:'hidden',whiteSpace:'nowrap',textOverflow:'ellipsis'}}>{event.name}</div>
        <button onClick={()=>onEdit(event)} style={{background:C.elevated,border:'none',borderRadius:10,padding:'7px 14px',color:C.subtle,fontFamily:F.ui,fontSize:13,fontWeight:600,cursor:'pointer'}}>Edit</button>
      </div>

      <div style={{padding:'20px 16px 48px'}}>
        {/* Hero header */}
        <div style={{background:`linear-gradient(135deg,${p.color}15,${p.color}08)`,border:`1.5px solid ${p.color}30`,borderRadius:20,padding:'24px 20px',marginBottom:20,position:'relative',overflow:'hidden'}}>
          <div style={{position:'absolute',top:-30,right:-30,width:120,height:120,borderRadius:'50%',background:p.color+'15',pointerEvents:'none'}}/>
          <div style={{display:'flex',alignItems:'center',gap:8,marginBottom:12}}>
            <div style={{width:40,height:40,borderRadius:14,background:p.color+'25',display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name={p.icon} size={20} color={p.color}/></div>
            <div>
              <div style={{fontFamily:F.ui,fontSize:12,fontWeight:700,color:p.color,textTransform:'uppercase',letterSpacing:'.06em'}}>{p.label}</div>
              {event.location&&<div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:1}}>{event.location}</div>}
            </div>
          </div>
          <div style={{display:'flex',justifyContent:'space-between',alignItems:'flex-end'}}>
            <div>
              <div style={{fontFamily:F.display,fontSize:28,fontWeight:800,color:C.text,letterSpacing:'-.01em',lineHeight:1.1}}>{event.name}</div>
              {event.date&&<div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,marginTop:6}}>{new Date(event.date+'T12:00:00').toLocaleDateString('en-US',{weekday:'long',month:'long',day:'numeric',year:'numeric'})}</div>}
            </div>
            {days!==null&&<div style={{textAlign:'right'}}>
              <div style={{fontFamily:F.display,fontSize:48,fontWeight:800,color:event.completed?C.green:(isPast?C.muted:C.text),lineHeight:1}}>{event.completed?'✓':(isPast?0:days)}</div>
              <div style={{fontFamily:F.ui,fontSize:12,color:C.muted,fontWeight:500}}>{event.completed?'Done':(isPast?'Past':'days')}</div>
            </div>}
          </div>
        </div>

        {/* Race details */}
        {(event.bibNumber||event.ageGroup)&&<div style={{display:'flex',gap:8,marginBottom:16,flexWrap:'wrap'}}>
          {event.bibNumber&&<Pill color={C.subtle} small>Bib #{event.bibNumber}</Pill>}
          {event.ageGroup&&<Pill color={p.color} small>{event.ageGroup}</Pill>}
        </div>}

        {/* Result / Goal times */}
        {(event.result||event.goal||event.stretchGoal||event.baseline)&&<div style={{display:'grid',gridTemplateColumns:`repeat(${Math.min([event.result,event.goal,event.stretchGoal,event.baseline].filter(Boolean).length,3)},1fr)`,gap:10,marginBottom:20}}>
          {[{l:event.mode==='pr'?'PR':p.resultLabel||'Result',v:event.result,c:C.green},{l:'Goal',v:event.goal,c:p.color},{l:'Stretch',v:event.stretchGoal,c:C.yellow},{l:'Previous best',v:event.baseline,c:C.subtle}].map(({l,v,c})=>v?<Card key={l} style={{textAlign:'center',padding:'14px 8px'}}><div style={{fontFamily:F.display,fontSize:24,fontWeight:700,color:c,lineHeight:1}}>{v}</div><div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginTop:5,fontWeight:500}}>{l}</div></Card>:null)}
        </div>}

        {/* Placements */}
        {(event.placement||event.genderPlacement||event.ageGroupPlacement)&&<div style={{display:'grid',gridTemplateColumns:`repeat(${[event.placement,event.genderPlacement,event.ageGroupPlacement].filter(Boolean).length},1fr)`,gap:10,marginBottom:20}}>
          {[{l:'Overall',v:event.placement,c:C.cyan},{l:'Gender',v:event.genderPlacement,c:C.accent},{l:'Age group',v:event.ageGroupPlacement,c:C.green}].map(({l,v,c})=>v?<Card key={l} style={{textAlign:'center',padding:'14px 8px'}}><div style={{fontFamily:F.display,fontSize:24,fontWeight:700,color:c,lineHeight:1}}>{v}</div><div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginTop:5,fontWeight:500}}>{l}</div></Card>:null)}
        </div>}

        {/* Tri splits */}
        {event.splits&&Object.values(event.splits).some(v=>v)&&<div style={{marginBottom:20}}>
          <Label>Splits</Label>
          <div style={{display:'grid',gridTemplateColumns:'repeat(3,1fr)',gap:8}}>
            {[{l:'Swim',v:event.splits.swim,icon:'swim'},{l:'T1',v:event.splits.t1},{l:'Bike',v:event.splits.bike,icon:'bike'},{l:'T2',v:event.splits.t2},{l:'Run',v:event.splits.run,icon:'run'},{l:'Total',v:event.splits.total}].map(({l,v,icon})=>v?<Card key={l} style={{textAlign:'center',padding:'12px 6px'}}>
              {icon&&<div style={{marginBottom:4}}><Icon name={icon} size={14} color={p.color}/></div>}
              <div style={{fontFamily:F.display,fontSize:18,fontWeight:700,color:C.text,lineHeight:1}}>{v}</div>
              <div style={{fontFamily:F.ui,fontSize:10,color:C.muted,marginTop:4,fontWeight:600,textTransform:'uppercase',letterSpacing:'.05em'}}>{l}</div>
            </Card>:null)}
          </div>
        </div>}

        {/* Race website link */}
        {event.url&&<Card accent={C.cyan} style={{marginBottom:16}} onClick={()=>window.open(event.url,'_blank')}>
          <div style={{display:'flex',alignItems:'center',gap:10}}>
            <div style={{width:34,height:34,borderRadius:12,background:C.cyan+'18',display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name='link' size={16} color={C.cyan}/></div>
            <div style={{flex:1,overflow:'hidden'}}>
              <div style={{fontFamily:F.ui,fontWeight:600,fontSize:14,color:C.cyan}}>Official race website</div>
              <div style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginTop:1,overflow:'hidden',whiteSpace:'nowrap',textOverflow:'ellipsis'}}>{event.url.replace(/^https?:\/\//,'')}</div>
            </div>
            <span style={{color:C.cyan,fontSize:14}}>→</span>
          </div>
        </Card>}

        {/* ═══ RACE PLANNING HUB ═══ */}
        {isRaceType&&<div style={{marginBottom:8}}>
          <div style={{fontFamily:F.display,fontSize:18,fontWeight:800,color:C.text,marginBottom:14,letterSpacing:'-.01em'}}>Race Planning</div>

          {/* AI Race Conditions */}
          <PlanSection icon="sparkle" iconColor={C.yellow} title="Race Conditions" hasContent={!!ai} defaultOpen={!!ai||!!wd}>
            {ai?<>
              <div style={{display:'flex',alignItems:'center',gap:8,marginBottom:14}}>
                <Pill color={C.yellow}>{ai.summary}</Pill>
                <div style={{flex:1}}/>
                <button onClick={regenerateConditions} disabled={aiLoading} style={{background:'none',border:`1.5px solid ${C.border}`,borderRadius:8,padding:'5px 10px',fontSize:12,fontFamily:F.ui,fontWeight:600,color:C.muted,cursor:aiLoading?'not-allowed':'pointer',display:'flex',alignItems:'center',gap:4}}>
                  <Icon name='refresh' size={12} color={C.muted}/>{aiLoading?'Generating…':'Refresh'}
                </button>
              </div>
              <div style={{display:'grid',gap:12}}>
                {[{label:'Terrain',value:ai.terrain,icon:'mountain',color:C.accent},{label:'Elevation',value:ai.elevation,icon:'activity',color:C.green},{label:'Climate',value:ai.climate,icon:'thermometer',color:C.yellow}].map(({label,value,icon,color})=>value?<div key={label} style={{display:'flex',gap:10,alignItems:'flex-start'}}>
                  <div style={{width:28,height:28,borderRadius:8,background:color+'15',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,marginTop:1}}><Icon name={icon} size={14} color={color}/></div>
                  <div><div style={{fontFamily:F.ui,fontSize:11,fontWeight:700,color:C.muted,textTransform:'uppercase',letterSpacing:'.05em',marginBottom:3}}>{label}</div><div style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.6}}>{value}</div></div>
                </div>:null)}
              </div>
              {ai.tips?.length>0&&<div style={{marginTop:14,padding:'12px 14px',background:C.yellow+'0A',borderRadius:12,border:`1px solid ${C.yellow}20`}}>
                <div style={{fontFamily:F.ui,fontSize:11,fontWeight:700,color:C.yellow,textTransform:'uppercase',letterSpacing:'.05em',marginBottom:8}}>Tips</div>
                {ai.tips.map((tip,i)=><div key={i} style={{display:'flex',gap:8,padding:'4px 0'}}><span style={{color:C.yellow,flexShrink:0,fontWeight:700,fontSize:13}}>▸</span><span style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.5}}>{tip}</span></div>)}
              </div>}
              <div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginTop:10}}>AI-generated{ai.generatedAt?' · '+new Date(ai.generatedAt).toLocaleDateString():''}</div>
            </>:<div style={{textAlign:'center',padding:'12px 0'}}>
              <div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,marginBottom:10}}>
                {event.location?'Generate AI analysis of race conditions':'Add a location to generate race conditions'}
              </div>
              {event.location&&<Btn onClick={regenerateConditions} color={C.yellow} disabled={aiLoading} style={{padding:'10px 20px',fontSize:13}}>
                {aiLoading?'Generating…':'Generate Conditions'}
              </Btn>}
            </div>}
          </PlanSection>

          {/* Weather */}
          <PlanSection icon="cloud" iconColor={C.cyan} title="Weather" hasContent={!!wd} defaultOpen={!!wd}>
            {wd?<div>
              <div style={{display:'flex',alignItems:'center',gap:16,marginBottom:14}}>
                <div style={{textAlign:'center'}}>
                  <div style={{fontFamily:F.display,fontSize:42,fontWeight:800,color:C.text,lineHeight:1}}>{wd.tempHigh}°</div>
                  <div style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginTop:2}}>/{wd.tempLow}° low</div>
                </div>
                <div style={{flex:1}}>
                  <div style={{fontFamily:F.ui,fontSize:16,fontWeight:700,color:C.text,marginBottom:4}}>{wd.condition}</div>
                  <div style={{fontFamily:F.ui,fontSize:13,color:C.subtle}}>Feels like {wd.feelsLikeHigh}°/{wd.feelsLikeLow}°</div>
                </div>
              </div>
              <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10}}>
                <Card style={{padding:'12px 14px',display:'flex',alignItems:'center',gap:10}}>
                  <Icon name='wind' size={16} color={C.cyan}/><div><div style={{fontFamily:F.display,fontSize:18,fontWeight:700,color:C.text}}>{wd.windMax} mph</div><div style={{fontFamily:F.ui,fontSize:11,color:C.muted}}>Wind</div></div>
                </Card>
                <Card style={{padding:'12px 14px',display:'flex',alignItems:'center',gap:10}}>
                  <Icon name='droplets' size={16} color={C.cyan}/><div><div style={{fontFamily:F.display,fontSize:18,fontWeight:700,color:C.text}}>{wd.precipChance}%</div><div style={{fontFamily:F.ui,fontSize:11,color:C.muted}}>Rain chance</div></div>
                </Card>
              </div>
              {wd.location&&<div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginTop:10}}>{wd.location} · Updated {new Date(weatherData.updatedAt).toLocaleString()}</div>}
            </div>:weatherLoading?<div style={{textAlign:'center',padding:16}}><Spinner color={C.cyan} size={18}/><div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:8}}>Loading forecast…</div></div>
            :wdClimate?<div style={{textAlign:'center',padding:'12px 0'}}><Icon name='cloud' size={28} color={C.muted}/><div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,marginTop:8}}>{wdClimate.message}</div></div>
            :<div style={{textAlign:'center',padding:'12px 0'}}><Icon name='cloud' size={28} color={C.muted}/><div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,marginTop:8}}>{event.location&&event.date?(days>16?`Forecast available in ~${days-16} days`:'Weather data unavailable'):'Add a location and date for weather'}</div></div>}
          </PlanSection>

          {/* Strategy & Pacing */}
          <PlanSection icon="flag" iconColor={C.accent} title="Strategy & Pacing" hasContent={!!strategy}>
            <Textarea placeholder="Pacing plan, race approach, mile-by-mile strategy…" value={strategy} onChange={e=>{setStrategy(e.target.value);setPlanDirty(true);}} rows={4}/>
          </PlanSection>

          {/* Nutrition */}
          <PlanSection icon="utensils" iconColor={C.green} title="Nutrition" hasContent={!!(nutBefore||nutDuring||nutAfter)}>
            <div style={{display:'flex',flexDirection:'column',gap:14}}>
              <div><Label>Before (night before + morning of)</Label><Textarea placeholder="e.g. Pasta dinner, banana + toast + coffee morning of…" value={nutBefore} onChange={e=>{setNutBefore(e.target.value);setPlanDirty(true);}} rows={2}/></div>
              <div><Label>During race</Label><Textarea placeholder="e.g. Gel every 45min, electrolytes every aid station…" value={nutDuring} onChange={e=>{setNutDuring(e.target.value);setPlanDirty(true);}} rows={2}/></div>
              <div><Label>After (recovery)</Label><Textarea placeholder="e.g. Protein shake within 30min, full meal within 2hrs…" value={nutAfter} onChange={e=>{setNutAfter(e.target.value);setPlanDirty(true);}} rows={2}/></div>
            </div>
          </PlanSection>

          {/* Gear & Logistics */}
          <PlanSection icon="clipboard" iconColor={C.purple} title="Gear & Logistics" hasContent={!!(gear||travel)}>
            <div style={{display:'flex',flexDirection:'column',gap:14}}>
              <div><Label>Gear checklist</Label><Textarea placeholder="Race kit, shoes, watch, sunscreen, body glide…" value={gear} onChange={e=>{setGear(e.target.value);setPlanDirty(true);}} rows={3}/></div>
              <div><Label>Travel & logistics</Label><Textarea placeholder="Parking, packet pickup, hotel, transportation…" value={travel} onChange={e=>{setTravel(e.target.value);setPlanDirty(true);}} rows={3}/></div>
            </div>
          </PlanSection>

          {/* Warmup */}
          <PlanSection icon="activity" iconColor={C.accent} title="Warmup Routine" hasContent={!!warmup}>
            <Textarea placeholder="Pre-race warmup: jog, drills, strides, stretching…" value={warmup} onChange={e=>{setWarmup(e.target.value);setPlanDirty(true);}} rows={3}/>
          </PlanSection>

          {/* Save plan button */}
          {planDirty&&<Btn onClick={savePlanSections} color={p.color} style={{width:'100%',marginBottom:16,padding:13,fontSize:14}}>Save race plan</Btn>}
        </div>}

        {/* Non-race type: keep simple race plan textarea */}
        {!isRaceType&&<div style={{marginBottom:24}}>
          <Label>Plan</Label>
          <Textarea placeholder="Strategy, goals, notes…" value={strategy} onChange={e=>{setStrategy(e.target.value);setPlanDirty(true);}} rows={5}/>
          {planDirty&&<Btn onClick={()=>{onUpdate({...event,racePlan:strategy,planSections:{...ps,strategy}});setPlanDirty(false);toast.success('Plan saved');}} color={p.color} style={{width:'100%',marginTop:10,padding:12,fontSize:14}}>Save plan</Btn>}
        </div>}

        {/* Notes */}
        <div style={{marginBottom:24}}>
          <Label>Notes</Label>
          <div style={{display:'flex',gap:8,marginBottom:12}}>
            <Inp placeholder="Add a note…" value={noteText} onChange={e=>setNoteText(e.target.value)} onKeyDown={e=>e.key==='Enter'&&addNote()} style={{flex:1}}/>
            <button onClick={addNote} disabled={!noteText.trim()} style={{width:48,height:48,background:!noteText.trim()?C.elevated:p.color,border:'none',borderRadius:12,cursor:!noteText.trim()?'not-allowed':'pointer',color:!noteText.trim()?C.muted:'#fff',fontSize:18,display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,transition:'all .15s'}}>+</button>
          </div>
          {notes.length===0?<Card style={{padding:20,textAlign:'center'}}><div style={{fontFamily:F.ui,fontSize:14,color:C.muted}}>No notes yet — add training insights, logistics, or anything relevant.</div></Card>
          :notes.map(n=><Card key={n.id} style={{marginBottom:8,padding:'13px 16px'}}>
            <div style={{display:'flex',justifyContent:'space-between',alignItems:'flex-start',gap:10}}>
              <div style={{flex:1}}>
                <div style={{fontFamily:F.ui,fontSize:15,color:C.text,lineHeight:1.65,whiteSpace:'pre-wrap'}}>{n.text}</div>
                <div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginTop:6}}>{fmtDateSh(n.date)}</div>
              </div>
              <button onClick={()=>deleteNote(n.id)} style={{background:'none',border:'none',color:C.muted,fontSize:14,cursor:'pointer',padding:4,flexShrink:0,opacity:0.6}} onMouseEnter={e=>e.currentTarget.style.opacity=1} onMouseLeave={e=>e.currentTarget.style.opacity=0.6}>✕</button>
            </div>
          </Card>)}
        </div>

        {/* Actions */}
        <div style={{display:'flex',gap:10}}>
          <Btn onClick={toggleComplete} color={event.completed?C.muted:C.green} outline={event.completed} style={{flex:1,fontSize:14,padding:13}}>{event.completed?'Reopen':'Mark complete ✓'}</Btn>
          <Btn onClick={async()=>{const ok=await confirmDialog('Delete this goal?','Your workout history will be kept.');if(ok){onDelete(event.id);onClose();}}} outline style={{flex:1,fontSize:14,padding:13,borderColor:C.red+'50',color:C.red}}>Delete</Btn>
        </div>
      </div>

      {showCompleteSplits&&<Sheet onClose={()=>setShowCompleteSplits(false)} title="Race Results">
        <div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,marginBottom:18}}>Enter your race splits and results.</div>
        <div style={{display:'flex',flexDirection:'column',gap:12,marginBottom:20}}>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr 1fr',gap:10}}>
            <div><Label>Swim</Label><Inp placeholder="0:32:10" value={completeSplits.swim} onChange={e=>setCompleteSplits(s=>({...s,swim:e.target.value}))}/></div>
            <div><Label>T1</Label><Inp placeholder="0:03:00" value={completeSplits.t1} onChange={e=>setCompleteSplits(s=>({...s,t1:e.target.value}))}/></div>
            <div><Label>Bike</Label><Inp placeholder="2:45:00" value={completeSplits.bike} onChange={e=>setCompleteSplits(s=>({...s,bike:e.target.value}))}/></div>
          </div>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr 1fr',gap:10}}>
            <div><Label>T2</Label><Inp placeholder="0:02:30" value={completeSplits.t2} onChange={e=>setCompleteSplits(s=>({...s,t2:e.target.value}))}/></div>
            <div><Label>Run</Label><Inp placeholder="1:50:00" value={completeSplits.run} onChange={e=>setCompleteSplits(s=>({...s,run:e.target.value}))}/></div>
            <div><Label>Total *</Label><Inp placeholder="5:12:40" value={completeSplits.total} onChange={e=>setCompleteSplits(s=>({...s,total:e.target.value}))}/></div>
          </div>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10}}>
            <div><Label>Bib #</Label><Inp placeholder="e.g. 1465" value={completeBib} onChange={e=>setCompleteBib(e.target.value)}/></div>
            <div><Label>Age group</Label><Inp placeholder="e.g. M18-24" value={completeAG} onChange={e=>setCompleteAG(e.target.value)}/></div>
          </div>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr 1fr',gap:10}}>
            <div><Label>Overall</Label><Inp placeholder="e.g. 721st" value={completePlacement} onChange={e=>setCompletePlacement(e.target.value)}/></div>
            <div><Label>Gender</Label><Inp placeholder="e.g. 551st" value={completeGenderPlace} onChange={e=>setCompleteGenderPlace(e.target.value)}/></div>
            <div><Label>Age group</Label><Inp placeholder="e.g. 23rd" value={completeAGPlace} onChange={e=>setCompleteAGPlace(e.target.value)}/></div>
          </div>
        </div>
        <div style={{display:'flex',gap:10}}>
          <Btn onClick={()=>setShowCompleteSplits(false)} outline style={{flex:1}}>Cancel</Btn>
          <Btn onClick={saveCompleteSplits} color={C.green} disabled={!completeSplits.total?.trim()} style={{flex:2}}>Complete race ✓</Btn>
        </div>
      </Sheet>}
    </div>
  );
}

// ─── Goals Tab ────────────────────────────────────────────────────────────────
function GoalsTab({events,onViewGoal,onAddEvent}){
  const upcoming=events.filter(e=>!e.completed).sort((a,b)=>(a.date||'9999').localeCompare(b.date||'9999'));
  const pastRaces=events.filter(e=>e.completed&&e.mode==='race').sort((a,b)=>(b.date||'').localeCompare(a.date||''));
  const prs=events.filter(e=>e.completed&&e.mode==='pr').sort((a,b)=>(b.date||'').localeCompare(a.date||''));
  const completed=events.filter(e=>e.completed&&e.mode!=='race'&&e.mode!=='pr').sort((a,b)=>(b.date||'').localeCompare(a.date||''));

  const GoalRow=({e})=>{const p=presetById(e.presetId);const days=e.date?daysUntil(e.date):null;const isRace=e.mode==='race';const isPR=e.mode==='pr';return(
    <Card onClick={()=>onViewGoal(e)} style={{marginBottom:10,padding:'16px 18px'}}>
      <div style={{display:'flex',alignItems:'center',gap:14}}>
        <div style={{width:46,height:46,borderRadius:16,background:p.color+'20',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}><Icon name={isRace?'trophy':isPR?'zap':p.icon} size={22} color={p.color}/></div>
        <div style={{flex:1,overflow:'hidden'}}>
          <div style={{fontFamily:F.ui,fontWeight:700,fontSize:16,color:e.completed&&!isRace&&!isPR?C.muted:C.text,overflow:'hidden',whiteSpace:'nowrap',textOverflow:'ellipsis'}}>{e.name}</div>
          <div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:3}}>{e.location||p.label}{e.date?` · ${fmtDateSh(e.date)}`:''}</div>
          {e.goal&&!e.completed&&<div style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:p.color,marginTop:4}}>Goal: {e.goal}{e.stretchGoal?` · Stretch: ${e.stretchGoal}`:''}</div>}
          {e.result&&<div style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:p.color,marginTop:4}}>{isPR?'PR':'Result'}: {e.result}{e.placement?` · ${e.placement}`:''}</div>}
        </div>
        {days!==null&&!e.completed&&<div style={{textAlign:'right',flexShrink:0}}>
          <div style={{fontFamily:F.display,fontSize:28,fontWeight:700,color:days<0?C.muted:C.text,lineHeight:1}}>{days<0?'—':days}</div>
          <div style={{fontFamily:F.ui,fontSize:10,color:C.muted}}>days</div>
        </div>}
        {e.completed&&!isRace&&!isPR&&<Pill color={C.green} small>Done</Pill>}
        {isRace&&<Pill color={p.color} small>Race</Pill>}
        {isPR&&<Pill color={C.green} small>PR</Pill>}
      </div>
      {(e.notes?.length>0||e.racePlan)&&<div style={{display:'flex',gap:8,marginTop:10,flexWrap:'wrap'}}>
        {e.notes?.length>0&&<Pill color={C.subtle} small>{e.notes.length} note{e.notes.length>1?'s':''}</Pill>}
        {e.racePlan&&<Pill color={C.purple} small>Plan</Pill>}
        {e.url&&<Pill color={C.cyan} small>Link</Pill>}
      </div>}
    </Card>
  );};

  return(<div style={{paddingBottom:80}}>
    <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:16}}>
      <div><div style={{fontFamily:F.display,fontSize:24,fontWeight:800,color:C.text}}>Goals & Races</div><div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:2}}>{upcoming.length} active{pastRaces.length>0?` · ${pastRaces.length} race${pastRaces.length>1?'s':''}`:''}{prs.length>0?` · ${prs.length} PR${prs.length>1?'s':''}`:''}{completed.length>0?` · ${completed.length} completed`:''}</div></div>
      <Btn onClick={onAddEvent} color={C.accent} style={{padding:'10px 18px',fontSize:14}}>+ Add</Btn>
    </div>

    {upcoming.length===0&&pastRaces.length===0&&prs.length===0&&completed.length===0&&<Card onClick={onAddEvent} accent={C.accent} style={{textAlign:'center',padding:36,marginBottom:16}}><div style={{marginBottom:10}}><Icon name='target' size={32} color={C.accent}/></div><div style={{fontFamily:F.display,fontSize:20,fontWeight:700,color:C.accent,marginBottom:6}}>Add your first goal</div><div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,lineHeight:1.6}}>Goals, past races, PRs — track your full history.</div></Card>}

    {upcoming.length>0&&<><Label>Upcoming</Label>{upcoming.map(e=><GoalRow key={e.id} e={e}/>)}</>}
    {pastRaces.length>0&&<div style={{marginTop:upcoming.length?24:0}}><Label>Race History</Label>{pastRaces.map(e=><GoalRow key={e.id} e={e}/>)}</div>}
    {prs.length>0&&<div style={{marginTop:(upcoming.length||pastRaces.length)?24:0}}><Label>Personal Records</Label>{prs.map(e=><GoalRow key={e.id} e={e}/>)}</div>}
    {completed.length>0&&<div style={{marginTop:(upcoming.length||pastRaces.length||prs.length)?24:0}}><Label>Completed Goals</Label>{completed.map(e=><GoalRow key={e.id} e={e}/>)}</div>}
  </div>);
}

// ─── Home Tab ──────────────────────────────────────────────────────────────────
function HomeTab({events,cardio,strength,pushMessage,pushLoading,personality,onRefreshPush,onAddEvent,onViewGoal,onViewAllGoals,onLog,onChat,setTab,onStartStrength,plan,trainingPlan}){
  const active=events.filter(e=>!e.completed);const completed=events.filter(e=>e.completed);const now=new Date();const ws=new Date(now);ws.setDate(now.getDate()-now.getDay());
  const thisWeekC=cardio.filter(w=>new Date(w.date+'T12:00:00')>=ws);const thisWeekS=strength.filter(s=>new Date(s.date+'T12:00:00')>=ws);
  const allRecent=[...cardio.map(w=>({...w,kind:'cardio'})),...strength.map(s=>({...s,sport:'strength',kind:'strength'}))].sort((a,b)=>b.date.localeCompare(a.date)).slice(0,4);
  const hasWorkouts=cardio.length+strength.length>0;
  return(<div style={{paddingBottom:80}}>
    <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:10}}>
      <Label style={{marginBottom:0}}>Training for</Label>
      {events.length>0&&<button onClick={onViewAllGoals} style={{background:'none',border:'none',fontFamily:F.ui,fontSize:13,fontWeight:600,color:C.accent,cursor:'pointer',padding:0}}>All goals{completed.length>0?` (${completed.length} past)`:''} →</button>}
    </div>
    {active.length===0?<Card onClick={onAddEvent} accent={C.accent} style={{marginBottom:16,textAlign:'center',padding:28}}><div style={{marginBottom:8}}><Icon name='target' size={28} color={C.accent}/></div><div style={{fontFamily:F.display,fontSize:18,fontWeight:700,color:C.accent,marginBottom:4}}>Add your first goal</div><div style={{fontFamily:F.ui,fontSize:14,color:C.subtle}}>Marathon, lifting PR, triathlon…</div></Card>
    :<div style={{display:'flex',gap:12,overflowX:'auto',paddingBottom:8,marginBottom:16,scrollbarWidth:'none',msOverflowStyle:'none'}}>
      {active.map(e=>{const p=presetById(e.presetId);const days=e.date?daysUntil(e.date):null;const isPast=days!==null&&days<0;return(<div key={e.id} onClick={()=>onViewGoal(e)} style={{flexShrink:0,width:190,borderRadius:18,background:C.surface,border:`1.5px solid ${p.color}30`,padding:'16px',boxShadow:S.card,position:'relative',overflow:'hidden',cursor:'pointer',transition:'all .15s'}} onMouseEnter={x=>{x.currentTarget.style.transform='translateY(-2px)';x.currentTarget.style.boxShadow=S.md;}} onMouseLeave={x=>{x.currentTarget.style.transform='none';x.currentTarget.style.boxShadow=S.card;}}><div style={{position:'absolute',top:-20,right:-20,width:80,height:80,borderRadius:'50%',background:p.color+'18',pointerEvents:'none'}}/><div style={{display:'flex',alignItems:'center',gap:6,marginBottom:8}}><Icon name={p.icon} size={14} color={p.color}/><span style={{fontFamily:F.ui,fontSize:11,fontWeight:700,color:p.color,textTransform:'uppercase',letterSpacing:'.06em'}}>{p.label}</span></div><div style={{fontFamily:F.display,fontSize:17,fontWeight:700,lineHeight:1.2,marginBottom:4,letterSpacing:'-.01em',color:C.text}}>{e.name}</div>{e.location&&<div style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginBottom:8}}>{e.location}</div>}<div style={{display:'flex',justifyContent:'space-between',alignItems:'flex-end'}}><div>{e.goal&&<div style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:p.color}}>Goal: {e.goal}</div>}</div>{days!==null?<div style={{textAlign:'right'}}><div style={{fontFamily:F.display,fontSize:30,fontWeight:800,color:isPast?C.muted:C.text,lineHeight:1}}>{isPast?'Done':days}</div><div style={{fontFamily:F.ui,fontSize:11,color:C.muted,fontWeight:500}}>{isPast?e.date:'days'}</div></div>:<div style={{fontFamily:F.ui,fontSize:12,color:C.muted}}>Ongoing</div>}</div></div>);})}
      <div onClick={onAddEvent} style={{flexShrink:0,width:72,borderRadius:18,border:`2px dashed ${C.border}`,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',gap:6,cursor:'pointer',transition:'all .15s',background:C.surface}} onMouseEnter={e=>{e.currentTarget.style.borderColor=C.accent;e.currentTarget.style.background=C.accent+'06';}} onMouseLeave={e=>{e.currentTarget.style.borderColor=C.border;e.currentTarget.style.background=C.surface;}}><Icon name='plus' size={20} color={C.muted}/><span style={{fontFamily:F.ui,fontSize:10,fontWeight:600,color:C.muted,textTransform:'uppercase',textAlign:'center',lineHeight:1.3}}>Add</span></div>
    </div>}
    {trainingPlan&&<Card style={{marginBottom:16,padding:'12px 16px',borderColor:C.accent+'25'}}>
      <div style={{display:'flex',alignItems:'center',gap:10}}>
        <div style={{width:32,height:32,borderRadius:10,background:C.accent+'15',display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name='calendar' size={16} color={C.accent}/></div>
        <div style={{flex:1}}>
          <div style={{fontFamily:F.ui,fontWeight:600,fontSize:13,color:C.text}}>Week {trainingPlan.currentWeek}/{trainingPlan.totalWeeks}</div>
          <div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginTop:1}}>Phase {trainingPlan.currentPhase}: {trainingPlan.phases?.find(p=>p.number===trainingPlan.currentPhase)?.name||'—'}</div>
        </div>
        <button onClick={()=>setTab('plan')} style={{background:C.elevated,border:`1px solid ${C.border}`,borderRadius:8,padding:'5px 12px',fontFamily:F.ui,fontSize:11,fontWeight:600,color:C.accent,cursor:'pointer'}}>View plan →</button>
      </div>
    </Card>}
    {(plan.length>0||trainingPlan?.weeklyPlans?.[String(trainingPlan?.currentWeek)])&&<TodaySessionCard plan={plan} cardio={cardio} strength={strength} onStartStrength={onStartStrength} setTab={setTab} trainingPlan={trainingPlan}/>}
    <PushMessageCard message={pushMessage} personality={personality} loading={pushLoading} onRefresh={onRefreshPush} hasWorkouts={hasWorkouts}/>
    <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10,marginBottom:16}}>
      <Card><Label>This week</Label><div style={{fontFamily:F.display,fontSize:44,fontWeight:800,lineHeight:1,color:C.text}}>{thisWeekC.length+thisWeekS.length}</div><div style={{fontFamily:F.ui,fontSize:13,fontWeight:500,color:C.muted,marginTop:3}}>sessions</div><div style={{display:'flex',gap:6,marginTop:10,flexWrap:'wrap'}}>{thisWeekS.length>0&&<SportBadge sport="strength" small/>}{[...new Set(thisWeekC.map(w=>w.sport))].map(s=><SportBadge key={s} sport={s} small/>)}{thisWeekC.length+thisWeekS.length===0&&<span style={{fontFamily:F.ui,fontSize:12,color:C.muted}}>None yet</span>}</div></Card>
      <Card><Label>All time</Label><div style={{fontFamily:F.display,fontSize:44,fontWeight:800,lineHeight:1,color:C.text}}>{cardio.length+strength.length}</div><div style={{fontFamily:F.ui,fontSize:13,fontWeight:500,color:C.muted,marginTop:3}}>sessions</div><div style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginTop:6}}>{strength.length} strength · {cardio.length} cardio</div></Card>
    </div>
    <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10,marginBottom:16}}>
      <Card onClick={onLog} accent={C.accent}><div style={{display:'flex',alignItems:'center',gap:10}}><div style={{width:36,height:36,borderRadius:12,background:C.accent+'18',display:'flex',alignItems:'center',justifyContent:'center',}}><Icon name='zap' size={17} color={C.accent}/></div><div><div style={{fontFamily:F.ui,fontWeight:700,fontSize:14,color:C.accent}}>Log workout</div><div style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginTop:1}}>Any activity</div></div></div></Card>
      <Card onClick={onChat} accent={C.cyan}><div style={{display:'flex',alignItems:'center',gap:10}}><div style={{width:36,height:36,borderRadius:12,background:C.cyan+'18',display:'flex',alignItems:'center',justifyContent:'center',}}><Icon name='message' size={17} color={C.cyan}/></div><div><div style={{fontFamily:F.ui,fontWeight:700,fontSize:14,color:C.cyan}}>Ask coach</div><div style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginTop:1}}>AI logs it</div></div></div></Card>
    </div>
    <Label>Recent activity</Label>
    {allRecent.length===0?<Card style={{textAlign:'center',padding:28}}><div style={{fontFamily:F.ui,fontSize:15,color:C.muted}}>No sessions yet — add a goal and start training</div></Card>:allRecent.map((w,i)=>(<Card key={i} style={{marginBottom:8,padding:'13px 16px'}}><div style={{display:'flex',alignItems:'center',gap:12}}><SportBadge sport={w.sport||'strength'} small/><div style={{flex:1,fontFamily:F.ui,fontSize:14,color:C.subtle,fontWeight:500,overflow:'hidden',whiteSpace:'nowrap',textOverflow:'ellipsis'}}>{w.notes||(w.kind==='strength'?`${w.exercises?.reduce((t,e)=>t+(e.sets?.length||0),0)||0} sets`:'—')}</div><div style={{textAlign:'right',flexShrink:0}}><div style={{fontFamily:F.display,fontSize:22,fontWeight:700,color:C.text}}>{fmtDur(w.duration)}</div><div style={{fontFamily:F.ui,fontSize:11,color:C.muted,fontWeight:500}}>{fmtDateSh(w.date)}</div></div></div></Card>))}
  </div>);}

// ─── Chat Tab ──────────────────────────────────────────────────────────────────
function ChatTab({messages,onSend,loading,isStreaming,streamText,personality}){
  const[input,setInput]=useState('');const bottomRef=useRef(null);const inputRef=useRef(null);
  const p=PERSONALITIES[personality]||PERSONALITIES.normal;
  useEffect(()=>{bottomRef.current?.scrollIntoView({behavior:'smooth'});},[messages,loading,streamText]);
  const send=()=>{const t=input.trim();if(!t||loading||isStreaming)return;onSend(t);setInput('');inputRef.current?.focus();};
  const suggestions=["I just ran 45 min easy at 10:30/mi","Finished a 90 min Zone 2 ride","How am I doing this week?","What should I focus on?"];
  const isDisabled=loading||isStreaming||!input.trim();
  return(<div style={{display:'flex',flexDirection:'column',height:'calc(100svh - 180px)',minHeight:400}}>
    {messages.length===0&&!isStreaming&&<div style={{marginBottom:16}}><Card style={{marginBottom:12,borderColor:p.color+'30',background:p.color+'07'}}><div style={{display:'flex',alignItems:'center',gap:10,marginBottom:8}}><div style={{width:32,height:32,borderRadius:10,background:p.color+'20',display:'flex',alignItems:'center',justifyContent:'center',}}><Icon name={p.icon} size={18} color={p.color}/></div><div><div style={{fontFamily:F.ui,fontWeight:700,fontSize:14,color:p.color}}>{p.name}</div><div style={{fontFamily:F.ui,fontSize:12,color:C.muted}}>Online · ready to coach</div></div></div><div style={{fontFamily:F.ui,fontSize:15,color:C.subtle,lineHeight:1.7}}>Tell me about a workout and I'll log it. Ask anything about your training.</div></Card>{suggestions.map((s,i)=><button key={i} onClick={()=>onSend(s)} style={{width:'100%',background:C.surface,border:`1.5px solid ${C.border}`,borderRadius:14,padding:'12px 16px',color:C.subtle,fontFamily:F.ui,fontSize:14,fontWeight:500,textAlign:'left',cursor:'pointer',marginBottom:8,transition:'all .15s',boxShadow:S.sm,lineHeight:1.5}} onMouseEnter={e=>{e.currentTarget.style.color=C.text;e.currentTarget.style.borderColor=C.borderBright;e.currentTarget.style.boxShadow=S.md;}} onMouseLeave={e=>{e.currentTarget.style.color=C.subtle;e.currentTarget.style.borderColor=C.border;e.currentTarget.style.boxShadow=S.sm;}}>{s}</button>)}</div>}
    <div style={{flex:1,overflowY:'auto',display:'flex',flexDirection:'column',gap:10,paddingRight:2}}>
      {messages.map((m,i)=>(<div key={i} className="fade-up" style={{display:'flex',justifyContent:m.role==='user'?'flex-end':'flex-start'}}><div style={{maxWidth:'85%',padding:'13px 16px',lineHeight:1.7,borderRadius:m.role==='user'?'20px 20px 6px 20px':'6px 20px 20px 20px',background:m.role==='user'?C.accent:C.surface,boxShadow:m.role==='assistant'?S.card:'none',fontFamily:F.ui,fontSize:15,color:m.role==='user'?'#fff':C.text,whiteSpace:m.role==='user'?'pre-wrap':'normal',border:m.role==='assistant'?`1.5px solid ${C.border}`:'none'}}>{m.role==='assistant'?renderMd(m.content):m.content}{m.logged&&<div style={{marginTop:10,padding:'8px 12px',background:C.green+'15',borderRadius:10,display:'flex',alignItems:'center',gap:7}}><span style={{color:C.green,fontSize:14,fontWeight:700}}>✓</span><span style={{fontFamily:F.ui,fontSize:13,fontWeight:600,color:C.green}}>Workout logged</span></div>}{m.nutritionLogged&&<div style={{marginTop:10,padding:'8px 12px',background:C.cyan+'15',borderRadius:10,display:'flex',alignItems:'center',gap:7}}><Icon name='zap' size={14} color={C.cyan}/><span style={{fontFamily:F.ui,fontSize:13,fontWeight:600,color:C.cyan}}>Nutrition logged</span></div>}{m.planChanged&&<div style={{marginTop:10,padding:'8px 12px',background:C.accent+'15',borderRadius:10,display:'flex',alignItems:'center',gap:7}}><Icon name='calendar' size={14} color={C.accent}/><span style={{fontFamily:F.ui,fontSize:13,fontWeight:600,color:C.accent}}>Training plan updated</span></div>}</div></div>))}
      {isStreaming&&<div className="fade-up" style={{display:'flex',justifyContent:'flex-start'}}><div className={streamText?'fade-up':'streaming-cursor'} style={{maxWidth:'85%',padding:'13px 16px',lineHeight:1.7,borderRadius:'6px 20px 20px 20px',background:C.surface,boxShadow:S.card,fontFamily:F.ui,fontSize:15,color:C.text,border:`1.5px solid ${C.border}`}}>{streamText?renderMd(streamText):<DotsLoader color={p.color}/>}</div></div>}
      {loading&&!isStreaming&&<div className="fade-up" style={{display:'flex'}}><div style={{padding:'14px 18px',borderRadius:'6px 20px 20px 20px',background:C.surface,boxShadow:S.card,border:`1.5px solid ${C.border}`}}><DotsLoader color={p.color}/><div style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginTop:6}}>Reviewing your training…</div></div></div>}
      <div ref={bottomRef}/>
    </div>
    <div style={{paddingTop:12,display:'flex',gap:8}}>
      <input ref={inputRef} value={input} onChange={e=>setInput(e.target.value)} onKeyDown={e=>e.key==='Enter'&&!e.shiftKey&&(e.preventDefault(),send())} placeholder="Talk to your coach…" style={{flex:1,background:C.surface,border:`1.5px solid ${C.border}`,borderRadius:16,padding:'14px 18px',color:C.text,fontFamily:F.ui,fontSize:15,outline:'none',transition:'all .15s',boxShadow:S.sm}} onFocus={e=>{e.target.style.borderColor=C.accent;e.target.style.boxShadow=S.md;}} onBlur={e=>{e.target.style.borderColor=C.border;e.target.style.boxShadow=S.sm;}}/>
      <button onClick={send} disabled={isDisabled} style={{width:52,background:isDisabled?C.elevated:C.accent,border:'none',borderRadius:16,cursor:isDisabled?'not-allowed':'pointer',fontSize:20,color:isDisabled?C.muted:'#fff',flexShrink:0,display:'flex',alignItems:'center',justifyContent:'center',transition:'all .15s',boxShadow:!isDisabled?S.sm:'none'}}>↑</button>
    </div>
  </div>);}

// ─── App Root ──────────────────────────────────────────────────────────────────
export default function CoachApp() {
  const [tab,          setTab]         = useState('home');
  const [showSettings, setShowSettings]= useState(false);
  const [isDark,       setIsDark]      = useState(() => db.get('coach_dark_mode', false));
  const [events,       setEvents]      = useState([]);
  const [cardio,       setCardio]      = useState([]);
  const [nutrition,    setNutrition]   = useState([]);
  const [strengthH,    setSH]          = useState([]);
  const [prs,          setPRs]         = useState({});
  const [trainingPlan, setTrainingPlan]= useState(null);
  const [activeWO,     setActiveWO]    = useState(null);
  const [messages,     setMessages]    = useState([]);
  const [loading,      setLoading]     = useState(false);
  const [isStreaming,  setIsStreaming]  = useState(false);
  const [streamText,   setStreamText]  = useState('');
  const [personality,  setPersonality] = useState('normal');
  const [customPrompt, setCustomPrompt]= useState('');
  const [pushMessage,  setPushMsg]     = useState('');
  const [pushLoading,  setPushLoading] = useState(false);
  const [eventModal,   setEventModal]  = useState(null);
  const [goalDetail,   setGoalDetail]  = useState(null);
  const [showQuick,    setShowQuick]   = useState(false);
  const [bricks,       setBricks]     = useState([]);
  const [brickPrompt,  setBrickPrompt]= useState(null); // {workout, candidates} for auto-suggest
  const lastPushCount = useRef(0);
  const lastPushTime  = useRef(0);

  // Inject styles once
  useEffect(()=>{
    if(!document.getElementById('coach-final-styles')){const el=document.createElement('style');el.id='coach-final-styles';el.textContent=STYLES;document.head.appendChild(el);}
  },[]);

  // Apply theme colors synchronously during render (before JSX reads C/S)
  useMemo(()=>{
    Object.assign(C, isDark ? DARK_C : LIGHT_C);
    Object.assign(S, isDark ? DARK_S : LIGHT_S);
  },[isDark]);

  // Apply document-level styles after render (DOM side effects)
  useEffect(()=>{
    document.body.style.background  = isDark ? DARK_C.bg : LIGHT_C.bg;
    document.body.style.color       = isDark ? DARK_C.text : LIGHT_C.text;
    document.body.style.colorScheme = isDark ? 'dark' : 'light';
  },[isDark]);

  // Load persisted data
  useEffect(()=>{
    setEvents(db.get('coach_events',[]));
    setCardio(db.get('coach_cardio',[]));
    setNutrition(db.get('coach_nutrition',[]));
    setSH(db.get('coach_strength_history',[]));
    setPRs(db.get('coach_prs',{}));
    setTrainingPlan(db.get('coach_training_plan',null));
    setBricks(db.get('coach_bricks',[]));
    setActiveWO(db.get('coach_active_workout',null));
    setMessages(db.get('coach_messages',[]));
    const savedP=db.get('coach_personality','normal'); const savedC=db.get('coach_custom_prompt','');
    setPersonality(savedP); setCustomPrompt(savedC);
    const pm=db.get('coach_push_message',null);
    if(pm?.text){setPushMsg(pm.text);lastPushCount.current=pm.count||0;lastPushTime.current=pm.ts||0;}
  },[]);

  const plan = useMemo(() => generateWeeklyPlan(events), [events]);
  const getAppState = useCallback(()=>({cardio,strength:strengthH,prs,events,memory:loadMemory(),plan,nutrition,trainingPlan,bricks}),[cardio,strengthH,prs,events,plan,nutrition,trainingPlan,bricks]);

  // Brick helpers
  const saveBrick=useCallback((brick)=>{
    setBricks(prev=>{const u=[{...brick,id:brick.id||'brick_'+uid()},...prev];db.set('coach_bricks',u);return u;});
    toast.success('Brick linked');
  },[]);
  const deleteBrick=useCallback(async(id)=>{
    const ok=await confirmDialog('Unlink this brick?','The individual workouts will remain.');
    if(!ok)return;
    setBricks(prev=>{const u=prev.filter(b=>b.id!==id);db.set('coach_bricks',u);return u;});
    toast.info('Brick unlinked');
  },[]);
  const detectBrickCandidate=useCallback((newWorkout)=>{
    const sameDayCardio=cardio.filter(w=>w.date===newWorkout.date&&w.sport!==newWorkout.sport&&w.sport!=='strength'&&newWorkout.sport!=='strength');
    const alreadyLinked=new Set(bricks.flatMap(b=>b.legs.map(l=>l.workoutId)));
    const candidates=sameDayCardio.filter(w=>!alreadyLinked.has(w.id));
    if(candidates.length>0)setBrickPrompt({workout:newWorkout,candidates});
  },[cardio,bricks]);

  // Auto-advance training plan week
  useEffect(()=>{
    if(!trainingPlan?.startDate||!trainingPlan?.totalWeeks) return;
    const start=new Date(trainingPlan.startDate+'T00:00:00');
    const now=new Date();
    const weeksSinceStart=Math.floor((now-start)/(7*24*60*60*1000))+1;
    const clampedWeek=Math.max(1,Math.min(weeksSinceStart,trainingPlan.totalWeeks));
    if(clampedWeek!==trainingPlan.currentWeek){
      const newPhase=trainingPlan.phases?.find(p=>{const ps=new Date(p.startDate+'T00:00:00');const pe=new Date(p.endDate+'T23:59:59');return now>=ps&&now<=pe;})?.number||trainingPlan.currentPhase;
      setTrainingPlan(prev=>{if(!prev)return prev;const u={...prev,currentWeek:clampedWeek,currentPhase:newPhase};db.set('coach_training_plan',u);return u;});
    }
  },[trainingPlan?.startDate,trainingPlan?.currentWeek,trainingPlan?.totalWeeks]);

  // Auto-refresh push message
  useEffect(()=>{
    const total=cardio.length+strengthH.length;
    const stale=Date.now()-lastPushTime.current>8*60*60*1000;
    if(total>0&&(total!==lastPushCount.current||stale)) refreshPushMessage();
  },[cardio.length,strengthH.length]);

  const refreshPushMessage=useCallback(async(pers=null,custom=null)=>{
    setPushLoading(true);
    try{const text=await generatePushMessage(pers||personality,custom!==null?custom:customPrompt,getAppState(),callAI);if(text){setPushMsg(text);const count=cardio.length+strengthH.length;lastPushCount.current=count;lastPushTime.current=Date.now();db.set('coach_push_message',{text,count,ts:Date.now()});}}catch{}
    finally{setPushLoading(false);}
  },[personality,customPrompt,getAppState,cardio.length,strengthH.length]);

  const handlePersonalityChange=useCallback(async p=>{
    setPersonality(p);db.set('coach_personality',p);
    refreshPushMessage(p,customPrompt);
  },[customPrompt,refreshPushMessage]);

  const handleCustomPromptChange=useCallback(async text=>{
    setCustomPrompt(text);db.set('coach_custom_prompt',text);
    if(personality==='custom') refreshPushMessage('custom',text);
  },[personality,refreshPushMessage]);

  const saveEvent=useCallback(ev=>{
    // Migrate existing racePlan to planSections if needed
    if(ev.racePlan && !ev.planSections){
      ev.planSections = { strategy: ev.racePlan, nutrition: { before: '', during: '', after: '' }, gear: '', travel: '', warmup: '' };
    }
    if(!ev.planSections){
      ev.planSections = { strategy: '', nutrition: { before: '', during: '', after: '' }, gear: '', travel: '', warmup: '' };
    }
    const isNew = !events.find(e=>e.id===ev.id);
    setEvents(prev=>{const u=prev.find(e=>e.id===ev.id)?prev.map(e=>e.id===ev.id?ev:e):[...prev,ev];db.set('coach_events',u);return u;});
    setEventModal(null);
    if(goalDetail?.id===ev.id) setGoalDetail(ev);
    toast.success(isNew?`"${ev.name}" added`:`"${ev.name}" updated`);
    // Auto-generate AI conditions for new races with location
    const p = presetById(ev.presetId);
    if(isNew && ev.location && ev.date && ev.mode==='goal' && ['run','tri','bike'].includes(p.planType) && !ev.aiConditions){
      toast.info('Generating race conditions…');
      generateRaceConditions(ev).then(conditions=>{
        if(conditions){
          const updated = {...ev, aiConditions: conditions};
          setEvents(prev=>{const u=prev.map(e=>e.id===updated.id?updated:e);db.set('coach_events',u);return u;});
          if(goalDetail?.id===ev.id) setGoalDetail(updated);
          toast.success('Race conditions generated');
        }
      });
    }
  },[events,goalDetail]);

  const updateEvent=useCallback(ev=>{
    setEvents(prev=>{const u=prev.map(e=>e.id===ev.id?ev:e);db.set('coach_events',u);return u;});
    setGoalDetail(ev);
  },[]);

  const deleteEvent=useCallback(id=>{
    const ev=events.find(e=>e.id===id);
    setEvents(prev=>{const u=prev.filter(e=>e.id!==id);db.set('coach_events',u);return u;});
    setEventModal(null);setGoalDetail(null);
    toast.info(`"${ev?.name}" deleted`);
  },[events]);

  const addCardio=useCallback(w=>{const nw={...w,id:w.id||uid()};setCardio(prev=>{const u=[nw,...prev];db.set('coach_cardio',u);return u;});return nw;},[]);
  const addCardioWithToast=useCallback(w=>{const nw=addCardio(w);const s=SPORT_META[w.sport]||SPORT_META.other;toast.success(`${s.label} logged — ${fmtDur(w.duration)}`);setTimeout(()=>detectBrickCandidate(nw),300);},[addCardio,detectBrickCandidate]);
  const importHealth=useCallback(workouts=>{let added=0;setCardio(prev=>{const ids=new Set(prev.map(w=>w.id));const newOnes=workouts.filter(w=>!ids.has(w.id));added=newOnes.length;const u=[...newOnes,...prev];db.set('coach_cardio',u);return u;});setTimeout(()=>toast.success(`${added} workout${added!==1?'s':''} imported`),100);},[]);

  const saveStrength=useCallback((completedEx,dur,newPRs,template)=>{
    const saved={id:uid(),templateId:template?.id,name:template?.name||'Strength',date:todayStr(),duration:dur,exercises:completedEx};
    setSH(prev=>{const u=[...prev,saved];db.set('coach_strength_history',u);return u;});
    const updatedPRs={...prs};for(const pr of newPRs)updatedPRs[pr.exerciseId]={weight:pr.weight,reps:pr.reps,estimated1RM:pr.estimated1RM,date:todayStr()};
    setPRs(updatedPRs);db.set('coach_prs',updatedPRs);setActiveWO(null);db.set('coach_active_workout',null);
    if(newPRs.length>0)toast.success(`${newPRs.length} new PR${newPRs.length>1?'s':''}!`);
    else toast.success(`${template?.name||'Strength'} saved — ${fmtDur(dur)}`);
  },[prs]);

  const handleSend=useCallback(async text=>{
    const userMsg={role:'user',content:text};const withUser=[...messages,userMsg];
    setMessages(withUser);setLoading(true);
    try{
      const appState=getAppState();
      const{response,workoutsLogged,nutritionLogged,planChanges}=await runAgentLoop({personality,customText:customPrompt,messages:withUser,appState,callAI,maxRounds:7});
      for(const w of workoutsLogged)addCardio(w);
      for(const m of nutritionLogged){setNutrition(prev=>{const u=[{...m,id:uid()},...prev].slice(0,200);db.set('coach_nutrition',u);return u;});}
      // Process plan changes
      for(const pc of planChanges){
        if(pc.type==='plan'){setTrainingPlan(pc.data);db.set('coach_training_plan',pc.data);toast.success('Training plan created');}
        if(pc.type==='week'){setTrainingPlan(prev=>{if(!prev)return prev;const u={...prev,weeklyPlans:{...prev.weeklyPlans,[String(pc.data.weekNumber)]:pc.data}};db.set('coach_training_plan',u);return u;});toast.success(`Week ${pc.data.weekNumber} plan generated`);}
        if(pc.type==='progress'){setTrainingPlan(prev=>{if(!prev)return prev;const u={...prev,currentWeek:pc.data.currentWeek,currentPhase:pc.data.currentPhase};db.set('coach_training_plan',u);return u;});}
      }
      setLoading(false);setIsStreaming(true);setStreamText('');
      await typewriter(response,chunk=>setStreamText(chunk));
      const aMsg={role:'assistant',content:response,logged:workoutsLogged.length>0,nutritionLogged:nutritionLogged.length>0,planChanged:planChanges.length>0};
      const final=[...withUser,aMsg];setMessages(final);db.set('coach_messages',final.slice(-60));
      setIsStreaming(false);setStreamText('');
      for(const w of workoutsLogged){const s=SPORT_META[w.sport]||SPORT_META.other;toast.success(`${s.label} logged — ${fmtDur(w.duration)}`);}
      for(const m of nutritionLogged){toast.success(`Nutrition logged — ${m.timing} training`);}
      extractMemory(final.slice(-8),callAI);
    }catch(err){
      setLoading(false);setIsStreaming(false);setStreamText('');
      const errMsg={role:'assistant',content:`Something went wrong: ${err.message}`,isError:true};
      setMessages(prev=>[...prev,errMsg]);db.set('coach_messages',[...messages,userMsg].slice(-60));
      toast.error('Message failed — check connection');
    }
  },[messages,personality,customPrompt,getAppState,addCardio]);

  const p=PERSONALITIES[personality]||PERSONALITIES.normal;
  const TABS=[{id:'home',label:'Home',icon:'home'},{id:'goals',label:'Goals',icon:'target'},{id:'plan',label:'Plan',icon:'calendar'},{id:'log',label:'Log',icon:'chart'},{id:'chat',label:'Coach',icon:'message'}];

  return(
    <div style={{background:C.bg,minHeight:'100svh',color:C.text,fontFamily:F.ui,maxWidth:500,margin:'0 auto',position:'relative'}}>
      {/* Top bar */}
      <div style={{position:'sticky',top:0,zIndex:50,background:C.bg+'F6',backdropFilter:'blur(20px)',borderBottom:`1px solid ${C.border}`}}>
        <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',padding:'14px 20px 0'}}>
          <div>
            <div style={{fontFamily:F.display,fontSize:24,fontWeight:800,letterSpacing:'-.01em',lineHeight:1,color:C.text}}>Coach</div>
            <div style={{fontFamily:F.ui,fontSize:11,fontWeight:500,color:C.muted,marginTop:1}}>Your personal trainer</div>
          </div>
          <div style={{display:'flex',alignItems:'center',gap:8}}>
            <button onClick={()=>setShowQuick(true)} style={{width:36,height:36,borderRadius:11,background:C.accent+'15',border:`1.5px solid ${C.accent}30`,cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center',color:C.accent,transition:'all .15s'}} onMouseEnter={e=>e.currentTarget.style.background=C.accent+'25'} onMouseLeave={e=>e.currentTarget.style.background=C.accent+'15'}><Icon name='zap' size={18}/></button>
            <button onClick={()=>setShowSettings(true)} style={{width:36,height:36,borderRadius:11,background:C.elevated,border:`1.5px solid ${C.border}`,cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center',color:C.subtle,transition:'all .15s'}} onMouseEnter={e=>e.currentTarget.style.color=C.text} onMouseLeave={e=>e.currentTarget.style.color=C.subtle}><Icon name='settings' size={18}/></button>
          </div>
        </div>
        <div style={{display:'flex',marginTop:12}}>
          {TABS.map(t=>(
            <button key={t.id} onClick={()=>setTab(t.id)} style={{flex:1,padding:'7px 2px 11px',background:'none',border:'none',borderBottom:`2.5px solid ${tab===t.id?C.accent:'transparent'}`,color:tab===t.id?C.accent:C.muted,cursor:'pointer',transition:'all .18s',display:'flex',flexDirection:'column',alignItems:'center',gap:3}}>
              <Icon name={t.icon} size={16} color={tab===t.id?C.accent:C.muted}/>
              <span style={{fontFamily:F.ui,fontSize:10,fontWeight:700,textTransform:'uppercase',letterSpacing:'.06em'}}>{t.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Content */}
      <div style={{padding:'20px 16px 0'}}>
        {tab==='home'&&<HomeTab events={events} cardio={cardio} strength={strengthH} pushMessage={pushMessage} pushLoading={pushLoading} personality={personality} onRefreshPush={refreshPushMessage} onAddEvent={()=>setEventModal('add')} onViewGoal={e=>setGoalDetail(e)} onViewAllGoals={()=>setTab('goals')} onLog={()=>setTab('log')} onChat={()=>setTab('chat')} setTab={setTab} onStartStrength={id=>{const t=STRENGTH_TEMPLATES.find(t=>t.id===id);if(t){const s={id:Date.now(),templateId:t.id,name:t.name,startTime:Date.now()};setActiveWO(s);db.set('coach_active_workout',s);}setTab('plan');}} plan={plan} trainingPlan={trainingPlan}/>}
        {tab==='goals'&&<GoalsTab events={events} onViewGoal={e=>setGoalDetail(e)} onAddEvent={()=>setEventModal('add')}/>}
        {tab==='plan'&&<TrainingPlanTab events={events} cardio={cardio} strengthHistory={strengthH} prs={prs} onSaveStrength={saveStrength} activeWO={activeWO} setActiveWO={setActiveWO} trainingPlan={trainingPlan} onAddEvent={()=>setEventModal('add')} appState={getAppState()} onPlanCreated={plan=>{setTrainingPlan(plan);db.set('coach_training_plan',plan);toast.success('Training plan created');}} onWeekGenerated={wp=>{setTrainingPlan(prev=>{if(!prev)return prev;const u={...prev,weeklyPlans:{...prev.weeklyPlans,[String(wp.weekNumber)]:wp}};db.set('coach_training_plan',u);return u;});toast.success(`Week ${wp.weekNumber} plan generated`);}} onDisruption={msg=>{setTab('chat');setTimeout(()=>handleSend(msg),100);}}/>}
        {tab==='log'&&<WorkoutLogTab cardio={cardio} strength={strengthH} onAddCardio={addCardioWithToast} onImportHealth={importHealth} bricks={bricks} onSaveBrick={saveBrick} onDeleteBrick={deleteBrick}/>}
        {tab==='chat'&&<ChatTab messages={messages} onSend={handleSend} loading={loading} isStreaming={isStreaming} streamText={streamText} personality={personality}/>}
      </div>


      {brickPrompt&&<div style={{position:'fixed',bottom:80,left:'50%',transform:'translateX(-50%)',width:'calc(100% - 32px)',maxWidth:468,zIndex:60}}><BrickPromptBanner workout={brickPrompt.workout} candidates={brickPrompt.candidates} onLink={(w1,w2)=>{saveBrick({date:w1.date,legs:[{workoutId:w2.id,sport:w2.sport},{workoutId:w1.id,sport:w1.sport}],transitionTime:null,transitionNotes:'',notes:''});setBrickPrompt(null);}} onDismiss={()=>setBrickPrompt(null)}/></div>}
      {(eventModal==='add'||(eventModal&&typeof eventModal==='object'))&&<EventModal event={eventModal==='add'?null:eventModal} onSave={saveEvent} onClose={()=>setEventModal(null)} onDelete={deleteEvent}/>}
      {showQuick&&<QuickCaptureSheet onClose={()=>setShowQuick(false)} onLog={w=>{addCardio(w);}} plan={plan}/>}

      {showSettings&&<SettingsPage personality={personality} customPrompt={customPrompt} onPersonalityChange={handlePersonalityChange} onCustomPromptChange={handleCustomPromptChange} isDark={isDark} onToggleDark={()=>setIsDark(d=>{const next=!d;db.set('coach_dark_mode',next);return next;})} onClose={()=>setShowSettings(false)}/>}

      {goalDetail&&<GoalDetailView event={goalDetail} onUpdate={updateEvent} onEdit={e=>{setEventModal(e);}} onDelete={deleteEvent} onClose={()=>setGoalDetail(null)}/>}

      <ToastManager/>
      <ConfirmManager/>
    </div>
  );
}
