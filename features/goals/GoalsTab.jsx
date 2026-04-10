"use client";
import React from "react";
import { C, S, F } from '../../lib/theme.js';
import { Icon } from '../../lib/icons.js';
import { presetById, EVENT_PRESETS } from '../../lib/constants.js';
import { fmtDateSh, daysUntil } from '../../lib/utils.js';
import { Card, Pill, Btn, Label, SportBadge } from '../../ui/primitives.js';

export function GoalsTab({events,onViewGoal,onAddEvent,onAddEventChat}){
  const upcoming=events.filter(e=>!e.completed).sort((a,b)=>(a.date||'9999').localeCompare(b.date||'9999'));
  const pastRaces=events.filter(e=>e.completed&&e.mode==='race').sort((a,b)=>(b.date||'').localeCompare(a.date||''));
  const prs=events.filter(e=>e.completed&&e.mode==='pr').sort((a,b)=>(b.date||'').localeCompare(a.date||''));
  const completed=events.filter(e=>e.completed&&e.mode!=='race'&&e.mode!=='pr').sort((a,b)=>(b.date||'').localeCompare(a.date||''));

  const prBoard = (() => {
    const best = {};
    prs.forEach(e => { const key = e.presetId; if (!best[key] || (e.date||'') > (best[key].date||'')) best[key] = e; });
    pastRaces.forEach(e => { const key = e.presetId; if (!best[key]) best[key] = e; });
    return Object.values(best);
  })();

  const GoalCard = ({e}) => {
    const p = presetById(e.presetId);
    const days = e.date ? daysUntil(e.date) : null;
    const isPast = days !== null && days < 0;
    const hasLocation = !!e.location;
    const isRaceGoal = hasLocation && ['run','tri','bike'].includes(p.planType);
    const hasPlan = !!(e.racePlan || e.planSections?.strategy || e.aiConditions);
    return (
      <Card onClick={() => onViewGoal(e)} style={{marginBottom:10,padding:0,overflow:'hidden'}}>
        <div style={{height:3,background:`linear-gradient(90deg,${p.color},${p.color}60)`}}/>
        <div style={{padding:'16px 18px'}}>
          <div style={{display:'flex',alignItems:'flex-start',gap:14}}>
            <div style={{width:46,height:46,borderRadius:16,background:p.color+'18',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
              <Icon name={isRaceGoal?'flag':p.icon} size={22} color={p.color}/>
            </div>
            <div style={{flex:1,overflow:'hidden'}}>
              <div style={{display:'flex',alignItems:'center',gap:8}}>
                <div style={{fontFamily:F.ui,fontWeight:700,fontSize:16,color:C.text,overflow:'hidden',whiteSpace:'nowrap',textOverflow:'ellipsis',flex:1}}>{e.name}</div>
                {isRaceGoal && <Pill color={p.color} small>Race</Pill>}
                {!isRaceGoal && <Pill color={C.subtle} small>Goal</Pill>}
              </div>
              <div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:3}}>
                {hasLocation ? e.location : p.label}
                {e.date ? ` · ${fmtDateSh(e.date)}` : ''}
              </div>
              {(e.goal || e.stretchGoal) && <div style={{display:'flex',gap:12,marginTop:8}}>
                {e.goal && <div style={{padding:'4px 10px',background:p.color+'12',borderRadius:8,display:'inline-flex',alignItems:'center',gap:4}}>
                  <Icon name='target' size={11} color={p.color}/>
                  <span style={{fontFamily:F.ui,fontSize:12,fontWeight:700,color:p.color}}>{e.goal}</span>
                </div>}
                {e.stretchGoal && <div style={{padding:'4px 10px',background:C.yellow+'12',borderRadius:8,display:'inline-flex',alignItems:'center',gap:4}}>
                  <Icon name='zap' size={11} color={C.yellow}/>
                  <span style={{fontFamily:F.ui,fontSize:12,fontWeight:700,color:C.yellow}}>{e.stretchGoal}</span>
                </div>}
              </div>}
              {e.baseline && <div style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginTop:4}}>Current: {e.baseline}</div>}
            </div>
            {days !== null && <div style={{textAlign:'right',flexShrink:0,minWidth:50}}>
              <div style={{fontFamily:F.display,fontSize:32,fontWeight:800,color:isPast?C.muted:(days<=7?C.accent:days<=30?C.yellow:C.text),lineHeight:1}}>{isPast?'—':days}</div>
              <div style={{fontFamily:F.ui,fontSize:10,color:C.muted,fontWeight:500}}>{isPast?'past':'days'}</div>
            </div>}
            {days === null && <div style={{fontFamily:F.ui,fontSize:12,color:C.muted,fontWeight:500,flexShrink:0}}>Ongoing</div>}
          </div>
          {(hasPlan || e.notes?.length > 0 || e.url) && <div style={{display:'flex',gap:6,marginTop:10,flexWrap:'wrap'}}>
            {hasPlan && <Pill color={C.purple} small>Plan</Pill>}
            {e.notes?.length > 0 && <Pill color={C.subtle} small>{e.notes.length} note{e.notes.length>1?'s':''}</Pill>}
            {e.url && <Pill color={C.cyan} small>Link</Pill>}
          </div>}
        </div>
      </Card>
    );
  };

  const RaceCard = ({e}) => {
    const p = presetById(e.presetId);
    const metGoal = e.goal && e.result && e.result <= e.goal;
    return (
      <Card onClick={() => onViewGoal(e)} style={{marginBottom:10,padding:0,overflow:'hidden'}}>
        <div style={{height:3,background:`linear-gradient(90deg,${p.color},${C.green})`}}/>
        <div style={{padding:'16px 18px'}}>
          <div style={{display:'flex',alignItems:'flex-start',gap:14}}>
            <div style={{width:46,height:46,borderRadius:16,background:p.color+'18',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
              <Icon name='trophy' size={22} color={p.color}/>
            </div>
            <div style={{flex:1,overflow:'hidden'}}>
              <div style={{fontFamily:F.ui,fontWeight:700,fontSize:16,color:C.text,overflow:'hidden',whiteSpace:'nowrap',textOverflow:'ellipsis'}}>{e.name}</div>
              <div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:2}}>
                {e.location || p.label}{e.date ? ` · ${fmtDateSh(e.date)}` : ''}
              </div>
            </div>
            {e.result && <div style={{textAlign:'right',flexShrink:0}}>
              <div style={{fontFamily:F.display,fontSize:22,fontWeight:800,color:C.green,lineHeight:1}}>{e.result}</div>
              <div style={{fontFamily:F.ui,fontSize:10,color:C.muted,marginTop:3}}>{p.resultLabel||'Result'}</div>
            </div>}
          </div>
          <div style={{display:'flex',gap:8,marginTop:10,flexWrap:'wrap',alignItems:'center'}}>
            {e.goal && <div style={{display:'inline-flex',alignItems:'center',gap:4,padding:'3px 8px',borderRadius:6,background:metGoal?C.green+'15':C.muted+'12'}}>
              <span style={{fontSize:11}}>{metGoal?'✓':'·'}</span>
              <span style={{fontFamily:F.ui,fontSize:11,fontWeight:600,color:metGoal?C.green:C.muted}}>Goal: {e.goal}</span>
            </div>}
            {e.placement && <Pill color={C.cyan} small>#{e.placement.replace(/[^0-9]/g,'') || e.placement}</Pill>}
            {e.ageGroupPlacement && e.ageGroup && <Pill color={C.green} small>{e.ageGroup}: {e.ageGroupPlacement}</Pill>}
            {e.bibNumber && <Pill color={C.subtle} small>Bib {e.bibNumber}</Pill>}
          </div>
        </div>
      </Card>
    );
  };

  const PRCard = ({e}) => {
    const p = presetById(e.presetId);
    const improvement = e.baseline && e.result ? `from ${e.baseline}` : null;
    return (
      <Card onClick={() => onViewGoal(e)} style={{marginBottom:10,padding:0,overflow:'hidden'}}>
        <div style={{height:3,background:`linear-gradient(90deg,${C.green},${C.cyan})`}}/>
        <div style={{padding:'16px 18px'}}>
          <div style={{display:'flex',alignItems:'center',gap:14}}>
            <div style={{width:46,height:46,borderRadius:16,background:C.green+'18',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
              <Icon name='zap' size={22} color={C.green}/>
            </div>
            <div style={{flex:1,overflow:'hidden'}}>
              <div style={{fontFamily:F.ui,fontWeight:700,fontSize:16,color:C.text,overflow:'hidden',whiteSpace:'nowrap',textOverflow:'ellipsis'}}>{e.name}</div>
              <div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:2}}>
                {p.label}{e.date ? ` · ${fmtDateSh(e.date)}` : ''}
              </div>
            </div>
            <div style={{textAlign:'right',flexShrink:0}}>
              <div style={{fontFamily:F.display,fontSize:26,fontWeight:800,color:C.green,lineHeight:1}}>{e.result}</div>
              {improvement && <div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginTop:3}}>{improvement}</div>}
              {!improvement && <div style={{fontFamily:F.ui,fontSize:10,color:C.green,marginTop:3,fontWeight:600}}>PR</div>}
            </div>
          </div>
        </div>
      </Card>
    );
  };

  const CompletedGoalCard = ({e}) => {
    const p = presetById(e.presetId);
    return (
      <Card onClick={() => onViewGoal(e)} style={{marginBottom:10,padding:'14px 18px',opacity:0.85}}>
        <div style={{display:'flex',alignItems:'center',gap:14}}>
          <div style={{width:40,height:40,borderRadius:14,background:C.green+'15',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
            <Icon name='check' size={20} color={C.green}/>
          </div>
          <div style={{flex:1,overflow:'hidden'}}>
            <div style={{fontFamily:F.ui,fontWeight:600,fontSize:15,color:C.subtle,overflow:'hidden',whiteSpace:'nowrap',textOverflow:'ellipsis'}}>{e.name}</div>
            <div style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginTop:2}}>{p.label}{e.date ? ` · ${fmtDateSh(e.date)}` : ''}</div>
          </div>
          {e.result && <div style={{fontFamily:F.display,fontSize:18,fontWeight:700,color:C.green}}>{e.result}</div>}
          <Pill color={C.green} small>Done</Pill>
        </div>
      </Card>
    );
  };

  const PRBoard = () => {
    if (prBoard.length === 0) return null;
    return (
      <div style={{marginBottom:20}}>
        <div style={{display:'grid',gridTemplateColumns:'repeat(auto-fill,minmax(140px,1fr))',gap:8}}>
          {prBoard.map(e => {
            const p = presetById(e.presetId);
            return (
              <div key={e.presetId} onClick={() => onViewGoal(e)} style={{background:C.surface,border:`1.5px solid ${p.color}25`,borderRadius:14,padding:'14px 12px',cursor:'pointer',textAlign:'center',transition:'all .15s',position:'relative',overflow:'hidden'}} onMouseEnter={x => {x.currentTarget.style.borderColor=p.color+'60';x.currentTarget.style.transform='translateY(-1px)';}} onMouseLeave={x => {x.currentTarget.style.borderColor=p.color+'25';x.currentTarget.style.transform='none';}}>
                <div style={{position:'absolute',top:-10,right:-10,width:40,height:40,borderRadius:'50%',background:p.color+'10',pointerEvents:'none'}}/>
                <Icon name={p.icon} size={16} color={p.color}/>
                <div style={{fontFamily:F.display,fontSize:22,fontWeight:800,color:C.text,marginTop:6,lineHeight:1}}>{e.result}</div>
                <div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginTop:4,fontWeight:600}}>{p.label}</div>
                {e.date && <div style={{fontFamily:F.ui,fontSize:10,color:C.muted,marginTop:2}}>{fmtDateSh(e.date)}</div>}
              </div>
            );
          })}
        </div>
      </div>
    );
  };

  return(<div style={{paddingBottom:80}}>
    <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:16}}>
      <div><div style={{fontFamily:F.display,fontSize:24,fontWeight:800,color:C.text}}>Goals & Races</div><div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:2}}>{upcoming.length} active{pastRaces.length>0?` · ${pastRaces.length} race${pastRaces.length>1?'s':''}`:''}{prs.length>0?` · ${prs.length} PR${prs.length>1?'s':''}`:''}{completed.length>0?` · ${completed.length} completed`:''}</div></div>
      <div style={{display:'flex',gap:6}}>
        <button onClick={onAddEventChat} style={{padding:'10px 14px',background:C.purple+'18',border:`1.5px solid ${C.purple}40`,borderRadius:14,fontFamily:F.display,fontSize:14,fontWeight:700,color:C.purple,cursor:'pointer',display:'flex',alignItems:'center',gap:6,transition:'all .15s'}} title="Add with AI chat"><Icon name='sparkle' size={14} color={C.purple}/>AI</button>
        <Btn onClick={onAddEvent} color={C.accent} style={{padding:'10px 18px',fontSize:14}}>+ Add</Btn>
      </div>
    </div>

    {upcoming.length===0&&pastRaces.length===0&&prs.length===0&&completed.length===0&&<div style={{display:'flex',flexDirection:'column',gap:10,marginBottom:16}}>
      <Card onClick={onAddEventChat} accent={C.purple} style={{textAlign:'center',padding:32}}><div style={{marginBottom:10}}><Icon name='sparkle' size={32} color={C.purple}/></div><div style={{fontFamily:F.display,fontSize:20,fontWeight:700,color:C.purple,marginBottom:6}}>Describe your goal</div><div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,lineHeight:1.6}}>Tell your coach about your next race or goal.</div></Card>
      <Card onClick={onAddEvent} style={{textAlign:'center',padding:20}}><div style={{display:'flex',alignItems:'center',justifyContent:'center',gap:8}}><Icon name='plus' size={18} color={C.muted}/><span style={{fontFamily:F.ui,fontWeight:600,fontSize:14,color:C.muted}}>Or fill out the form manually</span></div></Card>
    </div>}

    {upcoming.length>0&&<><Label>Upcoming</Label>{upcoming.map(e=><GoalCard key={e.id} e={e}/>)}</>}
    {prBoard.length>0&&<div style={{marginTop:upcoming.length?24:0}}><Label>Personal Records</Label><PRBoard/></div>}
    {pastRaces.length>0&&<div style={{marginTop:(upcoming.length||prBoard.length)?24:0}}><Label>Race History</Label>{pastRaces.map(e=><RaceCard key={e.id} e={e}/>)}</div>}
    {prs.length>0&&<div style={{marginTop:(upcoming.length||pastRaces.length||prBoard.length)?24:0}}><Label>All PRs</Label>{prs.map(e=><PRCard key={e.id} e={e}/>)}</div>}
    {completed.length>0&&<div style={{marginTop:(upcoming.length||pastRaces.length||prs.length||prBoard.length)?24:0}}><Label>Completed Goals</Label>{completed.map(e=><CompletedGoalCard key={e.id} e={e}/>)}</div>}
  </div>);
}
