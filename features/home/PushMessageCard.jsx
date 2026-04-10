"use client";
import React from "react";
import { C, S, F } from '../../lib/theme.js';
import { Icon } from '../../lib/icons.js';
import { PERSONALITIES } from '../../lib/personalities.js';
import { renderMd } from '../../lib/utils.js';
import { Card, Btn, DotsLoader, Spinner } from '../../ui/primitives.js';

export function PushMessageCard({ message, actions, personality, loading, onRefresh, onAction, hasWorkouts }) {
  const p=PERSONALITIES[personality]||PERSONALITIES.normal;
  const defaultMsg = personality==='goggins'
    ? "You haven't logged a single workout yet. The clock is ticking. Your race doesn't care about your excuses — it's coming whether you're ready or not. Add a goal above and get to work."
    : "Welcome to Coach. Add a goal above to generate your training plan, then log your first workout — I'll start tracking your progress and giving you real coaching feedback based on your actual training data.";
  const displayMsg = message || (!hasWorkouts ? defaultMsg : '');
  return(<Card style={{marginBottom:16,borderColor:p.color+'25',position:'relative',overflow:'hidden'}}>
    <div style={{position:'absolute',bottom:-20,right:-20,width:90,height:90,borderRadius:'50%',background:p.color+'10',pointerEvents:'none'}}/>
    <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:12}}>
      <div style={{display:'flex',alignItems:'center',gap:8}}>
        <div style={{width:28,height:28,borderRadius:9,background:p.color+'20',display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name={p.icon} size={14} color={p.color}/></div>
        <div><span style={{fontFamily:F.display,fontWeight:700,fontSize:14,color:p.color}}>Coach's Note</span></div>
      </div>
      {hasWorkouts&&<button onClick={onRefresh} disabled={loading} style={{background:C.elevated,border:'none',borderRadius:8,width:28,height:28,cursor:loading?'not-allowed':'pointer',color:C.muted,fontSize:13,display:'flex',alignItems:'center',justifyContent:'center',transition:'all .15s'}} onMouseEnter={e=>{if(!loading)e.currentTarget.style.color=p.color;}} onMouseLeave={e=>e.currentTarget.style.color=C.muted}><span style={{display:'inline-block',animation:loading?'spin 1s linear infinite':'none'}}>↻</span></button>}
    </div>
    {loading?<div><DotsLoader color={p.color}/><div style={{fontFamily:F.ui,fontSize:13,color:C.muted,marginTop:8}}>Reviewing your training…</div></div>
    :<><div style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.75}}>{renderMd(displayMsg)}</div>
    {actions?.length>0&&<div style={{display:'flex',flexWrap:'wrap',gap:8,marginTop:12,paddingTop:12,borderTop:`1px solid ${C.border}`}}>
      {actions.map((a,i)=><button key={i} onClick={()=>onAction?.(a)} style={{background:p.color+'12',border:`1.5px solid ${p.color}30`,borderRadius:10,padding:'8px 14px',fontFamily:F.ui,fontSize:13,fontWeight:600,color:p.color,cursor:'pointer',transition:'all .15s'}} onMouseEnter={e=>{e.currentTarget.style.background=p.color+'22';}} onMouseLeave={e=>{e.currentTarget.style.background=p.color+'12';}}>{a.label}</button>)}
    </div>}</>}
  </Card>);
}
