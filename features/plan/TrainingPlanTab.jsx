"use client";
import React, { useState } from "react";
import { C, S, F } from '../../lib/theme.js';
import { Icon } from '../../lib/icons.js';
import { SPORT_META, presetById } from '../../lib/constants.js';
import { fmtDur, fmtDateSh, daysUntil, todayStr, getDayName } from '../../lib/utils.js';
import { computeWeekAdherence, computeMultiWeekPatterns } from '../../ai/adherence.js';
import { Card, Btn, Inp, Label, Pill, Sheet, SportBadge } from '../../ui/primitives.js';
import { PlanBuilderSheet, _planBuilderStartedAt } from './PlanBuilderSheet.jsx';
import { EndPlanSheet } from './EndPlanSheet.jsx';
import { StrengthTracker } from '../strength/StrengthTracker.jsx';

function generateWeeklyPlan(events) {
  const active=events.filter(e=>!e.completed);
  if (!active.length) return [];
  const types=[...new Set(active.map(e=>presetById(e.presetId).planType))];
  const hasTri=types.includes('tri'),hasRun=types.includes('run'),hasStr=types.includes('strength');
  if (hasTri) return [
    {day:'Monday',sessions:[{type:'strength',label:'Strength A',notes:'Lower focus',fuel:'Pre: light snack',sport:'strength'}]},
    {day:'Tuesday',sessions:[{type:'run',sport:'run',duration:45,label:'Easy Run',notes:'Zone 2'},{type:'swim',sport:'swim',duration:30,label:'Swim',notes:'Technique drills'}]},
    {day:'Wednesday',sessions:[{type:'strength',label:'Strength B',notes:'Upper focus',sport:'strength'}]},
    {day:'Thursday',sessions:[{type:'bike',sport:'bike',duration:60,label:'Zone 2 Ride',notes:'Steady aerobic'},{type:'run',sport:'run',duration:20,label:'Brick Run',notes:'Off the bike'}]},
    {day:'Friday',sessions:[]},
    {day:'Saturday',sessions:[{type:'bike',sport:'bike',duration:90,label:'Long Ride',notes:'Build endurance'}]},
    {day:'Sunday',sessions:[{type:'run',sport:'run',duration:75,label:'Long Run',notes:'Easy aerobic build'}]},
  ];
  if (hasRun) return [
    {day:'Monday',sessions:[{type:'strength',label:'Strength',notes:'Strength + mobility',sport:'strength'}]},
    {day:'Tuesday',sessions:[{type:'run',sport:'run',duration:40,label:'Easy Run',notes:'Comfortable'}]},
    {day:'Wednesday',sessions:[{type:'run',sport:'run',duration:50,label:'Tempo Run',notes:'Comfortably hard'}]},
    {day:'Thursday',sessions:[{type:'strength',label:'Strength',notes:'Upper + core',sport:'strength'}]},
    {day:'Friday',sessions:[]},
    {day:'Saturday',sessions:[{type:'run',sport:'run',duration:90,label:'Long Run',notes:'Easy pace'}]},
    {day:'Sunday',sessions:[{type:'run',sport:'run',duration:30,label:'Recovery Run',notes:'Very easy'}]},
  ];
  if (hasStr) return [
    {day:'Monday',sessions:[{type:'strength',label:'Strength A',notes:'Lower body',sport:'strength'}]},
    {day:'Tuesday',sessions:[{type:'other',sport:'other',duration:30,label:'Conditioning',notes:'Easy cardio'}]},
    {day:'Wednesday',sessions:[{type:'strength',label:'Strength B',notes:'Upper + pull',sport:'strength'}]},
    {day:'Thursday',sessions:[{type:'other',sport:'other',duration:30,label:'Cardio',notes:'Light cardio'}]},
    {day:'Friday',sessions:[{type:'strength',label:'Strength C',notes:'Full body',sport:'strength'}]},
    {day:'Saturday',sessions:[]},{day:'Sunday',sessions:[]},
  ];
  return ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'].map(day=>({day,sessions:[]}));
}

export function TrainingPlanTab({events,cardio,strengthHistory,prs,onSaveStrength,activeWO,setActiveWO,trainingPlan,onPlanCreated,onWeekGenerated,onAddEvent,onDisruption,onDeletePlan,appState,onSaveTemplate,customExercises}){
  const[tracker,setTracker]=useState(activeWO&&activeWO.exercises?activeWO:null);
  const[createStep,setCreateStep]=useState(null);
  const[selectedGoal,setSelectedGoal]=useState(null);
  const[planBuilder,setPlanBuilder]=useState(null);
  const[expandedPhase,setExpandedPhase]=useState(null);
  const[showFuel,setShowFuel]=useState(null);
  const[showEndPlan,setShowEndPlan]=useState(false);
  const active=events.filter(e=>!e.completed);const plan=generateWeeklyPlan(events);const today=getDayName();
  const startStrength=sess=>{if(sess?.exercises)setTracker(sess);};
  const handleSave=(completedEx,dur,newPRs)=>{onSaveStrength(completedEx,dur,newPRs,tracker);setTracker(null);setActiveWO(null);};
  const handleDiscard=()=>{setTracker(null);setActiveWO(null);};

  const handleSelectGoal=(e)=>{setSelectedGoal(e);setCreateStep('confirm');};
  const handleWeekGenerated=(wp)=>{onWeekGenerated(wp);setPlanBuilder(null);};

  if(tracker)return (<div style={{paddingBottom:48}}><button onClick={()=>setTracker(null)} style={{background:'none',border:'none',color:C.muted,fontFamily:F.ui,fontSize:13,fontWeight:500,cursor:'pointer',marginBottom:16,padding:0,display:'flex',alignItems:'center',gap:4}}><Icon name='arrowLeft' size={14} color={C.muted}/> Back to plan</button><StrengthTracker workout={tracker} strengthHistory={strengthHistory} prs={prs} onSave={handleSave} onDiscard={handleDiscard} onSaveTemplate={onSaveTemplate} customExercises={customExercises}/></div>);

  if(!active.length)return (<div style={{paddingBottom:48}}><Card style={{textAlign:'center',padding:36}}><div style={{marginBottom:12}}><Icon name='calendar' size={36} color={C.muted}/></div><div style={{fontFamily:F.display,fontSize:20,fontWeight:700,color:C.text,marginBottom:8}}>No active goals</div><div style={{fontFamily:F.ui,fontSize:15,color:C.subtle,lineHeight:1.7}}>Add a goal from the Goals tab first, then come back to create your training plan.</div></Card></div>);

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

  if(!trainingPlan) return (<div style={{paddingBottom:48}}>
    <Card accent={C.accent} style={{textAlign:'center',padding:32,marginBottom:20}}>
      <div style={{marginBottom:12}}><Icon name='calendar' size={36} color={C.accent}/></div>
      <div style={{fontFamily:F.display,fontSize:22,fontWeight:800,color:C.text,marginBottom:8}}>Create Your Training Plan</div>
      <div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,lineHeight:1.7,marginBottom:20}}>Your AI coach will design a personalized, periodized training plan based on your goal, fitness level, and available time.</div>
      <Btn onClick={()=>setCreateStep('select')} color={C.accent} style={{width:'100%',padding:15,fontSize:16}}>Build my plan</Btn>
    </Card>
    <CreatePlanSheet/>
    {planBuilder&&<PlanBuilderSheet goal={planBuilder.goal} mode={planBuilder.mode} appState={appState} onPlanCreated={onPlanCreated} onWeekGenerated={handleWeekGenerated} onClose={()=>setPlanBuilder(null)}/>}
  </div>);

  // Has periodized plan — full plan UI
  const tp=trainingPlan;
  const currentPhase=tp.phases?.find(p=>p.number===tp.currentPhase)||tp.phases?.[0];
  const weekPlan=tp.weeklyPlans?.[String(tp.currentWeek)]||null;
  const weekAdherence=weekPlan?computeWeekAdherence(tp,tp.currentWeek,cardio,strengthHistory):null;
  const multiWeekPatterns=tp.currentWeek>1?computeMultiWeekPatterns(tp,tp.currentWeek,cardio,strengthHistory):[];
  const weeksToRace=tp.raceDate?Math.max(0,Math.ceil((new Date(tp.raceDate+'T12:00:00')-new Date())/604800000)):null;
  const phaseColors=['#E8604C','#2BAFC4','#F0A830','#8B6FE8','#2ABF84','#4890D8'];

  return (<div style={{paddingBottom:48}}>
    <div style={{marginBottom:20}}>
      <div style={{display:'flex',justifyContent:'space-between',alignItems:'flex-start',marginBottom:12}}>
        <div>
          <div style={{fontFamily:F.display,fontSize:22,fontWeight:800,color:C.text,letterSpacing:'-.01em'}}>{tp.raceName}</div>
          <div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:2}}>Week {tp.currentWeek} of {tp.totalWeeks}{weeksToRace!==null?` · ${weeksToRace} weeks to race`:''}</div>
        </div>
      </div>
      <div style={{display:'flex',gap:3,height:8,borderRadius:4,overflow:'hidden',marginBottom:10}}>
        {tp.phases?.map((ph,i)=>{const isCurrent=ph.number===tp.currentPhase;const isPast=ph.number<tp.currentPhase;return (
          <div key={ph.number} style={{flex:ph.weeks,background:isCurrent?phaseColors[i%phaseColors.length]:(isPast?phaseColors[i%phaseColors.length]+'60':C.border),borderRadius:2,transition:'all .3s',position:'relative'}}>
            {isCurrent&&<div style={{position:'absolute',inset:0,background:`linear-gradient(90deg,${phaseColors[i%phaseColors.length]},${phaseColors[i%phaseColors.length]}CC)`,borderRadius:2}}/>}
          </div>
        );})}
      </div>
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

    {activeWO&&activeWO.exercises&&<Card accent={C.yellow} onClick={()=>setTracker(activeWO)} style={{marginBottom:16}}><div style={{display:'flex',alignItems:'center',gap:10}}><Icon name='timer' size={20} color={C.yellow}/><div><div style={{fontFamily:F.ui,fontWeight:600,fontSize:15,color:C.yellow}}>Workout in progress</div><div style={{fontFamily:F.ui,fontSize:13,color:C.subtle,marginTop:1}}>{activeWO.label||activeWO.name||'Strength'} · tap to continue</div></div><span style={{marginLeft:'auto',color:C.yellow}}>→</span></div></Card>}

    <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:weekAdherence?6:10}}>
      <Label style={{marginBottom:0}}>Week {tp.currentWeek}{weekPlan?` · ${weekPlan.focusOfWeek}`:''}</Label>
    </div>

    {!weekPlan?<Card accent={C.accent} onClick={()=>setPlanBuilder({goal:{...events.find(e=>e.id===tp.goalId)||{name:tp.raceName},_weekNum:tp.currentWeek,_phaseNum:tp.currentPhase},mode:'week'})} style={{textAlign:'center',padding:28,marginBottom:16}}>
      <div style={{marginBottom:8}}><Icon name='calendar' size={28} color={C.accent}/></div>
      <div style={{fontFamily:F.display,fontSize:18,fontWeight:700,color:C.accent,marginBottom:4}}>Generate this week</div>
      <div style={{fontFamily:F.ui,fontSize:13,color:C.subtle}}>Your coach will create sessions based on your current phase and recent training.</div>
    </Card>
    :weekPlan.sessions?.map((dayObj,di)=>{
      const isToday=dayObj.day===today;
      const daySessions=dayObj.sessions||[];
      return (<div key={di} style={{marginBottom:10}}>
        <div style={{display:'flex',alignItems:'center',gap:8,marginBottom:6}}>
          <span style={{fontFamily:F.display,fontSize:16,fontWeight:700,color:isToday?C.accent:C.subtle}}>{dayObj.day}</span>
          {isToday&&<Pill color={C.accent} small>Today</Pill>}
          {dayObj.isRest&&<span style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginLeft:'auto'}}>Rest</span>}
        </div>
        {daySessions.length>0&&<Card style={{padding:'4px 6px',borderColor:isToday?C.accent+'30':C.border}}>
          {daySessions.map((sess,si)=>{
            const sport=SPORT_META[sess.type]||SPORT_META.other;
            const isStr=sess.type==='strength';
            const dayIndex=['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'].indexOf(dayObj.day);
            const weekStart=new Date();weekStart.setDate(weekStart.getDate()-((weekStart.getDay()+6)%7));weekStart.setHours(0,0,0,0);
            const dayDate=new Date(weekStart);dayDate.setDate(dayDate.getDate()+dayIndex);
            const dayDateStr=dayDate.toISOString().split('T')[0];
            const dayCardio=cardio.filter(w=>w.date===dayDateStr);
            const dayStrength=strengthHistory.filter(s=>s.date===dayDateStr);
            const done=isStr?dayStrength.some(sh=>sh.name===sess.label||sh.templateId===sess.templateId):dayCardio.some(w=>w.sport===sess.type);
            return (<div key={si}>
              <div onClick={isStr&&sess.exercises&&!done?()=>startStrength(sess):undefined} style={{display:'flex',alignItems:'flex-start',gap:12,padding:'12px 10px',borderRadius:12,cursor:isStr&&sess.exercises&&!done?'pointer':'default',borderBottom:si<daySessions.length-1?`1px solid ${C.border}`:'none',background:done?C.green+'08':'transparent'}}>
                <div style={{width:36,height:36,borderRadius:12,background:done?C.green+'20':sport.color+'20',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,marginTop:2}}>
                  {done?<Icon name='check' size={18} color={C.green}/>:<Icon name={isStr?'dumbbell':sport.icon} size={18} color={sport.color}/>}
                </div>
                <div style={{flex:1}}>
                  <div style={{fontFamily:F.ui,fontWeight:600,fontSize:15,color:done?C.green:C.text}}>{sess.label}</div>
                  {sess.purpose&&!done&&<div style={{fontFamily:F.ui,fontSize:12,color:C.muted,fontStyle:'italic',marginTop:3}}>{sess.purpose}</div>}
                  {sess.workout&&!done&&<div style={{fontFamily:F.mono,fontSize:12,color:C.text,marginTop:4,padding:'8px 10px',background:C.elevated,borderRadius:8,border:`1px solid ${C.border}`,lineHeight:1.6,whiteSpace:'pre-wrap'}}>{sess.workout}</div>}
                </div>
                <div style={{textAlign:'right',flexShrink:0}}>
                  {sess.duration&&<div style={{fontFamily:F.mono,fontSize:13,color:done?C.green:C.muted}}>{fmtDur(sess.duration)}</div>}
                  {isStr&&sess.exercises&&!done&&<div style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:C.green,marginTop:4}}>Start →</div>}
                </div>
              </div>
            </div>);
          })}
        </Card>}
      </div>);
    })}

    <div style={{marginTop:32,marginBottom:16}}>
      <button onClick={()=>setShowEndPlan(true)} style={{background:'none',border:`1.5px solid ${C.border}`,borderRadius:12,padding:'11px 16px',color:C.muted,fontFamily:F.ui,fontSize:13,fontWeight:500,cursor:'pointer',width:'100%',transition:'all .15s'}} onMouseEnter={e=>{e.currentTarget.style.borderColor=C.red;e.currentTarget.style.color=C.red;}} onMouseLeave={e=>{e.currentTarget.style.borderColor=C.border;e.currentTarget.style.color=C.muted;}}>End training plan</button>
    </div>
    {showEndPlan&&<EndPlanSheet trainingPlan={tp} cardio={cardio} strengthHistory={strengthHistory} onEnd={(reason,notes)=>{onDeletePlan(reason,notes);setShowEndPlan(false);}} onClose={()=>setShowEndPlan(false)}/>}
    {planBuilder&&<PlanBuilderSheet goal={planBuilder.goal} mode={planBuilder.mode} appState={appState} onPlanCreated={onPlanCreated} onWeekGenerated={handleWeekGenerated} onClose={()=>setPlanBuilder(null)}/>}
  </div>);
}
