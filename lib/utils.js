import React from 'react';
import { C, F } from './theme.js';

export const daysUntil = d => Math.ceil((new Date(d+'T12:00:00')-new Date())/86400000);
export const fmtDur    = m => { if(!m)return'—'; const h=Math.floor(m/60),mn=m%60; return h>0?(mn>0?`${h}h ${mn}m`:`${h}h`):`${mn}m`; };
export const fmtDateSh = d => new Date(d+'T12:00:00').toLocaleDateString('en-US',{month:'short',day:'numeric'});
export const todayStr  = () => new Date().toISOString().split('T')[0];
export const uid       = () => Math.random().toString(36).slice(2,10);
export const epley     = (w,r) => r===1?w:Math.round(w*(1+r/30));
export const exSlug    = name => name.toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'');
export const getDayName= () => ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'][new Date().getDay()];

export const fmtPace = (dur, dist) => {
  if (!dur || !dist) return '';
  const pace = dur / dist;
  const min = Math.floor(pace);
  const sec = Math.round((pace - min) * 60);
  return `${min}:${sec.toString().padStart(2, '0')} /mi`;
};

export const computeExPR = (exerciseType, sets) => {
  const completed = sets.filter(s => s.completed);
  if (!completed.length) return null;
  if (exerciseType === 'weighted') {
    const best = completed.reduce((b,s) => epley(s.weight,s.reps) > epley(b.weight,b.reps) ? s : b);
    return { weight: best.weight, reps: best.reps, estimated1RM: epley(best.weight, best.reps), type: 'weighted' };
  }
  if (exerciseType === 'timed') {
    const best = Math.max(...completed.map(s => s.duration || 0));
    return { bestDuration: best, type: 'timed' };
  }
  // bodyweight, banded, cardio-drill → max reps
  const best = Math.max(...completed.map(s => s.reps || 0));
  const result = { bestReps: best, type: exerciseType };
  if (exerciseType === 'banded') result.band = completed[0]?.band || '';
  return result;
};
export const getPRValue = pr => {
  if (!pr) return 0;
  if (pr.estimated1RM) return pr.estimated1RM;
  if (pr.bestDuration) return pr.bestDuration;
  if (pr.bestReps) return pr.bestReps;
  return 0;
};
export const isPRBetter = (newPR, oldPR) => {
  if (!oldPR) return true;
  if (newPR.type === 'weighted') return (newPR.estimated1RM || 0) > (oldPR.estimated1RM || 0);
  if (newPR.type === 'timed') return (newPR.bestDuration || 0) > (oldPR.bestDuration || 0);
  return (newPR.bestReps || 0) > (oldPR.bestReps || 0);
};
export const fmtPR = pr => {
  if (!pr) return '—';
  if (pr.estimated1RM) return pr.weight > 0 ? `${pr.weight}lb × ${pr.reps}` : `${pr.reps} reps`;
  if (pr.bestDuration) return `${pr.bestDuration}s`;
  if (pr.bestReps) return `${pr.bestReps} reps`;
  return '—';
};

export function renderMd(text){
  if(!text)return null;
  const inlineBold=(str,keyPfx)=>{const parts=[];let last=0;const re=/\*\*(.+?)\*\*/g;let m;while((m=re.exec(str))!==null){if(m.index>last)parts.push(str.slice(last,m.index));parts.push(<strong key={`${keyPfx}-${m.index}`}>{m[1]}</strong>);last=re.lastIndex;}if(last<str.length)parts.push(str.slice(last));return parts.length?parts:str;};
  return text.split('\n').map((line,i)=>{
    if(!line.trim())return <div key={i} style={{height:8}}/>;
    if(line.match(/^---+$/))return <div key={i} style={{height:1,background:C.border,margin:'12px 0'}}/>;
    const h1=line.match(/^#\s+(.*)$/);if(h1)return <div key={i} style={{fontFamily:F.display,fontSize:20,fontWeight:800,color:C.text,marginTop:16,marginBottom:6}}>{inlineBold(h1[1],`h1${i}`)}</div>;
    const h2=line.match(/^##\s+(.*)$/);if(h2)return <div key={i} style={{fontFamily:F.display,fontSize:17,fontWeight:700,color:C.text,marginTop:14,marginBottom:4}}>{inlineBold(h2[1],`h2${i}`)}</div>;
    const h3=line.match(/^###\s+(.*)$/);if(h3)return <div key={i} style={{fontFamily:F.ui,fontSize:15,fontWeight:700,color:C.text,marginTop:10,marginBottom:2}}>{inlineBold(h3[1],`h3${i}`)}</div>;
    const num=line.match(/^(\d+)[.)]\s+(.*)$/);if(num)return <div key={i} style={{display:'flex',gap:8,marginTop:2,marginBottom:2}}><span style={{color:C.accent,fontWeight:700,flexShrink:0,fontFamily:F.mono,fontSize:13,minWidth:18,textAlign:'right'}}>{num[1]}.</span><span>{inlineBold(num[2],`n${i}`)}</span></div>;
    const bullet=line.match(/^[-•*]\s+(.*)$/);if(bullet)return <div key={i} style={{display:'flex',gap:8,marginTop:2,marginBottom:2}}><span style={{color:C.muted,flexShrink:0}}>•</span><span>{inlineBold(bullet[1],`b${i}`)}</span></div>;
    return <div key={i}>{inlineBold(line,`l${i}`)}</div>;
  });
}
