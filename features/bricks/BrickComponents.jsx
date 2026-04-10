"use client";
import React, { useState } from "react";
import { C, S, F } from '../../lib/theme.js';
import { Icon } from '../../lib/icons.js';
import { SPORT_META } from '../../lib/constants.js';
import { todayStr, fmtDateSh, fmtDur } from '../../lib/utils.js';
import { Card, Sheet, Btn, Inp, Pill, SportBadge, Label } from '../../ui/primitives.js';

export function LinkBrickSheet({cardio,bricks,onSave,onClose}){
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

export function BrickPromptBanner({workout,candidates,onLink,onDismiss}){
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
