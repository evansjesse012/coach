"use client";
import React, { useState, useEffect, useRef, useCallback } from "react";
import { C, S, F } from '../../lib/theme.js';
import { Icon } from '../../lib/icons.js';
import { loadMemory, saveMemory, mergeMemory, defaultMemory } from '../../ai/memory.js';
import { callAI } from '../../ai/call-ai.js';
import { TOOLS } from '../../ai/tools.js';
import { renderMd } from '../../lib/utils.js';
import { Sheet, Btn, Inp, Textarea, Label, Spinner, Card, Pill, DotsLoader } from '../../ui/primitives.js';
import { toast } from '../../ui/toast.js';

export function AthleteProfilePage({onClose}){
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
  useEffect(()=>{bottomRef.current?.scrollIntoView({behavior:'smooth'});},[msgs,streamText]);

  const profilePrompt=`You are updating an athlete's coaching profile. The athlete is sharing information about themselves. Your job:
1. Acknowledge what they shared (1-2 sentences)
2. Extract facts and update the coaching memory appropriately
3. Ask a follow-up question to learn more — pick from gaps you notice (equipment, facilities, schedule, injuries, medical history, dietary needs, benchmarks, goals, preferences, training history)
4. Keep it conversational and brief — this is mobile.

Classify facts into tiers:
- permanent: equipment, facilities, schedule, medical history, dietary constraints, communication preferences, safety rules
- benchmarks: tested values (FTP, threshold pace, CSS) with date and method
- injuries: area, status, severity, triggers, modifications, return criteria
- observations: patterns, motivators, coaching notes, focus areas
- responseProfile: how they respond to training (volume vs intensity, recovery, skip patterns)

Today: ${new Date().toISOString().split('T')[0]}`;

  const typewriter=(text,onUpdate)=>new Promise(resolve=>{let i=0;const step=()=>{if(i>=text.length){resolve();return;}i+=Math.floor(Math.random()*3)+1;onUpdate(text.slice(0,i));requestAnimationFrame(step);};step();});

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
{"permanent":{"equipment":[],"facilities":[],"schedule":{"availableDays":0,"preferredTimes":"","constraints":[]},"medicalHistory":[],"dietaryConstraints":[],"communicationPrefs":"","safetyRules":[]},"benchmarks":[],"injuries":[],"observations":{"patterns":[],"motivators":[],"consistency":"","currentFocus":"","openItems":[],"coachingNotes":[]},"responseProfile":{"volumeVsIntensity":"","recoveryRate":"","skipPatterns":[]}}
If no extractable facts, return {}.`,messages:[{role:'user',content:chainRef.current.map(m=>`${m.role==='user'?'Athlete':'Coach'}: ${m.content}`).join('\n')}],max_tokens:600});
        const raw=extract.content?.filter(b=>b.type==='text')?.map(b=>b.text)?.join('')||'';
        const parsed=JSON.parse(raw.replace(/```json\n?|\n?```/g,'').trim());
        if(Object.keys(parsed).length>0){saveMemory(mergeMemory(loadMemory(),parsed));refreshMem();toast.success('Profile updated with new info');}
        else{toast.info('No new info to save — try sharing something specific');}
      }catch{toast.info('Got it — your coach will remember this context');}
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

  const hasPermanent = !!(mem.permanent?.equipment?.length||mem.permanent?.facilities?.length||mem.permanent?.schedule?.preferredTimes||mem.permanent?.communicationPrefs);
  const hasBenchmarks = !!mem.benchmarks?.length;
  const hasInjuries = !!mem.injuries?.length;
  const hasObservations = !!(mem.observations?.patterns?.length||mem.observations?.motivators?.length||mem.observations?.consistency||mem.observations?.currentFocus||mem.observations?.coachingNotes?.length);
  const hasResponseProfile = !!(mem.responseProfile?.volumeVsIntensity||mem.responseProfile?.recoveryRate||mem.responseProfile?.skipPatterns?.length||mem.responseProfile?.communicationNeeds);
  const hasHistory = !!(mem.conversationSummaries?.length||mem.periodSummaries?.length);

  return(<div className="slide-in" style={{position:'fixed',inset:0,background:C.bg,zIndex:100,overflowY:'auto',maxWidth:500,margin:'0 auto'}}>
    <div style={{background:C.bg+'F6',backdropFilter:'blur(20px)',borderBottom:`1px solid ${C.border}`,padding:'16px 20px',display:'flex',alignItems:'center',gap:12,position:'sticky',top:0,zIndex:10}}>
      <button onClick={onClose} style={{borderRadius:12,background:C.elevated,border:`1.5px solid ${C.border}`,color:C.text,cursor:'pointer',display:'flex',alignItems:'center',gap:4,padding:'8px 14px 8px 10px',flexShrink:0}}><Icon name='arrowLeft' size={16}/><span style={{fontFamily:F.ui,fontSize:13,fontWeight:600}}>Back</span></button>
      <div style={{fontFamily:F.display,fontSize:22,fontWeight:800,color:C.text,letterSpacing:'-.01em'}}>Athlete Profile</div>
    </div>

    <div style={{padding:'20px 16px 48px'}}>
      <div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,lineHeight:1.7,marginBottom:20}}>This is what your coach knows about you. The more you share, the better the coaching.</div>

      <Section icon="dumbbell" color={C.accent} title="Setup" empty="Tell your coach about your schedule, equipment, and preferences">
        {hasPermanent&&<div style={{display:'flex',flexDirection:'column',gap:8}}>
          {mem.permanent.schedule?.preferredTimes&&<div style={{display:'flex',gap:8}}><Icon name='calendar' size={13} color={C.muted}/><span style={{fontFamily:F.ui,fontSize:14,color:C.text}}>{mem.permanent.schedule.preferredTimes}</span></div>}
          {mem.permanent.schedule?.availableDays>0&&<div style={{display:'flex',gap:8}}><Icon name='chart' size={13} color={C.muted}/><span style={{fontFamily:F.ui,fontSize:14,color:C.text}}>{mem.permanent.schedule.availableDays} days/week</span></div>}
          {mem.permanent.schedule?.constraints?.length>0&&<div style={{display:'flex',gap:6,flexWrap:'wrap'}}>{mem.permanent.schedule.constraints.map((c,i)=><Pill key={i} color={C.muted} small>{c}</Pill>)}</div>}
          {mem.permanent.equipment?.length>0&&<div style={{display:'flex',gap:8,flexWrap:'wrap'}}><Icon name='dumbbell' size={13} color={C.muted} style={{flexShrink:0,marginTop:3}}/><div style={{display:'flex',gap:6,flexWrap:'wrap'}}>{mem.permanent.equipment.map((e,i)=><Pill key={i} color={C.accent} small>{e}</Pill>)}</div></div>}
          {mem.permanent.facilities?.length>0&&<div style={{display:'flex',gap:8,flexWrap:'wrap'}}><Icon name='target' size={13} color={C.muted} style={{flexShrink:0,marginTop:3}}/><div style={{display:'flex',gap:6,flexWrap:'wrap'}}>{mem.permanent.facilities.map((f,i)=><Pill key={i} color={C.cyan} small>{f}</Pill>)}</div></div>}
          {mem.permanent.communicationPrefs&&<div style={{display:'flex',gap:8}}><Icon name='message' size={13} color={C.muted}/><span style={{fontFamily:F.ui,fontSize:14,color:C.text}}>{mem.permanent.communicationPrefs}</span></div>}
          {mem.permanent.medicalHistory?.length>0&&<div><div style={{fontFamily:F.ui,fontSize:11,fontWeight:600,color:C.yellow,marginBottom:4,marginTop:4}}>MEDICAL</div><div style={{display:'flex',gap:6,flexWrap:'wrap'}}>{mem.permanent.medicalHistory.map((h,i)=><Pill key={i} color={C.yellow} small>{h}</Pill>)}</div></div>}
          {mem.permanent.dietaryConstraints?.length>0&&<div><div style={{fontFamily:F.ui,fontSize:11,fontWeight:600,color:C.green,marginBottom:4,marginTop:4}}>DIETARY</div><div style={{display:'flex',gap:6,flexWrap:'wrap'}}>{mem.permanent.dietaryConstraints.map((d,i)=><Pill key={i} color={C.green} small>{d}</Pill>)}</div></div>}
          {mem.permanent.safetyRules?.length>0&&<div><div style={{fontFamily:F.ui,fontSize:11,fontWeight:600,color:C.red,marginBottom:4,marginTop:4}}>SAFETY RULES</div>{mem.permanent.safetyRules.map((r,i)=><div key={i} style={{display:'flex',gap:8,padding:'4px 0'}}><span style={{color:C.red,flexShrink:0}}>!</span><span style={{fontFamily:F.ui,fontSize:14,color:C.text}}>{r.rule}{r.reason&&<span style={{color:C.muted}}> — {r.reason}</span>}</span></div>)}</div>}
        </div>}
      </Section>

      <Section icon="target" color={C.green} title="Benchmarks" empty="Your coach will track test results and fitness markers here">
        {hasBenchmarks&&<div>{mem.benchmarks.map((b,i)=><div key={i} style={{display:'flex',alignItems:'center',gap:8,padding:'6px 0',borderTop:i>0?`1px solid ${C.border}`:'none'}}>
          <span style={{fontFamily:F.ui,fontSize:14,fontWeight:600,color:C.text,flex:1}}>{b.metric}</span>
          <span style={{fontFamily:F.mono,fontSize:14,fontWeight:700,color:C.green}}>{b.value}</span>
          {b.testDate&&<span style={{fontFamily:F.ui,fontSize:11,color:C.muted}}>{b.testDate}</span>}
        </div>)}</div>}
      </Section>

      <Section icon="alert" color={C.yellow} title="Injuries" empty="Share any injuries — your coach will track them over time">
        {hasInjuries&&<div>{mem.injuries.map((inj,i)=><div key={i} style={{padding:'8px 0',borderTop:i>0?`1px solid ${C.border}`:'none'}}>
          <div style={{display:'flex',alignItems:'center',gap:8,marginBottom:4}}>
            <Pill color={inj.status==='resolved'?C.green:inj.status==='monitoring'?C.yellow:C.red} small>{inj.status||'active'}</Pill>
            <span style={{fontFamily:F.ui,fontSize:14,fontWeight:600,color:C.text}}>{inj.area}</span>
            {inj.severity&&<span style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginLeft:'auto'}}>{inj.severity}</span>}
          </div>
          {inj.triggers?.length>0&&<div style={{fontFamily:F.ui,fontSize:12,color:C.subtle,marginBottom:2}}>Triggers: {inj.triggers.join(', ')}</div>}
          {inj.modifications?.length>0&&<div style={{fontFamily:F.ui,fontSize:12,color:C.subtle,marginBottom:2}}>Modifications: {inj.modifications.join(', ')}</div>}
          {inj.history?.length>0&&<div style={{fontFamily:F.ui,fontSize:12,color:C.muted,fontStyle:'italic'}}>{inj.history[inj.history.length-1].note}</div>}
        </div>)}</div>}
      </Section>

      <Section icon="clipboard" color={C.cyan} title="Patterns" empty="Your coach will notice patterns as you train">
        {hasObservations&&<div>
          {mem.observations.currentFocus&&<div style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.6,marginBottom:8,padding:'8px 12px',background:C.purple+'0A',borderRadius:10,border:`1px solid ${C.purple}30`}}>{mem.observations.currentFocus}</div>}
          {mem.observations.patterns?.map((p,i)=><div key={i} style={{display:'flex',gap:8,padding:'6px 0',borderTop:i>0?`1px solid ${C.border}`:'none'}}><span style={{color:C.cyan,flexShrink:0}}>•</span><span style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.5}}>{p}</span></div>)}
          {mem.observations.consistency&&<div style={{marginTop:8,fontFamily:F.ui,fontSize:13,color:C.muted,fontStyle:'italic'}}>{mem.observations.consistency}</div>}
          {mem.observations.motivators?.length>0&&<div style={{marginTop:8,display:'flex',gap:6,flexWrap:'wrap'}}>{mem.observations.motivators.map((mv,i)=><Pill key={i} color={C.purple} small>{mv}</Pill>)}</div>}
          {mem.observations.openItems?.length>0&&<div style={{marginTop:10}}><div style={{fontFamily:F.ui,fontSize:11,fontWeight:600,color:C.purple,marginBottom:4}}>OPEN ITEMS</div>{mem.observations.openItems.map((item,i)=><div key={i} style={{display:'flex',gap:8,padding:'5px 0'}}><span style={{color:C.purple,flexShrink:0,fontSize:12}}>○</span><span style={{fontFamily:F.ui,fontSize:14,color:C.subtle}}>{item}</span></div>)}</div>}
          {mem.observations.coachingNotes?.length>0&&<div style={{marginTop:10}}><div style={{fontFamily:F.ui,fontSize:11,fontWeight:600,color:C.cyan,marginBottom:4}}>COACHING NOTES</div>{mem.observations.coachingNotes.map((n,i)=><div key={i} style={{display:'flex',gap:8,padding:'4px 0'}}><span style={{color:C.cyan,flexShrink:0}}>•</span><span style={{fontFamily:F.ui,fontSize:13,color:C.subtle,lineHeight:1.5}}>{n}</span></div>)}</div>}
        </div>}
      </Section>

      <Section icon="run" color={C.purple} title="Response Profile" empty="Your coach will learn how you respond to training over time">
        {hasResponseProfile&&<div style={{display:'flex',flexDirection:'column',gap:6}}>
          {mem.responseProfile.volumeVsIntensity&&<div style={{fontFamily:F.ui,fontSize:14,color:C.text}}><span style={{color:C.muted}}>Volume vs Intensity:</span> {mem.responseProfile.volumeVsIntensity}</div>}
          {mem.responseProfile.recoveryRate&&<div style={{fontFamily:F.ui,fontSize:14,color:C.text}}><span style={{color:C.muted}}>Recovery:</span> {mem.responseProfile.recoveryRate}</div>}
          {mem.responseProfile.easyDayDiscipline&&<div style={{fontFamily:F.ui,fontSize:14,color:C.text}}><span style={{color:C.muted}}>Easy days:</span> {mem.responseProfile.easyDayDiscipline}</div>}
          {mem.responseProfile.sessionPreferences&&<div style={{fontFamily:F.ui,fontSize:14,color:C.text}}><span style={{color:C.muted}}>Preferences:</span> {mem.responseProfile.sessionPreferences}</div>}
          {mem.responseProfile.communicationNeeds&&<div style={{fontFamily:F.ui,fontSize:14,color:C.text}}><span style={{color:C.muted}}>Coaching style:</span> {mem.responseProfile.communicationNeeds}</div>}
          {mem.responseProfile.skipPatterns?.length>0&&<div style={{display:'flex',gap:6,flexWrap:'wrap',marginTop:4}}>{mem.responseProfile.skipPatterns.map((s,i)=><Pill key={i} color={C.yellow} small>{s}</Pill>)}</div>}
        </div>}
      </Section>

      <Section icon="message" color={C.muted} title="Coaching History" empty="Conversation summaries will appear as you train">
        {hasHistory&&<div>
          {mem.periodSummaries?.length>0&&<div style={{marginBottom:10}}>{mem.periodSummaries.map((ps,i)=><div key={i} style={{padding:'8px 12px',background:C.elevated,borderRadius:10,marginBottom:6}}><div style={{fontFamily:F.ui,fontSize:11,fontWeight:600,color:C.muted,marginBottom:4}}>{ps.periodStart||'?'} — {ps.periodEnd||'?'}</div><div style={{fontFamily:F.ui,fontSize:13,color:C.subtle,lineHeight:1.6}}>{ps.summary}</div></div>)}</div>}
          {mem.conversationSummaries?.slice(-10).reverse().map((s,i)=><div key={i} style={{display:'flex',gap:8,padding:'6px 0',borderTop:i>0?`1px solid ${C.border}`:'none'}}>{s.date&&<span style={{fontFamily:F.mono,fontSize:11,color:C.muted,flexShrink:0,marginTop:2}}>{s.date}</span>}<span style={{fontFamily:F.ui,fontSize:13,color:C.subtle,lineHeight:1.5}}>{s.summary}</span></div>)}
        </div>}
      </Section>

      <Btn onClick={()=>setShowChat(true)} color={C.accent} style={{width:'100%',padding:15,fontSize:16,marginTop:8}}>Tell your coach more</Btn>
    </div>

    {showChat&&<Sheet onClose={()=>{setShowChat(false);refreshMem();}} title="Update your profile">
      <div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,marginBottom:16,lineHeight:1.6}}>Share anything that would help your coach — schedule, equipment, injuries, preferences, goals.</div>
      <div style={{maxHeight:'45vh',overflowY:'auto',display:'flex',flexDirection:'column',gap:10,marginBottom:16}}>
        {msgs.map((m,i)=>m.role==='user'
          ?<div key={i} className="fade-up" style={{alignSelf:'flex-end',background:C.accent,color:'#fff',borderRadius:'16px 16px 4px 16px',padding:'10px 14px',maxWidth:'85%',fontFamily:F.ui,fontSize:14,lineHeight:1.6}}>{m.content}</div>
          :<div key={i} className="fade-up" style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.75}}>{renderMd(m.content)}</div>
        )}
        {isStreaming&&streamText&&<div className="fade-up" style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.75}}>{renderMd(streamText)}</div>}
        {loading&&!isStreaming&&<DotsLoader color={C.accent}/>}
        <div ref={bottomRef}/>
      </div>
      <div style={{display:'flex',gap:8,alignItems:'flex-end'}}>
        <Textarea value={input} onChange={e=>setInput(e.target.value)} onKeyDown={e=>{if(e.key==='Enter'&&!e.shiftKey&&!loading&&input.trim()){e.preventDefault();sendMsg(input.trim());}}} placeholder="e.g. I train mornings, have a pool and Wahoo Kickr, recovering from a knee injury..." rows={2} style={{flex:1,minHeight:48,maxHeight:120}}/>
        <button onClick={()=>input.trim()&&!loading&&sendMsg(input.trim())} disabled={!input.trim()||loading} style={{width:48,height:48,background:!input.trim()||loading?C.elevated:C.accent,border:'none',borderRadius:12,cursor:!input.trim()||loading?'not-allowed':'pointer',color:!input.trim()||loading?C.muted:'#fff',fontSize:18,display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>↑</button>
      </div>
    </Sheet>}
  </div>);
}
