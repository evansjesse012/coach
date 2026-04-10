"use client";
import React, { useState, useEffect } from "react";
import { C, S, F } from '../../lib/theme.js';
import { Icon } from '../../lib/icons.js';
import { presetById, SPORT_META } from '../../lib/constants.js';
import { fmtDur, fmtDateSh, daysUntil, renderMd, uid, todayStr } from '../../lib/utils.js';
import { callAI } from '../../ai/call-ai.js';
import { Card, Btn, Inp, Label, Pill, Sheet, Textarea, Spinner } from '../../ui/primitives.js';
import { toast } from '../../ui/toast.js';
import { confirmDialog } from '../../ui/confirm.js';

function PlanSection({ icon, iconColor, title, hasContent, defaultOpen, children }) {
  const [open, setOpen] = useState(defaultOpen || false);
  return (
    <div style={{ marginBottom: 12 }}>
      <button onClick={() => setOpen(!open)} style={{
        width: '100%', display: 'flex', alignItems: 'center', gap: 10, padding: '13px 16px',
        background: C.card, border: `1.5px solid ${C.border}`, borderRadius: open ? '14px 14px 0 0' : 14,
        cursor: 'pointer', transition: 'all .15s',
      }}>
        <div style={{ width: 32, height: 32, borderRadius: 10, background: (iconColor || C.accent) + '18', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
          <Icon name={icon} size={16} color={iconColor || C.accent} />
        </div>
        <span style={{ flex: 1, fontFamily: F.ui, fontSize: 14, fontWeight: 700, color: C.text, textAlign: 'left' }}>{title}</span>
        {hasContent && !open && <div style={{ width: 8, height: 8, borderRadius: 4, background: C.green, flexShrink: 0 }} />}
        <Icon name={open ? 'chevUp' : 'chevDown'} size={16} color={C.muted} />
      </button>
      {open && (
        <div style={{ padding: '16px', background: C.card, border: `1.5px solid ${C.border}`, borderTop: 'none', borderRadius: '0 0 14px 14px' }}>
          {children}
        </div>
      )}
    </div>
  );
}

async function generateRaceConditions(event) {
  const p = presetById(event.presetId);
  try {
    const res = await callAI({
      system: 'You are a sports analyst. Respond with valid JSON only. No markdown code fences.',
      messages: [{ role: 'user', content: `Analyze race conditions for: ${event.name}, ${p.label}, Location: ${event.location||'Unknown'}, Date: ${event.date||'Unknown'}. Respond with JSON: {"summary":"","terrain":"","elevation":"","climate":"","tips":["","",""]}` }],
      max_tokens: 512,
    });
    const text = res.content?.[0]?.text || '';
    const cleaned = text.replace(/```json\s*/g, '').replace(/```\s*/g, '').trim();
    return { ...JSON.parse(cleaned), generatedAt: new Date().toISOString() };
  } catch { return null; }
}

export function GoalDetailView({event,allEvents,onUpdate,onEdit,onDelete,onClose}){
  const p=presetById(event.presetId);
  const isTri=p.planType==='tri';
  const isRaceType=['run','tri','bike'].includes(p.planType);
  const isRaceGoal = isRaceType && !!(event.location);
  const showRacePlanning = isRaceGoal && event.mode !== 'pr';
  const isPR = event.mode === 'pr';
  const days=event.date?daysUntil(event.date):null;
  const isPast=days!==null&&days<0;
  const prHistory = isPR ? (allEvents||[]).filter(e => e.presetId === event.presetId && e.result && e.id !== event.id).sort((a,b) => (b.date||'').localeCompare(a.date||'')) : [];
  const linkedRace = event.linkedRaceId ? (allEvents||[]).find(e => e.id === event.linkedRaceId) : null;
  const[noteText,setNoteText]=useState('');
  const[showCompleteSplits,setShowCompleteSplits]=useState(false);
  const[completeSplits,setCompleteSplits]=useState(event.splits||{swim:'',t1:'',bike:'',t2:'',run:'',total:''});
  const[completeResult,setCompleteResult]=useState(event.result||'');
  const[completePlacement,setCompletePlacement]=useState(event.placement||'');
  const[completeGenderPlace,setCompleteGenderPlace]=useState(event.genderPlacement||'');
  const[completeAGPlace,setCompleteAGPlace]=useState(event.ageGroupPlacement||'');
  const[completeBib,setCompleteBib]=useState(event.bibNumber||'');
  const[completeAG,setCompleteAG]=useState(event.ageGroup||'');
  const[aiLoading,setAiLoading]=useState(false);
  const[weatherData,setWeatherData]=useState(event.weather||null);
  const[weatherLoading,setWeatherLoading]=useState(false);
  const[weatherError,setWeatherError]=useState(false);

  const ps=event.planSections||{strategy:'',nutrition:{before:'',during:'',after:''},gear:'',travel:'',warmup:''};
  const[strategy,setStrategy]=useState(ps.strategy||event.racePlan||'');
  const[nutBefore,setNutBefore]=useState(ps.nutrition?.before||'');
  const[nutDuring,setNutDuring]=useState(ps.nutrition?.during||'');
  const[nutAfter,setNutAfter]=useState(ps.nutrition?.after||'');
  const[gear,setGear]=useState(ps.gear||'');
  const[travel,setTravel]=useState(ps.travel||'');
  const[warmup,setWarmup]=useState(ps.warmup||'');
  const[planDirty,setPlanDirty]=useState(false);
  const notes=event.notes||[];

  const fetchWeather=()=>{
    if(!event.location||!event.date||!showRacePlanning) return;
    setWeatherLoading(true);setWeatherError(false);
    fetch(`/api/weather?location=${encodeURIComponent(event.location)}&date=${event.date}`)
      .then(r=>{if(!r.ok)throw new Error('fetch failed');return r.json();})
      .then(data=>{if(data?.weather){const w={...data.weather,location:data.location,updatedAt:data.updatedAt};setWeatherData(w);onUpdate({...event,weather:w});}})
      .catch(()=>setWeatherError(true))
      .finally(()=>setWeatherLoading(false));
  };
  useEffect(()=>{
    if(!event.location||!event.date||!showRacePlanning) return;
    if(weatherData?.updatedAt){const age=Date.now()-new Date(weatherData.updatedAt).getTime();if(age<6*60*60*1000) return;}
    fetchWeather();
  },[event.location,event.date]);

  const addNote=()=>{if(!noteText.trim())return;const n={id:uid(),text:noteText.trim(),date:todayStr()};onUpdate({...event,notes:[n,...notes]});setNoteText('');toast.success('Note added');};
  const deleteNote=async(nid)=>{const ok=await confirmDialog('Delete this note?','');if(!ok)return;onUpdate({...event,notes:notes.filter(n=>n.id!==nid)});};

  const savePlanSections=()=>{
    const updated={...event,racePlan:strategy,planSections:{strategy,nutrition:{before:nutBefore,during:nutDuring,after:nutAfter},gear,travel,warmup}};
    onUpdate(updated);setPlanDirty(false);toast.success('Race plan saved');
  };

  const regenerateConditions=async()=>{
    setAiLoading(true);
    const conditions=await generateRaceConditions(event);
    if(conditions){onUpdate({...event,aiConditions:conditions});toast.success('Conditions updated');}
    else toast.error('Failed to generate conditions');
    setAiLoading(false);
  };

  const toggleComplete=async()=>{
    if(event.completed){onUpdate({...event,completed:false,mode:event.mode==='race'?'goal':event.mode});toast.info('Marked as active');}
    else if(isTri){setShowCompleteSplits(true);}
    else{const ok=await confirmDialog('Mark as complete?','This will move it to your history.');if(ok){onUpdate({...event,completed:true});toast.success('Completed!');}}
  };
  const saveCompleteSplits=()=>{
    const updates={...event,completed:true,mode:'race',splits:completeSplits,result:isTri?(completeSplits.total||completeResult):completeResult};
    if(completePlacement)updates.placement=completePlacement;
    if(completeGenderPlace)updates.genderPlacement=completeGenderPlace;
    if(completeAGPlace)updates.ageGroupPlacement=completeAGPlace;
    if(completeBib)updates.bibNumber=completeBib;
    if(completeAG)updates.ageGroup=completeAG;
    onUpdate(updates);setShowCompleteSplits(false);toast.success('Completed!');
  };

  const ai=event.aiConditions;

  return(
    <div className="slide-in" style={{position:'fixed',inset:0,background:C.bg,zIndex:100,overflowY:'auto',maxWidth:500,margin:'0 auto'}}>
      <div style={{background:C.bg+'F6',backdropFilter:'blur(20px)',borderBottom:`1px solid ${C.border}`,padding:'16px 20px',display:'flex',alignItems:'center',gap:12,position:'sticky',top:0,zIndex:10}}>
        <button onClick={onClose} style={{width:36,height:36,borderRadius:12,background:C.elevated,border:'none',color:C.subtle,fontSize:20,cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>←</button>
        <div style={{flex:1,fontFamily:F.display,fontSize:22,fontWeight:800,color:C.text,letterSpacing:'-.01em',overflow:'hidden',whiteSpace:'nowrap',textOverflow:'ellipsis'}}>{event.name}</div>
        <button onClick={()=>onEdit(event)} style={{background:C.elevated,border:'none',borderRadius:10,padding:'7px 14px',color:C.subtle,fontFamily:F.ui,fontSize:13,fontWeight:600,cursor:'pointer'}}>Edit</button>
      </div>

      <div style={{padding:'20px 16px 48px'}}>
        <div style={{background:`linear-gradient(135deg,${p.color}15,${p.color}08)`,border:`1.5px solid ${p.color}30`,borderRadius:20,padding:'24px 20px',marginBottom:20,position:'relative',overflow:'hidden'}}>
          <div style={{position:'absolute',top:-30,right:-30,width:120,height:120,borderRadius:'50%',background:p.color+'15',pointerEvents:'none'}}/>
          <div style={{display:'flex',alignItems:'center',gap:8,marginBottom:12}}>
            <div style={{width:40,height:40,borderRadius:14,background:p.color+'25',display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name={p.icon} size={20} color={p.color}/></div>
            <div>
              <div style={{fontFamily:F.ui,fontSize:12,fontWeight:700,color:p.color,textTransform:'uppercase',letterSpacing:'.06em'}}>{p.label}</div>
              {event.location&&<div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:1}}>{event.location}</div>}
            </div>
          </div>
          <div style={{display:'flex',justifyContent:'space-between',alignItems:'flex-end'}}>
            <div>
              <div style={{fontFamily:F.display,fontSize:28,fontWeight:800,color:C.text,letterSpacing:'-.01em',lineHeight:1.1}}>{event.name}</div>
              {event.date&&<div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,marginTop:6}}>{new Date(event.date+'T12:00:00').toLocaleDateString('en-US',{weekday:'long',month:'long',day:'numeric',year:'numeric'})}</div>}
            </div>
            {days!==null&&<div style={{textAlign:'right'}}>
              <div style={{fontFamily:F.display,fontSize:48,fontWeight:800,color:event.completed?C.green:(isPast?C.muted:C.text),lineHeight:1}}>{event.completed?'✓':(isPast?0:days)}</div>
              <div style={{fontFamily:F.ui,fontSize:12,color:C.muted,fontWeight:500}}>{event.completed?'Done':(isPast?'Past':'days')}</div>
            </div>}
          </div>
        </div>

        {(event.result||event.goal||event.stretchGoal||event.baseline)&&<div style={{display:'grid',gridTemplateColumns:`repeat(${Math.min([event.result,event.goal,event.stretchGoal,event.baseline].filter(Boolean).length,3)},1fr)`,gap:10,marginBottom:20}}>
          {[{l:event.mode==='pr'?'PR':p.resultLabel||'Result',v:event.result,c:C.green},{l:'Goal',v:event.goal,c:p.color},{l:'Stretch',v:event.stretchGoal,c:C.yellow},{l:'Previous best',v:event.baseline,c:C.subtle}].map(({l,v,c})=>v?<Card key={l} style={{textAlign:'center',padding:'14px 8px'}}><div style={{fontFamily:F.display,fontSize:24,fontWeight:700,color:c,lineHeight:1}}>{v}</div><div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginTop:5,fontWeight:500}}>{l}</div></Card>:null)}
        </div>}

        {event.url&&<Card accent={C.cyan} style={{marginBottom:16}} onClick={()=>window.open(event.url,'_blank')}>
          <div style={{display:'flex',alignItems:'center',gap:10}}>
            <div style={{width:34,height:34,borderRadius:12,background:C.cyan+'18',display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name='link' size={16} color={C.cyan}/></div>
            <div style={{flex:1,overflow:'hidden'}}>
              <div style={{fontFamily:F.ui,fontWeight:600,fontSize:14,color:C.cyan}}>Official race website</div>
              <div style={{fontFamily:F.ui,fontSize:12,color:C.muted,marginTop:1,overflow:'hidden',whiteSpace:'nowrap',textOverflow:'ellipsis'}}>{event.url.replace(/^https?:\/\//,'')}</div>
            </div>
            <span style={{color:C.cyan,fontSize:14}}>→</span>
          </div>
        </Card>}

        {showRacePlanning&&<div style={{marginBottom:8}}>
          <div style={{fontFamily:F.display,fontSize:18,fontWeight:800,color:C.text,marginBottom:14,letterSpacing:'-.01em'}}>Race Planning</div>
          <PlanSection icon="flag" iconColor={C.accent} title="Strategy & Pacing" hasContent={!!strategy}>
            <Textarea placeholder="Pacing plan, race approach..." value={strategy} onChange={e=>{setStrategy(e.target.value);setPlanDirty(true);}} rows={4}/>
          </PlanSection>
          <PlanSection icon="utensils" iconColor={C.green} title="Nutrition" hasContent={!!(nutBefore||nutDuring||nutAfter)}>
            <div style={{display:'flex',flexDirection:'column',gap:14}}>
              <div><Label>Before</Label><Textarea placeholder="Night before + morning of..." value={nutBefore} onChange={e=>{setNutBefore(e.target.value);setPlanDirty(true);}} rows={2}/></div>
              <div><Label>During race</Label><Textarea placeholder="Gel every 45min..." value={nutDuring} onChange={e=>{setNutDuring(e.target.value);setPlanDirty(true);}} rows={2}/></div>
              <div><Label>After</Label><Textarea placeholder="Recovery nutrition..." value={nutAfter} onChange={e=>{setNutAfter(e.target.value);setPlanDirty(true);}} rows={2}/></div>
            </div>
          </PlanSection>
          {planDirty&&<Btn onClick={savePlanSections} color={p.color} style={{width:'100%',marginBottom:16,padding:13,fontSize:14}}>Save race plan</Btn>}
        </div>}

        {!showRacePlanning&&!isPR&&<div style={{marginBottom:24}}>
          <div style={{fontFamily:F.display,fontSize:18,fontWeight:800,color:C.text,marginBottom:14,letterSpacing:'-.01em'}}>Plan & Strategy</div>
          <Textarea placeholder="Strategy, milestones, approach..." value={strategy} onChange={e=>{setStrategy(e.target.value);setPlanDirty(true);}} rows={5}/>
          {planDirty&&<Btn onClick={()=>{onUpdate({...event,racePlan:strategy,planSections:{...ps,strategy}});setPlanDirty(false);toast.success('Plan saved');}} color={p.color} style={{width:'100%',marginTop:10,padding:12,fontSize:14}}>Save plan</Btn>}
        </div>}

        <div style={{marginBottom:24}}>
          <Label>Notes</Label>
          <div style={{display:'flex',gap:8,marginBottom:12}}>
            <Inp placeholder="Add a note..." value={noteText} onChange={e=>setNoteText(e.target.value)} onKeyDown={e=>e.key==='Enter'&&addNote()} style={{flex:1}}/>
            <button onClick={addNote} disabled={!noteText.trim()} style={{width:48,height:48,background:!noteText.trim()?C.elevated:p.color,border:'none',borderRadius:12,cursor:!noteText.trim()?'not-allowed':'pointer',color:!noteText.trim()?C.muted:'#fff',fontSize:18,display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,transition:'all .15s'}}>+</button>
          </div>
          {notes.length===0?<Card style={{padding:20,textAlign:'center'}}><div style={{fontFamily:F.ui,fontSize:14,color:C.muted}}>No notes yet.</div></Card>
          :notes.map(n=><Card key={n.id} style={{marginBottom:8,padding:'13px 16px'}}>
            <div style={{display:'flex',justifyContent:'space-between',alignItems:'flex-start',gap:10}}>
              <div style={{flex:1}}>
                <div style={{fontFamily:F.ui,fontSize:15,color:C.text,lineHeight:1.65,whiteSpace:'pre-wrap'}}>{n.text}</div>
                <div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginTop:6}}>{fmtDateSh(n.date)}</div>
              </div>
              <button onClick={()=>deleteNote(n.id)} style={{background:'none',border:'none',color:C.muted,fontSize:14,cursor:'pointer',padding:4,flexShrink:0,opacity:0.6}} onMouseEnter={e=>e.currentTarget.style.opacity=1} onMouseLeave={e=>e.currentTarget.style.opacity=0.6}>✕</button>
            </div>
          </Card>)}
        </div>

        <div style={{display:'flex',gap:10}}>
          <Btn onClick={toggleComplete} color={event.completed?C.muted:C.green} outline={event.completed} style={{flex:1,fontSize:14,padding:13}}>{event.completed?'Reopen':'Mark complete ✓'}</Btn>
          <Btn onClick={async()=>{const ok=await confirmDialog('Delete this goal?','Your workout history will be kept.');if(ok){onDelete(event.id);onClose();}}} outline style={{flex:1,fontSize:14,padding:13,borderColor:C.red+'50',color:C.red}}>Delete</Btn>
        </div>
      </div>

      {showCompleteSplits&&<Sheet onClose={()=>setShowCompleteSplits(false)} title="Race Results">
        <div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,marginBottom:18}}>Enter your race splits and results.</div>
        <div style={{display:'flex',flexDirection:'column',gap:12,marginBottom:20}}>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr 1fr',gap:10}}>
            <div><Label>Swim</Label><Inp placeholder="0:32:10" value={completeSplits.swim} onChange={e=>setCompleteSplits(s=>({...s,swim:e.target.value}))}/></div>
            <div><Label>T1</Label><Inp placeholder="0:03:00" value={completeSplits.t1} onChange={e=>setCompleteSplits(s=>({...s,t1:e.target.value}))}/></div>
            <div><Label>Bike</Label><Inp placeholder="2:45:00" value={completeSplits.bike} onChange={e=>setCompleteSplits(s=>({...s,bike:e.target.value}))}/></div>
          </div>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr 1fr',gap:10}}>
            <div><Label>T2</Label><Inp placeholder="0:02:30" value={completeSplits.t2} onChange={e=>setCompleteSplits(s=>({...s,t2:e.target.value}))}/></div>
            <div><Label>Run</Label><Inp placeholder="1:50:00" value={completeSplits.run} onChange={e=>setCompleteSplits(s=>({...s,run:e.target.value}))}/></div>
            <div><Label>Total *</Label><Inp placeholder="5:12:40" value={completeSplits.total} onChange={e=>setCompleteSplits(s=>({...s,total:e.target.value}))}/></div>
          </div>
        </div>
        <div style={{display:'flex',gap:10}}>
          <Btn onClick={()=>setShowCompleteSplits(false)} outline style={{flex:1}}>Cancel</Btn>
          <Btn onClick={saveCompleteSplits} color={C.green} disabled={!completeSplits.total?.trim()} style={{flex:2}}>Complete race ✓</Btn>
        </div>
      </Sheet>}
    </div>
  );
}
