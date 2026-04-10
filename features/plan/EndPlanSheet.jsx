"use client";
import React, { useState } from "react";
import { C, S, F } from '../../lib/theme.js';
import { Icon } from '../../lib/icons.js';
import { computeWeekAdherence } from '../../ai/adherence.js';
import { Sheet, Btn, Textarea, Label, Card, Pill } from '../../ui/primitives.js';

export function EndPlanSheet({trainingPlan,cardio,strengthHistory,onEnd,onClose}){
  const[reason,setReason]=useState(null);
  const[notes,setNotes]=useState('');
  const tp=trainingPlan;
  const reasons=[
    {id:'completed',label:'Completed the race/goal',icon:'trophy',color:C.green},
    {id:'new_goal',label:'Switching to a new goal',icon:'target',color:C.cyan},
    {id:'injury',label:'Injury or health issue',icon:'alert',color:C.red},
    {id:'not_working',label:'Plan wasn\'t working',icon:'chart',color:C.yellow},
    {id:'life',label:'Life got in the way',icon:'calendar',color:C.purple},
    {id:'other',label:'Other',icon:'message',color:C.muted},
  ];

  const weekNums=Object.keys(tp.weeklyPlans||{}).map(Number).sort((a,b)=>a-b);
  const weekReviews=weekNums.map(w=>computeWeekAdherence(tp,w,cardio,strengthHistory)).filter(Boolean);
  const totalPrescribed=weekReviews.reduce((t,r)=>t+r.prescribed,0);
  const totalCompleted=weekReviews.reduce((t,r)=>t+r.completed,0);
  const totalMissed=weekReviews.reduce((t,r)=>t+r.missed,0);
  const overallAdherence=totalPrescribed>0?Math.round((totalCompleted+weekReviews.reduce((t,r)=>t+r.shortened*0.5,0))/totalPrescribed*100):0;

  return(<Sheet onClose={onClose} title="End training plan">
    <Card style={{marginBottom:16,padding:'14px 16px',background:C.elevated}}>
      <div style={{fontFamily:F.display,fontSize:16,fontWeight:700,color:C.text,marginBottom:6}}>{tp.raceName}</div>
      <div style={{display:'flex',gap:12,flexWrap:'wrap'}}>
        <div style={{fontFamily:F.ui,fontSize:12,color:C.muted}}>Week {tp.currentWeek}/{tp.totalWeeks}</div>
        {weekReviews.length>0&&<div style={{fontFamily:F.ui,fontSize:12,color:overallAdherence>=75?C.green:overallAdherence>=50?C.yellow:C.red,fontWeight:600}}>{overallAdherence}% adherence</div>}
        <div style={{fontFamily:F.ui,fontSize:12,color:C.muted}}>{weekReviews.length} weeks tracked</div>
      </div>
    </Card>

    <Label>Why are you ending this plan?</Label>
    <div style={{display:'flex',flexDirection:'column',gap:8,marginBottom:16}}>
      {reasons.map(r=>{const sel=reason===r.id;return(
        <div key={r.id} onClick={()=>setReason(r.id)} style={{display:'flex',alignItems:'center',gap:12,padding:'12px 16px',background:sel?r.color+'10':C.elevated,border:`1.5px solid ${sel?r.color:C.border}`,borderRadius:14,cursor:'pointer',transition:'all .15s'}}>
          <div style={{width:32,height:32,borderRadius:10,background:r.color+'18',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}><Icon name={r.icon} size={16} color={r.color}/></div>
          <span style={{fontFamily:F.ui,fontSize:14,fontWeight:sel?600:500,color:sel?r.color:C.text}}>{r.label}</span>
          {sel&&<div style={{marginLeft:'auto',width:8,height:8,borderRadius:'50%',background:r.color}}/>}
        </div>
      );})}
    </div>

    <Label>Notes (optional)</Label>
    <Textarea placeholder="Anything your coach should remember about this plan..." value={notes} onChange={e=>setNotes(e.target.value)} rows={3} style={{marginBottom:20}}/>

    <div style={{fontFamily:F.ui,fontSize:13,color:C.subtle,lineHeight:1.6,marginBottom:16,padding:'10px 14px',background:C.elevated,borderRadius:12}}>
      Your coach will archive this plan and remember what happened — adherence, phases completed, and why it ended. Your workout history is not affected.
    </div>

    <Btn onClick={()=>{if(!reason)return;onEnd(reason,notes);}} color={reason?C.accent:C.muted} style={{width:'100%',padding:15,fontSize:16,opacity:reason?1:0.5,cursor:reason?'pointer':'not-allowed'}}>
      End plan{reason==='completed'?' & celebrate':''}
    </Btn>
  </Sheet>);
}
