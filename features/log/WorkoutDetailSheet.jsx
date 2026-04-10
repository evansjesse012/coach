"use client";
import React from "react";
import { C, S, F } from '../../lib/theme.js';
import { Icon } from '../../lib/icons.js';
import { SPORT_META } from '../../lib/constants.js';
import { fmtDur, fmtDateSh } from '../../lib/utils.js';
import { Sheet, Label, Card, Pill, SportBadge } from '../../ui/primitives.js';

export function WorkoutDetailSheet({workout,onClose,onViewLog}){
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
      {workout.exercises.map((ex,i)=>{const et=ex.exerciseType||'weighted';return(<Card key={i} style={{marginBottom:8,padding:'12px 16px'}}>
        <div style={{fontFamily:F.ui,fontWeight:700,fontSize:15,color:C.text,marginBottom:6}}>{ex.name}</div>
        <div style={{display:'flex',gap:6,flexWrap:'wrap'}}>{ex.sets?.filter(s=>s.completed).map((s,j)=><span key={j} style={{fontFamily:F.mono,fontSize:12,color:C.subtle,background:C.elevated,borderRadius:8,padding:'4px 10px'}}>{et==='timed'?`${s.duration}s`:et==='banded'?`${s.band} ×${s.reps}`:s.weight>0?`${s.weight}×${s.reps}`:`${s.reps} reps`}</span>)}</div>
      </Card>);})}
    </div>}

    {workout.source==='healthkit'&&<div style={{display:'flex',alignItems:'center',gap:6,marginBottom:16}}><Icon name='watch' size={14} color={C.cyan}/><span style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:C.cyan}}>Imported from Apple Health</span></div>}

    {onViewLog&&<button onClick={onViewLog} style={{width:'100%',padding:'13px 16px',background:C.elevated,border:`1.5px solid ${C.border}`,borderRadius:14,fontFamily:F.ui,fontSize:14,fontWeight:600,color:C.accent,cursor:'pointer',transition:'all .15s',marginBottom:8}} onMouseEnter={e=>{e.currentTarget.style.background=C.accent+'10';e.currentTarget.style.borderColor=C.accent;}} onMouseLeave={e=>{e.currentTarget.style.background=C.elevated;e.currentTarget.style.borderColor=C.border;}}>View full log →</button>}
  </Sheet>);
}

export function BrickDetailSheet({brick,cardio,onDelete,onClose}){
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

    <button onClick={async()=>{if(onDelete){await onDelete(brick.id);onClose();}}} style={{width:'100%',padding:'13px 16px',background:'transparent',border:`1.5px solid ${C.red}50`,borderRadius:14,fontFamily:F.ui,fontSize:14,fontWeight:600,color:C.red,cursor:'pointer'}}>Unlink brick</button>
  </Sheet>);
}
