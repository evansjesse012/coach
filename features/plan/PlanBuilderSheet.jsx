"use client";
import React, { useState, useEffect, useRef, useCallback } from "react";
import { C, S, F } from '../../lib/theme.js';
import { Icon } from '../../lib/icons.js';
import { TOOLS } from '../../ai/tools.js';
import { callAI } from '../../ai/call-ai.js';
import { renderMd } from '../../lib/utils.js';
import { Sheet, Btn, Inp, DotsLoader } from '../../ui/primitives.js';

// These will need to be passed in or imported from wherever they end up
// For now we define minimal stubs referencing the monolith's functions
function buildPlanBuilderPrompt(goal, mode='create') {
  // This is a placeholder — in production this would be imported from a prompts module
  const mem = typeof window !== 'undefined' && window.__buildPlanBuilderPrompt ? window.__buildPlanBuilderPrompt(goal, mode) : '';
  return mem;
}

function executeTool(name, input, appState) {
  if (typeof window !== 'undefined' && window.__executeTool) return window.__executeTool(name, input, appState);
  return JSON.stringify({error: 'executeTool not available'});
}

function typewriter(text, onUpdate) {
  return new Promise(resolve => {
    let i = 0;
    const step = () => { if (i >= text.length) { resolve(); return; } i += Math.floor(Math.random() * 3) + 1; onUpdate(text.slice(0, i)); requestAnimationFrame(step); };
    step();
  });
}

let _planBuilderStartedAt=0;
export { _planBuilderStartedAt };

export function PlanBuilderSheet({goal,mode,appState,onPlanCreated,onWeekGenerated,onClose}){
  const[msgs,setMsgs]=useState([]);
  const[input,setInput]=useState('');
  const[loading,setLoading]=useState(false);
  const[stage,setStage]=useState('starting');
  const[isStreaming,setIsStreaming]=useState(false);
  const[streamText,setStreamText]=useState('');
  const bottomRef=useRef(null);
  const inputRef=useRef(null);
  const chainRef=useRef([]);

  const stageLabels={starting:'Starting...',reviewing:'Reviewing your training',designing:'Designing your plan',generating:'Generating week 1',done:'Plan created!',error:'Something went wrong'};
  const stageOrder=['reviewing','designing','generating','done'];
  const stageIdx=stageOrder.indexOf(stage);

  useEffect(()=>{bottomRef.current?.scrollIntoView({behavior:'smooth'});},[msgs,streamText]);

  const detectStage=(toolNames)=>{
    if(toolNames.some(n=>n==='save_weekly_plan'))setStage('generating');
    else if(toolNames.some(n=>n==='save_training_plan'))setStage('designing');
    else if(toolNames.some(n=>['get_workouts','get_athlete_profile','get_goals','get_training_stats'].includes(n)))setStage('reviewing');
  };

  const runTurn=useCallback(async(userMsgs)=>{
    setLoading(true);
    const systemPrompt=buildPlanBuilderPrompt(goal,mode);
    const clean=userMsgs.map(m=>({role:m.role,content:typeof m.content==='string'?m.content:String(m.content||'')}));
    let chain=[...clean];
    try{
      for(let round=0;round<10;round++){
        const resp=await callAI({system:systemPrompt,messages:chain,tools:TOOLS,tool_choice:{type:'auto'},max_tokens:2048});
        const textContent=resp.content?.filter(b=>b.type==='text')?.map(b=>b.text)?.join('')?.trim()||'';
        if(resp.stop_reason==='end_turn'){
          chainRef.current=chain;
          setLoading(false);
          setIsStreaming(true);setStreamText('');
          await typewriter(textContent,chunk=>setStreamText(chunk));
          const aMsg={role:'assistant',content:textContent};
          setMsgs(prev=>[...prev,aMsg]);
          chainRef.current=[...chain,{role:'assistant',content:textContent}];
          setIsStreaming(false);setStreamText('');
          return;
        }
        if(resp.stop_reason==='tool_use'){
          const toolUses=resp.content?.filter(b=>b.type==='tool_use')||[];
          if(!toolUses.length){chainRef.current=chain;setLoading(false);return;}
          detectStage(toolUses.map(t=>t.name));
          const toolResults=toolUses.map(tu=>{
            let inp;try{inp=typeof tu.input==='string'?JSON.parse(tu.input):tu.input;}catch{inp={};}
            const result=executeTool(tu.name,inp,appState);
            if(tu.name==='save_training_plan'){try{const p=JSON.parse(result);if(p.saved&&p.plan){onPlanCreated(p.plan);if(mode==='create')setStage('designing');}}catch{}}
            if(tu.name==='save_weekly_plan'){try{const p=JSON.parse(result);if(p.saved&&p.weekPlan){onWeekGenerated(p.weekPlan);setStage('done');}}catch{}}
            return{type:'tool_result',tool_use_id:tu.id,content:result};
          });
          chain=[...chain,{role:'assistant',content:resp.content},{role:'user',content:toolResults}];
          if(textContent){
            setIsStreaming(true);setStreamText('');
            await typewriter(textContent,chunk=>setStreamText(chunk));
            setMsgs(prev=>[...prev,{role:'assistant',content:textContent}]);
            setIsStreaming(false);setStreamText('');
          }
          continue;
        }
        break;
      }
      chainRef.current=chain;setLoading(false);
    }catch(err){
      setStage('error');setLoading(false);setIsStreaming(false);
      setMsgs(prev=>[...prev,{role:'assistant',content:`Something went wrong: ${err.message}. Tap "Try again" to retry.`}]);
    }
  },[goal,mode,appState,onPlanCreated,onWeekGenerated]);

  useEffect(()=>{
    if(_planBuilderStartedAt){setStage('generating');return;}
    _planBuilderStartedAt=Date.now();
    const initMsg={role:'user',content:mode==='week'?`Generate my training plan for week ${goal._weekNum||'current'} (Phase ${goal._phaseNum||'current'}).`:`Build me a training plan for ${goal.name}.`};
    setMsgs([initMsg]);
    runTurn([initMsg]);
  },[]);

  const sendReply=()=>{
    const t=input.trim();if(!t||loading||isStreaming)return;
    const userMsg={role:'user',content:t};
    const updated=[...msgs,userMsg];
    setMsgs(updated);setInput('');
    const fullChain=[...chainRef.current,{role:'user',content:t}];
    runTurn(fullChain);
  };

  const retry=()=>{setStage('starting');runTurn(chainRef.current.length?chainRef.current:[msgs[0]]);};
  const approveAndGo=()=>{if(loading||isStreaming)return;const msg=mode==='week'?"Looks great — generate the week.":"Looks great — save the plan and generate week 1.";const userMsg={role:'user',content:msg};setMsgs(prev=>[...prev,userMsg]);const fullChain=[...chainRef.current,{role:'user',content:msg}];runTurn(fullChain);};

  const isDone=stage==='done';
  const isConversational=!loading&&!isStreaming&&msgs.length>1&&!isDone&&stage!=='error';

  const handleClose=()=>{_planBuilderStartedAt=0;onClose();};

  return(<Sheet onClose={handleClose} title={mode==='week'?'Generating week':'Building your plan'}>
    <div style={{display:'flex',gap:4,marginBottom:16}}>
      {stageOrder.map((s,i)=><div key={s} style={{flex:1,height:4,borderRadius:2,background:i<=stageIdx?(i===stageIdx?C.accent:C.green):C.border,transition:'background .3s'}}/>)}
    </div>
    <div style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:stage==='error'?C.red:stage==='done'?C.green:C.accent,marginBottom:4}}>{stageLabels[stage]}</div>
    {stage!=='done'&&stage!=='error'&&<div style={{fontFamily:F.ui,fontSize:11,color:C.muted,marginBottom:16}}>This usually takes 30–60 seconds</div>}

    <div style={{maxHeight:'50vh',overflowY:'auto',display:'flex',flexDirection:'column',gap:10,marginBottom:16}}>
      {msgs.filter(m=>m.role==='assistant').map((m,i)=>(
        <div key={i} className="fade-up" style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.75}}>{renderMd(m.content)}</div>
      ))}
      {isStreaming&&streamText&&<div className="fade-up" style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.75}}>{renderMd(streamText)}</div>}
      {loading&&!isStreaming&&<div style={{display:'flex',alignItems:'center',gap:8,padding:'8px 0'}}><DotsLoader color={C.accent}/><span style={{fontFamily:F.ui,fontSize:12,color:C.muted}}>{stageLabels[stage]}</span></div>}
      <div ref={bottomRef}/>
    </div>

    {isConversational&&<>
      <Btn onClick={approveAndGo} color={C.green} style={{width:'100%',padding:13,fontSize:15,marginBottom:8}}>Ready to train</Btn>
      <div style={{display:'flex',gap:8,marginBottom:12}}>
        <Inp ref={inputRef} value={input} onChange={e=>setInput(e.target.value)} onKeyDown={e=>e.key==='Enter'&&sendReply()} placeholder="Request changes..." style={{flex:1}}/>
        <button onClick={sendReply} disabled={!input.trim()} style={{width:48,height:48,background:!input.trim()?C.elevated:C.accent,border:'none',borderRadius:12,cursor:!input.trim()?'not-allowed':'pointer',color:!input.trim()?C.muted:'#fff',fontSize:18,display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>↑</button>
      </div>
    </>}

    {stage==='error'&&<Btn onClick={retry} color={C.accent} style={{width:'100%',padding:13,fontSize:15,marginBottom:8}}>Try again</Btn>}
    {isDone&&<Btn onClick={handleClose} color={C.green} style={{width:'100%',padding:13,fontSize:15}}>View your plan</Btn>}
  </Sheet>);
}
