"use client";
import React, { useState } from "react";
import { C, S, F } from '../../lib/theme.js';
import { Icon } from '../../lib/icons.js';
import { PERSONALITIES } from '../../lib/personalities.js';
import { loadMemory, saveMemory, defaultMemory } from '../../ai/memory.js';
import { todayStr } from '../../lib/utils.js';
import { db } from '../../lib/db.js';
import { Sheet, Btn, Inp, Toggle, Label, Textarea, Card } from '../../ui/primitives.js';
import { toast } from '../../ui/toast.js';
import { confirmDialog } from '../../ui/confirm.js';

export function SettingsPage({ personality, customPrompt, onPersonalityChange, onCustomPromptChange, isDark, onToggleDark, onClose, onViewProfile }) {
  const [localCustom, setLocalCustom] = useState(customPrompt||'');
  const [saved, setSaved] = useState(false);
  const mem = loadMemory();
  const hasMemory = !!(mem.observations?.patterns?.length||mem.injuries?.length||mem.observations?.openItems?.length);

  const handleCustomSave = () => { onCustomPromptChange(localCustom); setSaved(true); setTimeout(()=>setSaved(false),2000); toast.success('Custom coach saved'); };
  const resetMemory = async () => { const ok=await confirmDialog('Reset coaching memory?','The coach will start fresh — all learned patterns and history cleared.'); if(!ok)return; saveMemory(defaultMemory()); toast.info('Coaching memory reset'); };
  const exportData = () => { const data={exportedAt:new Date().toISOString(),events:db.get('coach_events',[]),cardio:db.get('coach_cardio',[]),strength:db.get('coach_strength_history',[]),prs:db.get('coach_prs',{}),nutrition:db.get('coach_nutrition',[]),trainingPlan:db.get('coach_training_plan',null),bricks:db.get('coach_bricks',[]),memory:loadMemory()}; const blob=new Blob([JSON.stringify(data,null,2)],{type:'application/json'}); const url=URL.createObjectURL(blob); const a=document.createElement('a'); a.href=url; a.download=`coach-export-${todayStr()}.json`; a.click(); URL.revokeObjectURL(url); toast.success('Data exported'); };
  const loadSeedData = async () => { const ok=await confirmDialog('Load test data?','This will replace all current data with sample training data for testing.'); if(!ok)return; try{const res=await fetch('/seed-data.json');const d=await res.json();db.set('coach_events',d.events||[]);db.set('coach_cardio',d.cardio||[]);db.set('coach_strength_history',d.strengthHistory||[]);db.set('coach_prs',d.prs||{});db.set('coach_nutrition',d.nutrition||[]);db.set('coach_bricks',d.bricks||[]);db.set('coach_plan_history',d.planHistory||[]);if(d.memory)saveMemory(d.memory);db.set('coach_messages',[]);toast.success('Test data loaded — reload the app');setTimeout(()=>window.location.reload(),1000);}catch(e){toast.error('Failed to load seed data');} };

  return (
    <div className="slide-in" style={{position:'fixed',inset:0,background:C.bg,zIndex:100,overflowY:'auto',maxWidth:500,margin:'0 auto'}}>
      <div style={{background:C.bg+'F6',backdropFilter:'blur(20px)',borderBottom:`1px solid ${C.border}`,padding:'16px 20px',display:'flex',alignItems:'center',gap:12,position:'sticky',top:0,zIndex:10}}>
        <button onClick={onClose} style={{borderRadius:12,background:C.elevated,border:`1.5px solid ${C.border}`,color:C.text,cursor:'pointer',display:'flex',alignItems:'center',gap:4,padding:'8px 14px 8px 10px',flexShrink:0}}><Icon name='arrowLeft' size={16}/><span style={{fontFamily:F.ui,fontSize:13,fontWeight:600}}>Back</span></button>
        <div style={{fontFamily:F.display,fontSize:22,fontWeight:800,color:C.text,letterSpacing:'-.01em'}}>Settings</div>
      </div>

      <div style={{padding:'20px 16px 48px'}}>

        {/* Appearance */}
        <div style={{marginBottom:32}}>
          <Label>Appearance</Label>
          <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',padding:'14px 18px',background:C.card,borderRadius:14,border:`1.5px solid ${C.border}`,boxShadow:S.card}}>
            <div style={{display:'flex',alignItems:'center',gap:12}}>
              <div style={{width:38,height:38,borderRadius:12,background:C.elevated,display:'flex',alignItems:'center',justifyContent:'center',}}>{isDark?<Icon name='moon' size={20} color={C.muted}/>:<Icon name='sun' size={20} color={C.yellow}/>}</div>
              <div>
                <div style={{fontFamily:F.ui,fontWeight:600,fontSize:15,color:C.text}}>{isDark?'Dark mode':'Light mode'}</div>
                <div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:1}}>{isDark?'Easy on the eyes at night':'Clean and bright'}</div>
              </div>
            </div>
            <Toggle on={isDark} onToggle={onToggleDark}/>
          </div>
        </div>

        {/* Coach mode */}
        <div style={{marginBottom:32}}>
          <Label>Coach mode</Label>
          <div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,marginBottom:16,lineHeight:1.65}}>Choose how your coach communicates. Affects chat and the daily coaching analysis.</div>
          {['normal','goggins','hype'].map(key=>{
            const p=PERSONALITIES[key]; const sel=personality===key;
            return(
              <div key={key} onClick={()=>onPersonalityChange(key)} style={{marginBottom:10,background:sel?p.color+'10':C.card,border:`2px solid ${sel?p.color:C.border}`,borderRadius:18,padding:'18px 20px',cursor:'pointer',transition:'all .18s',boxShadow:sel?S.md:S.card}} onMouseEnter={e=>{if(!sel){e.currentTarget.style.borderColor=p.color+'66';e.currentTarget.style.background=p.color+'08';}}} onMouseLeave={e=>{if(!sel){e.currentTarget.style.borderColor=C.border;e.currentTarget.style.background=C.card;}}}>
                <div style={{display:'flex',alignItems:'flex-start',gap:14}}>
                  <div style={{width:52,height:52,borderRadius:16,background:p.color+'20',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}><Icon name={p.icon} size={26} color={p.color}/></div>
                  <div style={{flex:1}}>
                    <div style={{display:'flex',alignItems:'center',gap:10,marginBottom:4}}>
                      <div style={{fontFamily:F.display,fontSize:20,fontWeight:700,color:sel?p.color:C.text}}>{p.name}</div>
                      {sel&&<div style={{width:10,height:10,borderRadius:'50%',background:p.color,flexShrink:0}}/>}
                    </div>
                    <div style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:p.color,marginBottom:6}}>{p.tagline}</div>
                    <div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,lineHeight:1.65}}>{p.description}</div>
                  </div>
                </div>
                {key==='goggins'&&sel&&<div style={{marginTop:14,padding:'10px 14px',background:C.red+'12',borderRadius:10,border:`1px solid ${C.red}30`}}><div style={{fontFamily:F.ui,fontSize:13,color:C.red,fontWeight:600}}>This mode is brutally honest. No mercy, no excuses.</div></div>}
              </div>
            );
          })}

          {/* Custom */}
          {(()=>{const p=PERSONALITIES.custom;const sel=personality==='custom';return(<div style={{marginBottom:10}}><div onClick={()=>onPersonalityChange('custom')} style={{background:sel?p.color+'10':C.card,border:`2px solid ${sel?p.color:C.border}`,borderRadius:18,padding:'18px 20px',cursor:'pointer',transition:'all .18s',boxShadow:sel?S.md:S.card}} onMouseEnter={e=>{if(!sel){e.currentTarget.style.borderColor=p.color+'66';e.currentTarget.style.background=p.color+'08';}}} onMouseLeave={e=>{if(!sel){e.currentTarget.style.borderColor=C.border;e.currentTarget.style.background=C.card;}}}><div style={{display:'flex',alignItems:'flex-start',gap:14}}><div style={{width:52,height:52,borderRadius:16,background:p.color+'20',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}><Icon name={p.icon} size={26} color={p.color}/></div><div style={{flex:1}}><div style={{display:'flex',alignItems:'center',gap:10,marginBottom:4}}><div style={{fontFamily:F.display,fontSize:20,fontWeight:700,color:sel?p.color:C.text}}>{p.name}</div>{sel&&<div style={{width:10,height:10,borderRadius:'50%',background:p.color,flexShrink:0}}/>}</div><div style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:p.color,marginBottom:6}}>{p.tagline}</div><div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,lineHeight:1.65}}>{p.description}</div></div></div></div>{sel&&<div className="fade-up" style={{background:C.purple+'08',border:`2px solid ${C.purple}30`,borderRadius:16,padding:'16px 18px',marginTop:8}}><div style={{fontFamily:F.ui,fontSize:14,fontWeight:600,color:C.purple,marginBottom:8}}>Describe your ideal coach</div><div style={{fontFamily:F.ui,fontSize:13,color:C.subtle,marginBottom:12,lineHeight:1.65}}>Write a few sentences. Your words become the coaching style. Examples: "Be like my college coach — tough but fair, always cite the science." or "Gentle and supportive, I struggle with anxiety."</div><Textarea placeholder="e.g. Talk to me like I'm training for the Olympics. Always reference the data. Push me when I make excuses, but celebrate real wins..." value={localCustom} onChange={e=>setLocalCustom(e.target.value)} rows={5} style={{marginBottom:12}}/><Btn onClick={handleCustomSave} color={C.purple} disabled={!localCustom.trim()} style={{width:'100%',fontSize:15}}>{saved?'✓ Saved':'Save custom coach'}</Btn></div>}</div>);})()}
        </div>

        {/* Profile & Memory */}
        <div style={{marginBottom:32}}>
          <Label>Athlete profile</Label>
          <Card onClick={onViewProfile} accent={C.accent} style={{marginBottom:10}}>
            <div style={{display:'flex',alignItems:'center',gap:12}}><div style={{width:36,height:36,borderRadius:12,background:C.accent+'18',display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name='run' size={18} color={C.accent}/></div><div style={{flex:1}}><div style={{fontFamily:F.ui,fontWeight:700,fontSize:14,color:C.accent}}>View athlete profile</div><div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:1}}>See what your coach knows about you</div></div><span style={{color:C.accent}}>→</span></div>
          </Card>
          {hasMemory&&<button onClick={resetMemory} style={{background:'none',border:`1.5px solid ${C.border}`,borderRadius:12,padding:'11px 16px',color:C.muted,fontFamily:F.ui,fontSize:13,fontWeight:500,cursor:'pointer',width:'100%',transition:'all .15s',marginTop:4}} onMouseEnter={e=>{e.currentTarget.style.borderColor=C.red;e.currentTarget.style.color=C.red;}} onMouseLeave={e=>{e.currentTarget.style.borderColor=C.border;e.currentTarget.style.color=C.muted;}}>Reset coaching memory</button>}
        </div>

        {/* Data */}
        <div style={{marginBottom:32}}>
          <Label>Your data</Label>
          <Card onClick={exportData} accent={C.cyan}>
            <div style={{display:'flex',alignItems:'center',gap:12}}><div style={{width:36,height:36,borderRadius:12,background:C.cyan+'18',display:'flex',alignItems:'center',justifyContent:'center',}}><Icon name='upload' size={18} color={C.cyan}/></div><div><div style={{fontFamily:F.ui,fontWeight:700,fontSize:14,color:C.cyan}}>Export all data</div><div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:1}}>Download workouts, goals, and history as JSON</div></div></div>
          </Card>
          <Card onClick={loadSeedData} accent={C.yellow} style={{marginTop:10}}>
            <div style={{display:'flex',alignItems:'center',gap:12}}><div style={{width:36,height:36,borderRadius:12,background:C.yellow+'18',display:'flex',alignItems:'center',justifyContent:'center',}}><Icon name='zap' size={18} color={C.yellow}/></div><div><div style={{fontFamily:F.ui,fontWeight:700,fontSize:14,color:C.yellow}}>Load test data</div><div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:1}}>Replace with sample triathlon training data</div></div></div>
          </Card>
        </div>

        {/* About */}
        <div>
          <Label>About</Label>
          <Card><div style={{fontFamily:F.ui,fontSize:14,color:C.subtle,lineHeight:1.8}}><div style={{display:'flex',justifyContent:'space-between',marginBottom:4}}><span style={{fontWeight:600}}>Coach App</span><span style={{color:C.muted}}>v1.0</span></div><div style={{color:C.muted,fontSize:13}}>AI-powered personal training. Your data stays on your device.</div></div></Card>
        </div>
      </div>
    </div>
  );
}
