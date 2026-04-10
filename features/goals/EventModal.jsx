"use client";
import React, { useState } from "react";
import { C, S, F } from '../../lib/theme.js';
import { Icon } from '../../lib/icons.js';
import { EVENT_PRESETS, presetById } from '../../lib/constants.js';
import { uid, todayStr } from '../../lib/utils.js';
import { Sheet, Btn, Inp, Label } from '../../ui/primitives.js';
import { confirmDialog } from '../../ui/confirm.js';

export function EventModal({event,onSave,onClose,onDelete}){
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
