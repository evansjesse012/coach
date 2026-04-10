import { presetById } from '../lib/constants.js';
import { uid } from '../lib/utils.js';

export function generateWeeklyPlan(events) {
  const active=events.filter(e=>!e.completed);
  if (!active.length) return [];
  const types=[...new Set(active.map(e=>presetById(e.presetId).planType))];
  const hasTri=types.includes('tri'),hasRun=types.includes('run'),hasStr=types.includes('strength');
  if (hasTri) return [
    {day:'Monday',    sessions:[{type:'strength',label:'Strength A',notes:'Lower focus — leg press, split squats, Nordics',fuel:'Pre: light snack 60min before · Post: protein + carbs within 30min',sport:'strength'}]},
    {day:'Tuesday',   sessions:[{type:'run',sport:'run',duration:45,label:'Easy Run',notes:'Zone 2 · conversational pace',fuel:'Pre: banana + coffee 90min before · Post: protein shake or chocolate milk'},{type:'swim',sport:'swim',duration:30,label:'Swim',notes:'Technique drills · 1500–2000m',fuel:'Pre: light snack if needed · water during'}]},
    {day:'Wednesday', sessions:[{type:'strength',label:'Strength B',notes:'Upper focus — pull-ups, face pulls',fuel:'Pre: light snack 60min before · Post: protein + carbs within 30min',sport:'strength'}]},
    {day:'Thursday',  sessions:[{type:'bike',sport:'bike',duration:60,label:'Zone 2 Ride',notes:'Steady aerobic effort',fuel:'Pre: oatmeal or toast 2hrs before · During: water + electrolytes · Post: recovery meal'},{type:'run',sport:'run',duration:20,label:'Brick Run',notes:'Off the bike · easy pace',fuel:'Practice race-day nutrition — eat what you\'ll use on race day'}]},
    {day:'Friday',    sessions:[]},
    {day:'Saturday',  sessions:[{type:'bike',sport:'bike',duration:90,label:'Long Ride',notes:'Build endurance · practice fueling',fuel:'Pre: full breakfast 2-3hrs before (60-80g carbs) · During: 1 gel every 45min + electrolytes · Post: protein + carbs within 30min'}]},
    {day:'Sunday',    sessions:[{type:'run',sport:'run',duration:75,label:'Long Run',notes:'Easy aerobic build',fuel:'Pre: oatmeal + banana 2hrs before · During: water, gel at 45min if needed · Post: recovery meal with protein'}]},
  ];
  if (hasRun) return [
    {day:'Monday',    sessions:[{type:'strength',label:'Strength',notes:'Strength + mobility',sport:'strength'}]},
    {day:'Tuesday',   sessions:[{type:'run',sport:'run',duration:40,label:'Easy Run',notes:'Comfortable, conversational'}]},
    {day:'Wednesday', sessions:[{type:'run',sport:'run',duration:50,label:'Tempo Run',notes:'Comfortably hard effort'}]},
    {day:'Thursday',  sessions:[{type:'strength',label:'Strength',notes:'Upper + core',sport:'strength'}]},
    {day:'Friday',    sessions:[]},
    {day:'Saturday',  sessions:[{type:'run',sport:'run',duration:90,label:'Long Run',notes:'Easy pace · build your base'}]},
    {day:'Sunday',    sessions:[{type:'run',sport:'run',duration:30,label:'Recovery Run',notes:'Very easy · flush the legs'}]},
  ];
  if (hasStr) return [
    {day:'Monday',    sessions:[{type:'strength',label:'Strength A',notes:'Lower body',sport:'strength'}]},
    {day:'Tuesday',   sessions:[{type:'other',sport:'other',duration:30,label:'Conditioning',notes:'Easy cardio · active recovery'}]},
    {day:'Wednesday', sessions:[{type:'strength',label:'Strength B',notes:'Upper + pull',sport:'strength'}]},
    {day:'Thursday',  sessions:[{type:'other',sport:'other',duration:30,label:'Cardio',notes:'Light cardio of choice'}]},
    {day:'Friday',    sessions:[{type:'strength',label:'Strength C',notes:'Full body',sport:'strength'}]},
    {day:'Saturday',  sessions:[]},{day:'Sunday',sessions:[]},
  ];
  return ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'].map(day=>({day,sessions:[]}));
}

export function getMockHealthWorkouts(){const types=['run','bike','swim','strength','hike'];const notes={run:['Morning run','Tempo intervals','Long run','Easy jog'],bike:['Z2 ride','Interval session','Long ride'],swim:['Pool session','Technique drills'],strength:['Gym session','Home workout'],hike:['Trail hike']};const durs={run:[25,35,45,55,70,90],bike:[45,60,75,90,120],swim:[30,40,50],strength:[45,55,65],hike:[60,90,120]};const w=[];for(let d=1;d<=14;d++){if(Math.random()>0.45){const date=new Date();date.setDate(date.getDate()-d);const sport=types[Math.floor(Math.random()*types.length)];w.push({id:`hk-${d}-${uid()}`,sport,duration:durs[sport][Math.floor(Math.random()*durs[sport].length)],notes:notes[sport][Math.floor(Math.random()*notes[sport].length)],date:date.toISOString().split('T')[0],source:'healthkit'});}}return w.sort((a,b)=>b.date.localeCompare(a.date));}
