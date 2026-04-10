"use client";
import React, { useState, useEffect } from "react";
import { C, S, F } from '../../lib/theme.js';
import { Icon } from '../../lib/icons.js';
import { fmtDur, todayStr, uid, exSlug, computeExPR, isPRBetter, fmtPR } from '../../lib/utils.js';
import { Card, Btn, Label } from '../../ui/primitives.js';
import { toast } from '../../ui/toast.js';
import { confirmDialog } from '../../ui/confirm.js';
import { SetRow } from './SetRow.jsx';
import { ExerciseDetailSheet } from '../exercises/ExerciseDetailSheet.jsx';
import { ExercisePickerSheet } from '../exercises/ExerciseLibrary.jsx';

function RestTimer({seconds,onDone}){const[rem,setRem]=useState(seconds);useEffect(()=>{if(rem<=0){onDone();return;}const t=setTimeout(()=>setRem(r=>r-1),1000);return()=>clearTimeout(t);},[rem]);const pct=(rem/seconds)*100;return(<div style={{background:C.elevated,borderRadius:12,padding:'10px 16px',marginBottom:14,display:'flex',alignItems:'center',gap:14,boxShadow:S.sm}}><div style={{flex:1}}><div style={{display:'flex',justifyContent:'space-between',marginBottom:5}}><span style={{fontFamily:F.ui,fontSize:13,fontWeight:600,color:C.muted}}>Rest</span><span style={{fontFamily:F.display,fontSize:22,fontWeight:700,color:pct>33?C.cyan:C.yellow}}>{rem}s</span></div><div style={{height:4,background:C.border,borderRadius:4,overflow:'hidden'}}><div style={{height:'100%',width:`${pct}%`,background:`linear-gradient(90deg,${C.yellow},${C.cyan})`,borderRadius:4,transition:'width 1s linear'}}/></div></div><button onClick={onDone} style={{background:C.surface,border:`1.5px solid ${C.border}`,borderRadius:10,padding:'6px 13px',color:C.subtle,fontFamily:F.ui,fontSize:12,fontWeight:600,cursor:'pointer',flexShrink:0}}>Skip</button></div>);}

export function StrengthTracker({workout,strengthHistory,prs,onSave,onDiscard,onSaveTemplate,customExercises}){
  const[selectedExercise,setSelectedExercise]=useState(null);
  const[showAddExercise,setShowAddExercise]=useState(false);
  const[session]=useState(()=>({
    id:Date.now(), name:workout.label||workout.name||'Strength', startTime:Date.now(),
    exercises:(workout.exercises||[]).map(ex=>({
      slug:exSlug(ex.name), name:ex.name, exerciseType:ex.exerciseType||'weighted', rest:ex.rest||60, notes:ex.notes||'',
      sets:Array.from({length:ex.sets||3},(_,i)=>({
        setNum:i+1, completed:false,
        ...(ex.exerciseType==='timed' ? {duration:ex.duration||30} :
            ex.exerciseType==='banded' ? {band:ex.band||'medium',reps:ex.reps||10} :
            ex.exerciseType==='bodyweight'||ex.exerciseType==='cardio-drill' ? {reps:ex.reps||10} :
            {weight:ex.weight||0,reps:ex.reps||10})
      }))
    }))
  }));
  const[ex,setEx]=useState(session.exercises);const[restTimer,setRest]=useState(null);const[view,setView]=useState('active');
  const[elapsed,setElapsed]=useState(0);
  useEffect(()=>{const t=setInterval(()=>setElapsed(Math.floor((Date.now()-session.startTime)/1000)),1000);return()=>clearInterval(t);},[session.startTime]);
  const fmtElapsed=s=>{const m=Math.floor(s/60);const sec=s%60;return`${m}:${sec<10?'0':''}${sec}`;};
  const total=ex.reduce((s,e)=>s+e.sets.length,0);const done=ex.reduce((s,e)=>s+e.sets.filter(x=>x.completed).length,0);
  const getLastPerf=slug=>{for(const s of [...strengthHistory].reverse()){const e=s.exercises?.find(e=>(e.slug||exSlug(e.name||''))=== slug || e.exerciseId===slug);if(e?.sets?.length)return e.sets.filter(s=>s.completed);}return[];};
  const updateSet=(slug,idx,upd)=>setEx(prev=>prev.map(e=>e.slug!==slug?e:{...e,sets:e.sets.map((s,i)=>i!==idx?s:{...s,...upd})}));
  const completeSet=(slug,idx)=>{setEx(prev=>prev.map(e=>e.slug!==slug?e:{...e,sets:e.sets.map((s,i)=>i!==idx?s:{...s,completed:true})}));const exData=ex.find(e=>e.slug===slug);if(exData?.rest)setRest({slug,seconds:exData.rest,key:`${slug}-${idx}`});};
  const addSet=(slug)=>{setEx(prev=>prev.map(e=>{if(e.slug!==slug)return e;const lastSet=e.sets[e.sets.length-1]||{};const newSet={setNum:e.sets.length+1,completed:false,...(e.exerciseType==='timed'?{duration:lastSet.duration||30}:e.exerciseType==='banded'?{band:lastSet.band||'medium',reps:lastSet.reps||10}:e.exerciseType==='bodyweight'||e.exerciseType==='cardio-drill'?{reps:lastSet.reps||10}:{weight:lastSet.weight||0,reps:lastSet.reps||10})};return{...e,sets:[...e.sets,newSet]};}));};
  const removeExercise=async(slug)=>{const ok=await confirmDialog('Remove exercise?','This exercise will be removed from the workout.');if(ok)setEx(prev=>prev.filter(e=>e.slug!==slug));};
  const addExercises=(picked)=>{const newExs=picked.map(pEx=>({slug:exSlug(pEx.name),name:pEx.name,exerciseType:pEx.exerciseType||'weighted',rest:60,notes:'',sets:Array.from({length:3},(_,i)=>({setNum:i+1,completed:false,...(pEx.exerciseType==='timed'?{duration:30}:pEx.exerciseType==='banded'?{band:'medium',reps:10}:pEx.exerciseType==='bodyweight'||pEx.exerciseType==='cardio-drill'?{reps:10}:{weight:0,reps:10})}))}));setEx(prev=>[...prev,...newExs]);setShowAddExercise(false);};
  const handleDiscard=async()=>{const ok=await confirmDialog('Discard workout?','All progress will be lost.');if(ok)onDiscard();};

  if(view==='summary'){
    const dur=Math.round((Date.now()-session.startTime)/60000);
    const completed=ex.map(e=>({...e,sets:e.sets.filter(s=>s.completed)})).filter(e=>e.sets.length>0);
    const totalVol=completed.reduce((s,e)=>e.exerciseType==='weighted'?s+e.sets.reduce((ss,set)=>ss+((set.weight||0)*(set.reps||0)),0):s,0);
    const totalReps=completed.reduce((s,e)=>s+e.sets.reduce((ss,set)=>ss+(set.reps||0),0),0);
    const newPRs=[];
    for(const e of completed){
      const pr=computeExPR(e.exerciseType,e.sets);
      if(pr&&isPRBetter(pr,prs[e.slug])){newPRs.push({slug:e.slug,name:e.name,exerciseType:e.exerciseType,...pr});}
    }
    return(<div className="fade-up" style={{paddingBottom:40}}>
      <div style={{textAlign:'center',padding:'24px 0 20px'}}><div style={{marginBottom:8}}><Icon name='star' size={48} color={C.green}/></div><div style={{fontFamily:F.display,fontSize:32,fontWeight:800,color:C.text}}>Workout done!</div><div style={{fontFamily:F.ui,fontSize:15,color:C.subtle,marginTop:4}}>{session.name}</div></div>
      <div style={{display:'grid',gridTemplateColumns:'repeat(3,1fr)',gap:10,marginBottom:16}}>{[
        {l:'Time',v:fmtDur(dur),c:C.cyan},
        {l:'Sets',v:completed.reduce((s,e)=>s+e.sets.length,0),c:C.text},
        {l:totalVol>0?'Volume':'Reps',v:totalVol>0?`${(totalVol/1000).toFixed(1)}k`:totalReps,c:C.text}
      ].map(({l,v,c})=><Card key={l} style={{textAlign:'center',padding:'14px 8px'}}><div style={{fontFamily:F.display,fontSize:28,fontWeight:700,color:c,lineHeight:1}}>{v}</div><div style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginTop:5,fontWeight:500}}>{l}</div></Card>)}</div>
      {newPRs.length>0&&<Card accent={C.yellow} style={{marginBottom:14}}><Label style={{color:C.yellow,marginBottom:10}}>New Personal Records</Label>{newPRs.map((pr,i)=><div key={i} style={{display:'flex',justifyContent:'space-between',padding:'7px 0',borderTop:i>0?`1px solid ${C.border}`:'none'}}><span style={{fontFamily:F.ui,fontSize:15,fontWeight:500,color:C.text}}>{pr.name}</span><span style={{fontFamily:F.mono,fontSize:14,color:C.yellow}}>{fmtPR(pr)}</span></div>)}</Card>}
      <Label>Breakdown</Label>{completed.map((e,i)=><Card key={i} style={{marginBottom:8,padding:'13px 16px'}}><div style={{fontFamily:F.ui,fontWeight:600,fontSize:15,marginBottom:8,color:C.text}}>{e.name}</div><div style={{display:'flex',gap:7,flexWrap:'wrap'}}>{e.sets.map((s,j)=><span key={j} style={{fontFamily:F.mono,fontSize:12,color:C.subtle,background:C.elevated,borderRadius:8,padding:'4px 10px'}}>{e.exerciseType==='timed'?`${s.duration}s`:e.exerciseType==='banded'?`${s.band} ×${s.reps}`:s.weight>0?`${s.weight}×${s.reps}`:`${s.reps} reps`}</span>)}</div></Card>)}
      <div style={{display:'flex',gap:10,marginTop:16}}><Btn onClick={handleDiscard} outline style={{flex:1}}>Discard</Btn><Btn onClick={()=>onSave(completed,dur,newPRs)} color={C.green} style={{flex:2}}>Save workout</Btn></div>
      {onSaveTemplate&&<button onClick={()=>{const tpl={id:uid(),name:session.name,exercises:ex.map(e=>({name:e.name,slug:e.slug,exerciseType:e.exerciseType,sets:e.sets.length,reps:e.sets[0]?.reps||10,weight:e.sets[0]?.weight||0,duration:e.sets[0]?.duration||30,band:e.sets[0]?.band||'medium',rest:e.rest||60,notes:e.notes||''})),createdAt:todayStr(),lastUsed:null};onSaveTemplate(tpl);toast.success('Template saved');}} style={{width:'100%',marginTop:12,padding:'12px',borderRadius:14,background:C.elevated,border:`2px dashed ${C.border}`,fontFamily:F.ui,fontSize:14,fontWeight:600,color:C.accent,cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center',gap:6}}><Icon name='clipboard' size={16} color={C.accent}/> Save as Template</button>}
    </div>);
  }

  const headerCols = eType => eType==='timed'?{cols:'28px 1fr 80px 44px',heads:['#','Prev','Secs','']} : eType==='bodyweight'||eType==='cardio-drill'?{cols:'28px 1fr 80px 44px',heads:['#','Prev','Reps','']} : eType==='banded'?{cols:'28px 1fr 60px 60px 44px',heads:['#','Prev','Band','Reps','']} : {cols:'28px 1fr 60px 60px 44px',heads:['#','Prev','Lbs','Reps','']};

  return(<div className="fade-up" style={{paddingBottom:88}}>
    <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:14}}>
      <div>
        <div style={{fontFamily:F.display,fontSize:22,fontWeight:800,color:C.text}}>{session.name}</div>
        <div style={{display:'flex',gap:12,marginTop:2}}>
          <span style={{fontFamily:F.mono,fontSize:14,color:C.cyan,fontWeight:600}}>{fmtElapsed(elapsed)}</span>
          <span style={{fontFamily:F.ui,fontSize:14,color:C.muted}}>{done}/{total} sets</span>
        </div>
      </div>
      <button onClick={handleDiscard} style={{background:C.elevated,border:'none',borderRadius:10,padding:'7px 14px',color:C.subtle,fontFamily:F.ui,fontSize:13,fontWeight:500,cursor:'pointer'}}>Discard</button>
    </div>
    <div style={{height:5,background:C.border,borderRadius:4,overflow:'hidden',marginBottom:16}}><div style={{height:'100%',width:`${total>0?(done/total)*100:0}%`,background:`linear-gradient(90deg,${C.accent},${C.green})`,borderRadius:4,transition:'width .3s'}}/></div>
    {restTimer&&<RestTimer key={restTimer.key} seconds={restTimer.seconds} onDone={()=>setRest(null)}/>}
    {ex.map(exData=>{const lastPerf=getLastPerf(exData.slug);const allDone=exData.sets.every(s=>s.completed);const hdr=headerCols(exData.exerciseType);return(<Card key={exData.slug} style={{marginBottom:12}}>
      <div style={{display:'flex',justifyContent:'space-between',alignItems:'flex-start',marginBottom:10}}><div><div onClick={()=>setSelectedExercise(exData.name)} style={{fontFamily:F.ui,fontWeight:700,fontSize:16,color:allDone?C.green:C.accent,cursor:'pointer'}}>{exData.name}</div>{exData.notes&&<div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:2}}>{exData.notes}</div>}</div><div style={{display:'flex',alignItems:'center',gap:6}}><span style={{fontFamily:F.mono,fontSize:12,color:allDone?C.green:C.muted}}>{exData.sets.filter(s=>s.completed).length}/{exData.sets.length}</span><button onClick={()=>removeExercise(exData.slug)} style={{width:26,height:26,borderRadius:8,background:C.elevated,border:'none',cursor:'pointer',color:C.muted,fontSize:12,display:'flex',alignItems:'center',justifyContent:'center'}} title="Remove exercise">✕</button></div></div>
      <div style={{display:'grid',gridTemplateColumns:hdr.cols,gap:6,marginBottom:6,padding:'0 4px'}}>{hdr.heads.map((h,i)=><span key={i} style={{fontFamily:F.ui,fontSize:11,fontWeight:600,color:C.muted,textAlign:i>=2?'center':'left'}}>{h}</span>)}</div>
      {exData.sets.map((set,i)=><SetRow key={i} set={set} setNum={i+1} prev={lastPerf[i]} exerciseType={exData.exerciseType} onUpdate={u=>updateSet(exData.slug,i,u)} onComplete={()=>completeSet(exData.slug,i)}/>)}
      <button onClick={()=>addSet(exData.slug)} style={{width:'100%',padding:'8px',borderRadius:10,background:C.elevated,border:`1.5px dashed ${C.border}`,fontFamily:F.ui,fontSize:12,fontWeight:600,color:C.accent,cursor:'pointer',marginTop:4}}>+ Add Set{exData.rest?` (${Math.floor(exData.rest/60)}:${(exData.rest%60).toString().padStart(2,'0')})`:''}</button>
    </Card>);})}
    <button onClick={()=>setShowAddExercise(true)} style={{width:'100%',padding:'12px',borderRadius:14,background:C.elevated,border:`2px dashed ${C.border}`,fontFamily:F.ui,fontSize:14,fontWeight:600,color:C.accent,cursor:'pointer',marginBottom:16,display:'flex',alignItems:'center',justifyContent:'center',gap:6}}><Icon name='plus' size={16} color={C.accent}/> Add Exercise</button>
    <div style={{position:'fixed',bottom:24,left:'50%',transform:'translateX(-50%)',width:'calc(100% - 32px)',maxWidth:468,zIndex:20}}><Btn onClick={()=>done>0&&setView('summary')} color={done===total?C.green:C.accent} disabled={done===0} style={{width:'100%',padding:15,fontSize:17,borderRadius:16,boxShadow:S.md}}>{done===total?'Finish workout ✓':`Finish (${done}/${total} sets)`}</Btn></div>
    {selectedExercise&&<ExerciseDetailSheet exerciseName={selectedExercise} strengthHistory={strengthHistory} prs={prs} onClose={()=>setSelectedExercise(null)}/>}
    {showAddExercise&&<ExercisePickerSheet customExercises={customExercises} onPick={addExercises} onClose={()=>setShowAddExercise(false)} multi/>}
  </div>);
}
