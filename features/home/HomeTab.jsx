"use client";
import React, { useState } from "react";
import { C, S, F } from '../../lib/theme.js';
import { Icon } from '../../lib/icons.js';
import { SPORT_META, presetById } from '../../lib/constants.js';
import { fmtDur, fmtDateSh, daysUntil, todayStr } from '../../lib/utils.js';
import { Card, Label, Pill, SportBadge } from '../../ui/primitives.js';
import { TodaySessionCard } from './TodaySessionCard.jsx';
import { PushMessageCard } from './PushMessageCard.jsx';
import { WorkoutDetailSheet } from '../log/WorkoutDetailSheet.jsx';

export function HomeTab({events,cardio,strength,pushMessage,pushLoading,personality,onRefreshPush,onPushAction,onAddEvent,onAddEventChat,onViewGoal,onViewAllGoals,onLog,onChat,setTab,onStartStrength,plan,trainingPlan}){
  const[selectedWorkout,setSelectedWorkout]=useState(null);
  const active=events.filter(e=>!e.completed);const completed=events.filter(e=>e.completed);const now=new Date();const ws=new Date(now);ws.setDate(now.getDate()-now.getDay());
  const thisWeekC=cardio.filter(w=>new Date(w.date+'T12:00:00')>=ws);const thisWeekS=strength.filter(s=>new Date(s.date+'T12:00:00')>=ws);
  const allRecent=[...cardio.map(w=>({...w,kind:'cardio'})),...strength.map(s=>({...s,sport:'strength',kind:'strength'}))].sort((a,b)=>b.date.localeCompare(a.date)).slice(0,4);
  const hasWorkouts=cardio.length+strength.length>0;
  return(<div style={{paddingBottom:80}}>
    <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:10}}>
      <Label style={{marginBottom:0}}>Training for</Label>
      {events.length>0&&<button onClick={onViewAllGoals} style={{background:'none',border:'none',fontFamily:F.ui,fontSize:13,fontWeight:600,color:C.accent,cursor:'pointer',padding:0}}>All goals{completed.length>0?` (${completed.length} past)`:''} →</button>}
    </div>
    {active.length===0?<div style={{marginBottom:16,display:'flex',gap:10}}>
      <Card onClick={onAddEventChat} accent={C.purple} style={{flex:1,textAlign:'center',padding:22}}><div style={{marginBottom:6}}><Icon name='sparkle' size={24} color={C.purple}/></div><div style={{fontFamily:F.display,fontSize:15,fontWeight:700,color:C.purple,marginBottom:3}}>Describe a goal</div><div style={{fontFamily:F.ui,fontSize:12,color:C.subtle}}>Chat with AI</div></Card>
      <Card onClick={onAddEvent} accent={C.accent} style={{flex:1,textAlign:'center',padding:22}}><div style={{marginBottom:6}}><Icon name='plus' size={24} color={C.accent}/></div><div style={{fontFamily:F.display,fontSize:15,fontWeight:700,color:C.accent,marginBottom:3}}>Add manually</div><div style={{fontFamily:F.ui,fontSize:12,color:C.subtle}}>Fill out a form</div></Card>
    </div>
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
    <PushMessageCard message={pushMessage.text} actions={pushMessage.actions} personality={personality} loading={pushLoading} onRefresh={onRefreshPush} onAction={onPushAction} hasWorkouts={hasWorkouts}/>
    <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10,marginBottom:16}}>
      <Card><Label>This week</Label><div style={{fontFamily:F.display,fontSize:44,fontWeight:800,lineHeight:1,color:C.text}}>{thisWeekC.length+thisWeekS.length}</div><div style={{fontFamily:F.ui,fontSize:13,fontWeight:500,color:C.muted,marginTop:3}}>sessions</div><div style={{display:'flex',gap:6,marginTop:10,flexWrap:'wrap'}}>{thisWeekS.length>0&&<SportBadge sport="strength" small/>}{[...new Set(thisWeekC.map(w=>w.sport))].map(s=><SportBadge key={s} sport={s} small/>)}{thisWeekC.length+thisWeekS.length===0&&<span style={{fontFamily:F.ui,fontSize:12,color:C.muted}}>None yet</span>}</div></Card>
      <Card><Label>All time</Label><div style={{fontFamily:F.display,fontSize:44,fontWeight:800,lineHeight:1,color:C.text}}>{cardio.length+strength.length}</div><div style={{fontFamily:F.ui,fontSize:13,fontWeight:500,color:C.muted,marginTop:3}}>sessions</div><div style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginTop:6}}>{strength.length} strength · {cardio.length} cardio</div></Card>
    </div>
    <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10,marginBottom:16}}>
      <Card onClick={onLog} accent={C.accent}><div style={{display:'flex',alignItems:'center',gap:10}}><div style={{width:36,height:36,borderRadius:12,background:C.accent+'18',display:'flex',alignItems:'center',justifyContent:'center',}}><Icon name='zap' size={17} color={C.accent}/></div><div><div style={{fontFamily:F.ui,fontWeight:700,fontSize:14,color:C.accent}}>Log workout</div><div style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginTop:1}}>Any activity</div></div></div></Card>
      <Card onClick={onChat} accent={C.cyan}><div style={{display:'flex',alignItems:'center',gap:10}}><div style={{width:36,height:36,borderRadius:12,background:C.cyan+'18',display:'flex',alignItems:'center',justifyContent:'center',}}><Icon name='message' size={17} color={C.cyan}/></div><div><div style={{fontFamily:F.ui,fontWeight:700,fontSize:14,color:C.cyan}}>Ask coach</div><div style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginTop:1}}>AI logs it</div></div></div></Card>
    </div>
    <div style={{display:'flex',justifyContent:'space-between',alignItems:'center'}}><Label style={{marginBottom:0}}>Recent activity</Label>{allRecent.length>0&&<button onClick={()=>setTab('log')} style={{background:'none',border:'none',fontFamily:F.ui,fontSize:13,fontWeight:600,color:C.accent,cursor:'pointer',padding:0}}>View all →</button>}</div>
    {allRecent.length===0?<Card style={{textAlign:'center',padding:28}}><div style={{fontFamily:F.ui,fontSize:15,color:C.muted}}>No sessions yet — add a goal and start training</div></Card>:allRecent.map((w,i)=>(<Card key={i} onClick={()=>setSelectedWorkout(w)} style={{marginBottom:8,padding:'13px 16px',cursor:'pointer'}}><div style={{display:'flex',alignItems:'center',gap:12}}><SportBadge sport={w.sport||'strength'} small/><div style={{flex:1,fontFamily:F.ui,fontSize:14,color:C.subtle,fontWeight:500,overflow:'hidden',whiteSpace:'nowrap',textOverflow:'ellipsis'}}>{w.notes||(w.kind==='strength'?`${w.exercises?.reduce((t,e)=>t+(e.sets?.length||0),0)||0} sets`:'—')}</div><div style={{textAlign:'right',flexShrink:0}}><div style={{fontFamily:F.display,fontSize:22,fontWeight:700,color:C.text}}>{fmtDur(w.duration)}</div><div style={{fontFamily:F.ui,fontSize:11,color:C.muted,fontWeight:500}}>{fmtDateSh(w.date)}</div></div></div></Card>))}
    {selectedWorkout&&<WorkoutDetailSheet workout={selectedWorkout} onClose={()=>setSelectedWorkout(null)} onViewLog={()=>{setSelectedWorkout(null);setTab('log');}}/>}
  </div>);}
