"use client";
import React, { useState, useEffect, useRef, useCallback } from "react";
import { C, S, F } from '../../lib/theme.js';
import { Icon } from '../../lib/icons.js';
import { EVENT_PRESETS, presetById } from '../../lib/constants.js';
import { renderMd, uid } from '../../lib/utils.js';
import { TOOLS } from '../../ai/tools.js';
import { callAI } from '../../ai/call-ai.js';
import { Sheet, Btn, Inp, Label, Pill, DotsLoader } from '../../ui/primitives.js';

function typewriter(text, onUpdate) {
  return new Promise(resolve => {
    let i = 0;
    const step = () => { if (i >= text.length) { resolve(); return; } i += Math.floor(Math.random() * 3) + 1; onUpdate(text.slice(0, i)); requestAnimationFrame(step); };
    step();
  });
}

function executeTool(name, input, appState) {
  if (typeof window !== 'undefined' && window.__executeTool) return window.__executeTool(name, input, appState);
  return JSON.stringify({error: 'executeTool not available'});
}

const PROPOSE_EVENT_TOOL = { name:'propose_event', description:'Propose a structured goal, race, or PR based on the conversation.', input_schema:{type:'object',properties:{
    mode:{type:'string',enum:['goal','race','pr']},
    presetId:{type:'string',enum:EVENT_PRESETS.map(p=>p.id)},
    name:{type:'string'},date:{type:'string'},location:{type:'string'},
    goal:{type:'string'},stretchGoal:{type:'string'},baseline:{type:'string'},
    result:{type:'string'},url:{type:'string'},placement:{type:'string'},
    bibNumber:{type:'string'},ageGroup:{type:'string'},
    genderPlacement:{type:'string'},ageGroupPlacement:{type:'string'},
    splits:{type:'object',properties:{swim:{type:'string'},t1:{type:'string'},bike:{type:'string'},t2:{type:'string'},run:{type:'string'},total:{type:'string'}}},
  },required:['mode','presetId','name']} };
const GOAL_CHAT_TOOLS = [...TOOLS, PROPOSE_EVENT_TOOL];

function buildGoalChatPrompt() {
  const presetList = EVENT_PRESETS.map(p=>`${p.id}: ${p.label} (${p.planType})`).join(', ');
  return `You are a friendly coaching assistant helping an athlete add a goal, race result, or personal record. Have a natural conversation to gather the details.
YOUR APPROACH: 1. Start by asking what they'd like to add 2. Listen and ask follow-ups 3. When ready, call propose_event
AVAILABLE PRESETS: ${presetList}
Today: ${new Date().toISOString().split('T')[0]}`;
}

export function GoalChatSheet({appState,onSave,onClose}){
  const[msgs,setMsgs]=useState([]);
  const[input,setInput]=useState('');
  const[loading,setLoading]=useState(false);
  const[isStreaming,setIsStreaming]=useState(false);
  const[streamText,setStreamText]=useState('');
  const[stage,setStage]=useState('chatting');
  const[proposedEvent,setProposedEvent]=useState(null);
  const[form,setForm]=useState(null);
  const bottomRef=useRef(null);
  const inputRef=useRef(null);
  const chainRef=useRef([]);

  useEffect(()=>{bottomRef.current?.scrollIntoView({behavior:'smooth'});},[msgs,streamText]);

  const executeGoalTool=(name,inp)=>{
    if(name==='propose_event') return JSON.stringify({proposed:true,message:'Event proposed to user for review.'});
    return executeTool(name,inp,appState);
  };

  const runTurn=useCallback(async(userMsgs)=>{
    setLoading(true);
    const systemPrompt=buildGoalChatPrompt();
    const clean=userMsgs.map(m=>({role:m.role,content:typeof m.content==='string'?m.content:String(m.content||'')}));
    let chain=[...clean];
    try{
      for(let round=0;round<8;round++){
        const resp=await callAI({system:systemPrompt,messages:chain,tools:GOAL_CHAT_TOOLS,tool_choice:{type:'auto'},max_tokens:1024});
        const textContent=resp.content?.filter(b=>b.type==='text')?.map(b=>b.text)?.join('')?.trim()||'';
        if(resp.stop_reason==='end_turn'){
          chainRef.current=chain;setLoading(false);
          if(textContent){
            setIsStreaming(true);setStreamText('');
            await typewriter(textContent,chunk=>setStreamText(chunk));
            const aMsg={role:'assistant',content:textContent};
            setMsgs(prev=>[...prev,aMsg]);
            chainRef.current=[...chain,{role:'assistant',content:textContent}];
            setIsStreaming(false);setStreamText('');
          }
          return;
        }
        if(resp.stop_reason==='tool_use'){
          const toolUses=resp.content?.filter(b=>b.type==='tool_use')||[];
          if(!toolUses.length){chainRef.current=chain;setLoading(false);return;}
          const toolResults=toolUses.map(tu=>{
            let inp;try{inp=typeof tu.input==='string'?JSON.parse(tu.input):tu.input;}catch{inp={};}
            const result=executeGoalTool(tu.name,inp);
            if(tu.name==='propose_event'){
              const proposed={presetId:inp.presetId||'custom',mode:inp.mode||'goal',name:inp.name||'',date:inp.date||'',location:inp.location||'',goal:inp.goal||'',stretchGoal:inp.stretchGoal||'',baseline:inp.baseline||'',result:inp.result||'',url:inp.url||'',placement:inp.placement||'',bibNumber:inp.bibNumber||'',ageGroup:inp.ageGroup||'',genderPlacement:inp.genderPlacement||'',ageGroupPlacement:inp.ageGroupPlacement||'',splits:inp.splits||{swim:'',t1:'',bike:'',t2:'',run:'',total:''}};
              setProposedEvent(proposed);setForm(proposed);setStage('reviewing');
            }
            return{type:'tool_result',tool_use_id:tu.id,content:result};
          });
          chain=[...chain,{role:'assistant',content:resp.content},{role:'user',content:toolResults}];
          if(textContent){setIsStreaming(true);setStreamText('');await typewriter(textContent,chunk=>setStreamText(chunk));setMsgs(prev=>[...prev,{role:'assistant',content:textContent}]);setIsStreaming(false);setStreamText('');}
          if(toolUses.some(tu=>tu.name==='propose_event')){chainRef.current=chain;setLoading(false);return;}
          continue;
        }
        break;
      }
      chainRef.current=chain;setLoading(false);
    }catch(err){setLoading(false);setIsStreaming(false);setMsgs(prev=>[...prev,{role:'assistant',content:`Something went wrong: ${err.message}. Try again.`}]);}
  },[appState]);

  useEffect(()=>{
    const initMsg={role:'user',content:'I want to add a new goal, race, or PR.'};
    setMsgs([initMsg]);runTurn([initMsg]);
  },[]);

  const sendReply=()=>{
    const t=input.trim();if(!t||loading||isStreaming)return;
    const userMsg={role:'user',content:t};
    const updated=[...msgs,userMsg];setMsgs(updated);setInput('');
    if(stage==='reviewing'){setStage('chatting');setProposedEvent(null);setForm(null);}
    const fullChain=[...chainRef.current,{role:'user',content:t}];runTurn(fullChain);
  };

  const upd=(k,v)=>setForm(f=>({...f,[k]:v}));
  const updSplit=(k,v)=>setForm(f=>({...f,splits:{...f.splits,[k]:v}}));

  const handleSave=()=>{
    if(!form||!form.name.trim())return;
    const preset=presetById(form.presetId);
    const isTri=preset?.planType==='tri';
    const ev={id:uid(),presetId:form.presetId,mode:form.mode,name:form.name,date:form.date,location:form.location,goal:form.goal,stretchGoal:form.stretchGoal,baseline:form.baseline,result:isTri&&form.splits?.total?form.splits.total:form.result,url:form.url,placement:form.placement,bibNumber:form.bibNumber,ageGroup:form.ageGroup,genderPlacement:form.genderPlacement,ageGroupPlacement:form.ageGroupPlacement,splits:form.splits,completed:form.mode==='race'||form.mode==='pr'};
    onSave(ev);setStage('done');
  };

  const preset=form?presetById(form.presetId):null;
  const isTri=preset?.planType==='tri';
  const isConversational=!loading&&!isStreaming&&msgs.length>1&&stage==='chatting';

  return(<Sheet onClose={onClose} title="Add with AI">
    <div style={{maxHeight:stage==='reviewing'?'25vh':'55vh',overflowY:'auto',display:'flex',flexDirection:'column',gap:10,marginBottom:16}}>
      {msgs.filter(m=>m.role==='assistant').map((m,i)=>(
        <div key={i} className="fade-up" style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.75}}>{renderMd(m.content)}</div>
      ))}
      {isStreaming&&streamText&&<div className="fade-up" style={{fontFamily:F.ui,fontSize:14,color:C.text,lineHeight:1.75}}>{renderMd(streamText)}</div>}
      {loading&&!isStreaming&&<div style={{display:'flex',alignItems:'center',gap:8,padding:'8px 0'}}><DotsLoader color={C.accent}/><span style={{fontFamily:F.ui,fontSize:12,color:C.muted}}>Thinking...</span></div>}
      <div ref={bottomRef}/>
    </div>

    {stage==='reviewing'&&form&&preset&&<>
      <div style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:C.green,textTransform:'uppercase',letterSpacing:'.08em',marginBottom:10}}>Review & edit</div>
      <div style={{display:'flex',alignItems:'center',gap:10,marginBottom:16,padding:'10px 14px',background:preset.color+'10',borderRadius:12,border:`1.5px solid ${preset.color}30`}}>
        <Icon name={preset.icon} size={18} color={preset.color}/>
        <span style={{fontFamily:F.ui,fontWeight:700,fontSize:14,color:preset.color}}>{preset.label}</span>
        <Pill color={form.mode==='goal'?C.accent:form.mode==='race'?C.yellow:C.green} small>{form.mode==='goal'?'Goal':form.mode==='race'?'Race':'PR'}</Pill>
      </div>
      <div style={{display:'flex',flexDirection:'column',gap:10,marginBottom:16}}>
        <div><Label>Name *</Label><Inp value={form.name} onChange={e=>upd('name',e.target.value)} placeholder="Event name"/></div>
        <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:8}}>
          <div><Label>Date</Label><Inp type="date" value={form.date} onChange={e=>upd('date',e.target.value)}/></div>
          {form.mode!=='pr'&&<div><Label>Location</Label><Inp value={form.location} onChange={e=>upd('location',e.target.value)} placeholder="City, State"/></div>}
        </div>
        {form.mode==='goal'&&<>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:8}}>
            <div><Label>{preset.goalLabel||'Goal'}</Label><Inp value={form.goal} onChange={e=>upd('goal',e.target.value)} placeholder="e.g. 3:30"/></div>
            <div><Label>Stretch goal</Label><Inp value={form.stretchGoal} onChange={e=>upd('stretchGoal',e.target.value)} placeholder="e.g. 3:15"/></div>
          </div>
          <div><Label>Current PR</Label><Inp value={form.baseline} onChange={e=>upd('baseline',e.target.value)} placeholder="Your best so far"/></div>
        </>}
        {form.mode==='race'&&!isTri&&<>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:8}}>
            <div><Label>{preset.resultLabel||'Result'}</Label><Inp value={form.result} onChange={e=>upd('result',e.target.value)} placeholder="e.g. 3:28:15"/></div>
            <div><Label>Goal was</Label><Inp value={form.goal} onChange={e=>upd('goal',e.target.value)} placeholder="What you aimed for"/></div>
          </div>
        </>}
        {form.mode==='pr'&&<>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:8}}>
            <div><Label>{preset.resultLabel||'Result'}</Label><Inp value={form.result} onChange={e=>upd('result',e.target.value)} placeholder="e.g. 4:58 or 315 lbs"/></div>
            <div><Label>Previous best</Label><Inp value={form.baseline} onChange={e=>upd('baseline',e.target.value)} placeholder="Old PR"/></div>
          </div>
        </>}
        <div><Label>Race website</Label><Inp value={form.url} onChange={e=>upd('url',e.target.value)} placeholder="https://..." type="url"/></div>
      </div>
      <div style={{display:'flex',gap:10}}>
        <Btn onClick={()=>{setStage('chatting');setProposedEvent(null);setForm(null);}} outline style={{flex:1}}>Keep chatting</Btn>
        <Btn onClick={handleSave} color={preset.color} disabled={!form.name.trim()} style={{flex:2}}>
          {form.mode==='goal'?'Save goal':form.mode==='race'?'Save race':'Save PR'}
        </Btn>
      </div>
    </>}

    {stage==='done'&&<Btn onClick={onClose} color={C.green} style={{width:'100%',padding:13,fontSize:15}}>Done</Btn>}

    {(isConversational||stage==='reviewing')&&<div style={{display:'flex',gap:8,marginTop:stage==='reviewing'?12:0}}>
      <Inp ref={inputRef} value={input} onChange={e=>setInput(e.target.value)} onKeyDown={e=>e.key==='Enter'&&sendReply()} placeholder={stage==='reviewing'?'Want to change something? Just say it...':'Describe your goal, race, or PR...'} style={{flex:1}}/>
      <button onClick={sendReply} disabled={!input.trim()} style={{width:48,height:48,background:!input.trim()?C.elevated:C.accent,border:'none',borderRadius:12,cursor:!input.trim()?'not-allowed':'pointer',color:!input.trim()?C.muted:'#fff',fontSize:18,display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>↑</button>
    </div>}
  </Sheet>);
}
