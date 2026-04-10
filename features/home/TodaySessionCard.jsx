"use client";
import React from "react";
import { C, S, F } from '../../lib/theme.js';
import { Icon } from '../../lib/icons.js';
import { SPORT_META } from '../../lib/constants.js';
import { todayStr, getDayName, fmtDur } from '../../lib/utils.js';
import { Card, Btn, Pill } from '../../ui/primitives.js';

export function TodaySessionCard({ plan, cardio, strength, onStartStrength, setTab, trainingPlan }) {
  const today=getDayName(); const td=todayStr();
  const todayC=cardio.filter(w=>w.date===td); const todayS=strength.filter(s=>s.date===td);

  // Try periodized plan first
  const tp=trainingPlan;
  const weekPlan=tp?.weeklyPlans?.[String(tp.currentWeek)];
  const tpToday=weekPlan?.sessions?.find(d=>d.day===today);

  if(tpToday){
    const daySessions=tpToday.sessions||[];
    if(tpToday.isRest||!daySessions.length) return (<Card style={{marginBottom:16,background:`linear-gradient(135deg,${C.elevated},${C.card})`,borderColor:C.border}}><div style={{display:'flex',alignItems:'center',gap:12}}><div style={{width:44,height:44,borderRadius:14,background:C.elevated,display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name='rest' size={22} color={C.muted}/></div><div><div style={{fontFamily:F.display,fontSize:18,fontWeight:700,color:C.text}}>Rest Day</div><div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,marginTop:2}}>Recovery is training. Let the body adapt.</div></div></div></Card>);
    const isSessDone=s=>{if(s.type==='brick')return(s.legs||[]).every(l=>todayC.some(w=>w.sport===l.sport));if(s.type==='strength')return todayS.some(sh=>sh.name===s.label||sh.templateId===s.templateId);return todayC.some(w=>w.sport===s.type);};
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
        return (<div key={i} onClick={isStr&&!done&&sess.exercises?()=>{onStartStrength(sess);setTab('plan');}:(!done?()=>setTab('log'):undefined)} style={{display:'flex',alignItems:'center',gap:12,padding:'11px 14px',background:done?C.green+'0A':C.elevated,borderRadius:12,border:`1.5px solid ${done?C.green+'44':accent+'30'}`,cursor:!done?'pointer':'default',transition:'all .15s'}}>
          <div style={{width:36,height:36,borderRadius:12,background:accent+'20',display:'flex',alignItems:'center',justifyContent:'center'}}>{done?<Icon name='check' size={17} color={C.green}/>:<Icon name={isStr?'dumbbell':sport.icon} size={17} color={accent}/>}</div>
          <div style={{flex:1}}>
            <div style={{display:'flex',alignItems:'center',gap:6}}>{sess.priority&&<div style={{width:6,height:6,borderRadius:'50%',background:sess.priority==='red'?C.accent:C.yellow}}/>}<div style={{fontFamily:F.ui,fontWeight:600,fontSize:15,color:done?C.green:C.text}}>{sess.label}</div></div>
            {sess.purpose&&!done&&<div style={{fontFamily:F.ui,fontSize:12,color:C.muted,fontStyle:'italic',marginTop:2}}>{sess.purpose}</div>}
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
  const allDone=todayPlan.sessions.every(s=>s.type==='strength'?todayS.some(sh=>sh.name===s.label||sh.templateId===s.templateId):todayC.some(w=>w.sport===s.sport));
  return (<Card accent={allDone?C.green:C.accent} style={{marginBottom:16}}><div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:12}}><div><div style={{fontFamily:F.display,fontSize:18,fontWeight:700,color:allDone?C.green:C.accent}}>{allDone?'✓ Today complete':"Today's sessions"}</div><div style={{fontFamily:F.ui,fontSize:13,color:C.subtle,marginTop:1}}>{getDayName()}</div></div>{allDone&&<Pill color={C.green}>Done</Pill>}</div><div style={{display:'flex',flexDirection:'column',gap:8}}>{todayPlan.sessions.map((sess,i)=>{const isStr=sess.type==='strength';const sport=SPORT_META[sess.sport||'other'];const done=isStr?todayS.some(s=>s.name===sess.label||s.templateId===sess.templateId):todayC.some(w=>w.sport===sess.sport);const accent=done?C.green:(isStr?C.green:sport.color);return (<div key={i} onClick={isStr&&!done&&sess.exercises?()=>{onStartStrength(sess);setTab('plan');}:(!done?()=>setTab('log'):undefined)} style={{display:'flex',alignItems:'center',gap:12,padding:'11px 14px',background:done?C.green+'0A':C.elevated,borderRadius:12,border:`1.5px solid ${done?C.green+'44':accent+'30'}`,cursor:!done?'pointer':'default',transition:'all .15s'}}><div style={{width:36,height:36,borderRadius:12,background:accent+'20',display:'flex',alignItems:'center',justifyContent:'center',}}>{done?<Icon name='check' size={17} color={C.green}/>:(isStr?<Icon name='dumbbell' size={17} color={accent}/>:<Icon name={sport.icon} size={17} color={accent}/>)}</div><div style={{flex:1}}><div style={{fontFamily:F.ui,fontWeight:600,fontSize:15,color:done?C.green:C.text}}>{sess.label}</div><div style={{fontFamily:F.ui,fontSize:13,color:C.subtle,marginTop:1,lineHeight:1.4}}>{sess.notes}</div></div>{!isStr&&sess.duration&&<div style={{fontFamily:F.mono,fontSize:12,color:C.muted}}>{fmtDur(sess.duration)}</div>}{isStr&&!done&&sess.exercises&&<div style={{fontFamily:F.ui,fontSize:13,fontWeight:600,color:C.green}}>Start →</div>}{!isStr&&!done&&<div style={{fontFamily:F.ui,fontSize:13,fontWeight:600,color:sport.color}}>Log →</div>}</div>);})}</div></Card>);
}
