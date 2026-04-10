"use client";
import React, { useState, useEffect, useRef } from "react";
import { C, S, F } from '../../lib/theme.js';
import { Icon } from '../../lib/icons.js';
import { SPORT_META } from '../../lib/constants.js';
import { fmtDur, getDayName } from '../../lib/utils.js';
import { callAI } from '../../ai/call-ai.js';
import { Sheet, Btn, Inp, Textarea, Label, Pill, Spinner } from '../../ui/primitives.js';
import { toast } from '../../ui/toast.js';

function parseQuickCapture(text, callAI) {
  return callAI({system:`Parse this workout description into JSON. Return ONLY valid JSON: {"sport":"run|bike|swim|strength|hike|other","duration":minutes_number,"notes":"brief description","date":"YYYY-MM-DD"}. Today is ${new Date().toISOString().split('T')[0]}. If no date mentioned, use today.`,messages:[{role:'user',content:text}],max_tokens:200}).then(r=>{const raw=r.content?.filter(b=>b.type==='text')?.map(b=>b.text)?.join('')||'';return JSON.parse(raw.replace(/```json\n?|\n?```/g,'').trim());});
}

export function QuickCaptureSheet({ onClose, onLog, plan }) {
  const[input,setInput]=useState('');const[loading,setLoading]=useState(false);const[parsed,setParsed]=useState(null);const inputRef=useRef(null);
  useEffect(()=>setTimeout(()=>inputRef.current?.focus(),100),[]);
  const today=getDayName();const todayPlan=plan?.find(d=>d.day===today);
  const suggestions=todayPlan?.sessions?.filter(s=>s.type!=='strength')?.map(s=>`${fmtDur(s.duration)} ${s.label.toLowerCase()}`)||[];
  const handleSubmit=async()=>{if(!input.trim()||loading)return;setLoading(true);try{const r=await parseQuickCapture(input,callAI);setParsed(r);}catch{toast.error('Could not parse — try "45 min easy run"');}setLoading(false);};
  const handleConfirm=()=>{if(!parsed)return;onLog(parsed);toast.success(`${SPORT_META[parsed.sport]?.label||parsed.sport} logged — ${fmtDur(parsed.duration)}`);onClose();};
  const handleSuggestion=async text=>{setInput(text);setLoading(true);try{const r=await parseQuickCapture(text,callAI);setParsed(r);}catch{}setLoading(false);};
  return(<Sheet onClose={onClose} title="Quick log"><div style={{fontFamily:F.ui,fontSize:15,color:C.subtle,marginBottom:16,lineHeight:1.6}}>Tell me what you did in plain English.</div>{suggestions.length>0&&!parsed&&<div style={{marginBottom:14}}><Label>Today's plan</Label><div style={{display:'flex',gap:8,flexWrap:'wrap'}}>{suggestions.map((s,i)=><button key={i} onClick={()=>handleSuggestion(s)} style={{background:C.elevated,border:`1.5px solid ${C.border}`,borderRadius:10,padding:'7px 14px',fontFamily:F.ui,fontSize:13,fontWeight:500,color:C.subtle,cursor:'pointer',transition:'all .15s'}} onMouseEnter={e=>{e.currentTarget.style.borderColor=C.accent;e.currentTarget.style.color=C.accent;}} onMouseLeave={e=>{e.currentTarget.style.borderColor=C.border;e.currentTarget.style.color=C.subtle;}}>{s}</button>)}</div></div>}{parsed&&<div className="fade-up" style={{marginBottom:16,padding:'14px 16px',background:C.green+'0A',borderRadius:14,border:`1.5px solid ${C.green}44`}}><div style={{fontFamily:F.ui,fontWeight:600,fontSize:14,color:C.green,marginBottom:8}}>✓ Ready to log</div><div style={{display:'flex',gap:10,flexWrap:'wrap'}}><Pill color={SPORT_META[parsed.sport]?.color||C.accent}>{SPORT_META[parsed.sport]?.label||parsed.sport}</Pill><Pill color={C.cyan}>{fmtDur(parsed.duration)}</Pill>{parsed.notes&&<Pill color={C.subtle}>{parsed.notes}</Pill>}</div></div>}{!parsed&&<div style={{display:'flex',gap:8,marginBottom:16}}><Inp ref={inputRef} placeholder='e.g. Just ran 5 miles easy, 50 minutes' value={input} onChange={e=>setInput(e.target.value)} onKeyDown={e=>e.key==='Enter'&&handleSubmit()} style={{flex:1}}/><button onClick={handleSubmit} disabled={loading||!input.trim()} style={{width:50,height:50,background:loading||!input.trim()?C.elevated:C.accent,border:'none',borderRadius:12,cursor:loading||!input.trim()?'not-allowed':'pointer',color:loading||!input.trim()?C.muted:'#fff',fontSize:18,display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>{loading?<Spinner color="#fff" size={14}/>:'→'}</button></div>}{parsed?<div style={{display:'flex',gap:10}}><Btn onClick={()=>{setParsed(null);setInput('');}} outline style={{flex:1}}>Edit</Btn><Btn onClick={handleConfirm} color={C.green} style={{flex:2}}>Log it ✓</Btn></div>:<div style={{fontFamily:F.ui,fontSize:13,color:C.muted,textAlign:'center'}}>Or use the full <button onClick={onClose} style={{background:'none',border:'none',color:C.accent,fontFamily:F.ui,fontSize:13,cursor:'pointer',textDecoration:'underline',padding:0}}>Log tab</button></div>}</Sheet>);
}
