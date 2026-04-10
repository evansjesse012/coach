import { computeWeekAdherence, computeMultiWeekPatterns } from './adherence.js';
import { db } from '../lib/db.js';
import { uid } from '../lib/utils.js';

export function executeTool(name, input, appState) {
  const { cardio=[], strength=[], prs={}, events=[], memory={}, plan=[], nutrition=[], trainingPlan=null, bricks=[] } = appState;
  const today = new Date().toISOString().split('T')[0];
  const fD = m => { if(!m)return'0m'; const h=Math.floor(m/60),mn=m%60; return h>0?(mn>0?`${h}h ${mn}m`:`${h}h`):`${mn}m`; };
  switch (name) {
    case 'get_workouts': {
      const { sport='all', days=30, limit=20 } = input;
      const cutoff=new Date(); cutoff.setDate(cutoff.getDate()-days);
      const brickIds=new Map();bricks.forEach(b=>b.legs.forEach(l=>brickIds.set(l.workoutId,{brickId:b.id,transitionTime:b.transitionTime,transitionNotes:b.transitionNotes})));
      const all=[...cardio.map(w=>{const r={date:w.date,sport:w.sport,duration:w.duration,notes:w.notes||'',id:w.id};const bl=brickIds.get(w.id);if(bl)r.brick=bl;return r;}),...strength.map(s=>({date:s.date,sport:'strength',name:s.name,duration:s.duration,sets:s.exercises?.reduce((t,e)=>t+(e.sets?.filter(x=>x.completed)?.length||0),0)||0}))].filter(w=>new Date(w.date+'T12:00:00')>=cutoff).filter(w=>sport==='all'||w.sport===sport).sort((a,b)=>b.date.localeCompare(a.date)).slice(0,limit);
      const brickCount=bricks.filter(b=>new Date(b.date+'T12:00:00')>=cutoff).length;
      return all.length ? JSON.stringify({count:all.length,bricksInPeriod:brickCount,workouts:all}) : `No ${sport==='all'?'':sport+' '}workouts in last ${days} days.`;
    }
    case 'get_training_plan': {
      const { includePhaseDetail=false, weekNumber=null } = input;
      const todayName=new Date().toLocaleString('en-US',{weekday:'long'});
      // If a periodized plan exists, return that
      if (trainingPlan) {
        const tp = trainingPlan;
        const currentPhase = tp.phases?.find(p=>p.number===tp.currentPhase) || tp.phases?.[0];
        const wk = weekNumber || tp.currentWeek || 1;
        const weekPlan = tp.weeklyPlans?.[String(wk)] || null;
        const weeksToRace = tp.raceDate ? Math.ceil((new Date(tp.raceDate+'T12:00:00')-new Date())/604800000) : null;
        const result = {
          hasPeriodizedPlan: true,
          raceName: tp.raceName,
          raceDate: tp.raceDate,
          weeksToRace,
          totalWeeks: tp.totalWeeks,
          currentWeek: tp.currentWeek,
          currentPhase: currentPhase ? { number:currentPhase.number, name:currentPhase.name, focus:currentPhase.focus, intensityCeiling:currentPhase.intensityCeiling, weeklyVolume:currentPhase.weeklyVolume, strengthFreq:currentPhase.strengthFreq } : null,
          trainingDaysPerWeek: tp.trainingDaysPerWeek,
          today: todayName,
        };
        if (includePhaseDetail) result.allPhases = tp.phases;
        if (weekPlan) {
          result.weekPlan = weekPlan;
        } else {
          result.weekPlanStatus = `Week ${wk} has not been generated yet. Use save_weekly_plan to generate and save it.`;
        }
        return JSON.stringify(result);
      }
      // Fallback to static plan
      if (!plan?.length) return 'No training plan. Athlete needs to create one from the Plan tab or add a goal first.';
      const todayC=cardio.filter(w=>w.date===today); const todayS=strength.filter(s=>s.date===today);
      return JSON.stringify({hasPeriodizedPlan:false,today:todayName,plan:plan.map(({day,sessions})=>({day,isToday:day===todayName,sessions:sessions.map(s=>({...s,completedToday:day===todayName?(s.type==='strength'?todayS.some(sh=>sh.name===s.label||sh.templateId===s.templateId):todayC.some(w=>w.sport===s.sport)):null})),isRestDay:sessions.length===0}))});
    }
    case 'get_training_stats': {
      const { weeks=4 } = input; const stats=[];
      for(let w=0;w<weeks;w++){const start=new Date();start.setDate(start.getDate()-start.getDay()-(w*7));start.setHours(0,0,0,0);const end=new Date(start);end.setDate(end.getDate()+7);const inW=d=>{const dt=new Date(d+'T12:00:00');return dt>=start&&dt<end;};const wC=cardio.filter(x=>inW(x.date));const wS=strength.filter(x=>inW(x.date));const bySport=wC.reduce((acc,x)=>{if(!acc[x.sport])acc[x.sport]={sessions:0,minutes:0};acc[x.sport].sessions++;acc[x.sport].minutes+=x.duration||0;return acc;},{});stats.push({label:w===0?'This week':w===1?'Last week':`${w} weeks ago`,cardioSessions:wC.length,strengthSessions:wS.length,totalSessions:wC.length+wS.length,totalMinutes:wC.reduce((s,x)=>s+(x.duration||0),0),bySport});}
      const allSorted=[...cardio,...strength].sort((a,b)=>b.date.localeCompare(a.date));
      const daysSince=allSorted[0]?.date?Math.floor((new Date()-new Date(allSorted[0].date+'T12:00:00'))/86400000):null;
      return JSON.stringify({weeklyBreakdown:stats,averageSessionsPerWeek:Math.round(stats.reduce((s,w)=>s+w.totalSessions,0)/stats.length*10)/10,totalLogged:cardio.length+strength.length,daysSinceLastWorkout:daysSince});
    }
    case 'get_personal_records': {
      const { exercise='all' } = input;
      if (!Object.keys(prs).length) return 'No PRs recorded yet.';
      const records=exercise==='all'?Object.entries(prs).map(([ex,pr])=>({exercise:ex,...pr})):Object.entries(prs).filter(([ex])=>ex.toLowerCase().includes(exercise.toLowerCase())).map(([ex,pr])=>({exercise:ex,...pr}));
      return records.length ? JSON.stringify({records}) : `No PRs found for "${exercise}".`;
    }
    case 'get_goals': {
      const { include_completed=false } = input;
      const filtered=include_completed?events:events.filter(e=>!e.completed);
      return filtered.length ? JSON.stringify({goals:filtered.map(e=>({name:e.name,type:e.presetId,location:e.location,date:e.date,daysAway:e.date?Math.ceil((new Date(e.date+'T12:00:00')-new Date())/86400000):null,goal:e.goal,stretchGoal:e.stretchGoal,baseline:e.baseline,completed:e.completed}))}) : 'No active goals.';
    }
    case 'get_athlete_profile': return (!memory||!Object.keys(memory).length) ? 'No coaching memory yet.' : JSON.stringify(memory);
    case 'log_workout': {
      const { sport, duration, notes='', date=today } = input;
      if (!sport||!duration) return JSON.stringify({error:'sport and duration required'});
      return JSON.stringify({logged:true,workout:{sport,duration,notes,date}});
    }
    case 'log_nutrition': {
      const { meal, timing='general', relatedWorkout='', date=today } = input;
      if (!meal) return JSON.stringify({error:'nutrition description is required'});
      return JSON.stringify({logged:true,nutrition:{description:meal,timing,relatedWorkout,date}});
    }
    case 'get_nutrition': {
      const { days=7, timing='all' } = input;
      const cutoff=new Date(); cutoff.setDate(cutoff.getDate()-days);
      const filtered=nutrition.filter(m=>new Date(m.date+'T12:00:00')>=cutoff).filter(m=>timing==='all'||m.timing===timing).sort((a,b)=>b.date.localeCompare(a.date));
      if (!filtered.length) return `No nutrition logged in the last ${days} days.`;
      return JSON.stringify({count:filtered.length,nutrition:filtered});
    }
    case 'save_training_plan': {
      const { goalId, raceName, raceDate, startDate, totalWeeks, trainingDaysPerWeek=5, phases } = input;
      if (!goalId||!phases?.length) return JSON.stringify({error:'goalId and phases are required'});
      const plan = { id:'plan_'+uid(), goalId, raceName, raceDate, startDate, totalWeeks, currentWeek:1, currentPhase:1, trainingDaysPerWeek, phases, weeklyPlans:{}, createdAt:today };
      return JSON.stringify({saved:true,plan});
    }
    case 'save_weekly_plan': {
      const { weekNumber, phase, focusOfWeek, sessions } = input;
      if (!weekNumber||!sessions?.length) return JSON.stringify({error:'weekNumber and sessions are required'});
      const weekPlan = { weekNumber, phase, generatedAt:today, focusOfWeek, sessions };
      return JSON.stringify({saved:true,weekPlan});
    }
    case 'update_plan_progress': {
      const { currentWeek, currentPhase, notes='' } = input;
      return JSON.stringify({updated:true,currentWeek,currentPhase,notes});
    }
    case 'get_week_review': {
      const { weekNumber=null, includeMultiWeek=false } = input;
      if (!trainingPlan) return JSON.stringify({error:'No training plan exists.'});
      const wk = weekNumber || Math.max(1, (trainingPlan.currentWeek || 1) - 1);
      const review = computeWeekAdherence(trainingPlan, wk, cardio, strength);
      if (!review) return JSON.stringify({error:`Week ${wk} has not been generated yet.`});
      const result = {
        weekNumber: wk,
        prescribed: review.prescribed,
        completed: review.completed,
        shortened: review.shortened,
        missed: review.missed,
        substituted: review.substituted,
        adherence: review.adherence + '%',
        missedByType: review.missedByType,
        days: review.days.map(d => ({
          day: d.day, date: d.dateStr, isRest: d.isRest,
          sessions: d.sessions.map(s => ({
            type: s.type, label: s.label, prescribed: s.duration ? s.duration + 'min' : null,
            status: s.status, actual: s.actualDuration ? s.actualDuration + 'min' : null,
            substitute: s.substitute || null
          }))
        }))
      };
      if (includeMultiWeek) {
        result.multiWeekPatterns = computeMultiWeekPatterns(trainingPlan, trainingPlan.currentWeek, cardio, strength);
      }
      return JSON.stringify(result);
    }
    case 'get_plan_history': {
      const history = db.get('coach_plan_history', []);
      if (!history.length) return JSON.stringify({ message: 'No past training plans on record.' });
      return JSON.stringify(history.map(h => ({
        raceName: h.raceName, raceDate: h.raceDate,
        startDate: h.startDate, endedDate: h.endedDate,
        endReason: h.endReason, endNotes: h.endNotes || '',
        completedWeeks: h.completedWeeks, totalWeeks: h.totalWeeks,
        phasesCompleted: h.phasesCompleted, totalPhases: h.totalPhases,
        phases: h.phases,
        adherence: h.adherence
      })));
    }
    default: return JSON.stringify({error:`Unknown tool: ${name}`});
  }
}