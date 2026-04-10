// ─── Memory ────────────────────────────────────────────────────────────────────
export const MEMORY_KEY = 'coach_memory_v2';
export const defaultMemory = () => ({
  permanent: {
    equipment: [], facilities: [],
    schedule: { availableDays: 0, preferredTimes: '', constraints: [] },
    medicalHistory: [], dietaryConstraints: [],
    communicationPrefs: '',
    safetyRules: []
  },
  benchmarks: [],
  injuries: [],
  observations: {
    patterns: [], motivators: [], consistency: '', currentFocus: '', openItems: [], coachingNotes: []
  },
  responseProfile: {
    volumeVsIntensity: '', recoveryRate: '', easyDayDiscipline: '', sessionPreferences: '', skipPatterns: [], communicationNeeds: ''
  },
  conversationSummaries: [],
  periodSummaries: [],
  lastUpdated: ''
});

export const migrateV1toV2 = (old) => {
  const m = defaultMemory();
  // Permanent tier from profile
  if (old.profile?.equipment) m.permanent.equipment = old.profile.equipment.split(/,\s*/).map(s=>s.trim()).filter(Boolean);
  if (old.profile?.preferredWorkoutTimes) m.permanent.schedule.preferredTimes = old.profile.preferredWorkoutTimes;
  if (old.profile?.communicationStyle) m.permanent.communicationPrefs = old.profile.communicationStyle;
  // Injuries
  if (old.physical?.injuries?.length) {
    m.injuries = old.physical.injuries.map(inj => ({
      id: (inj.area||'').toLowerCase().replace(/\s+/g,'-'),
      area: inj.area||'', status: inj.status||'monitoring', severity: '',
      firstReported: inj.date||'', lastUpdated: inj.date||'',
      triggers: [], safeActivities: [], modifications: [], returnCriteria: '',
      history: inj.notes ? [{ date: inj.date||'', note: inj.notes }] : []
    }));
  }
  // Observations from behavioral + coaching + strengths/limiters
  if (old.behavioral?.patterns?.length) m.observations.patterns = [...old.behavioral.patterns];
  if (old.behavioral?.motivators?.length) m.observations.motivators = [...old.behavioral.motivators];
  if (old.behavioral?.consistency) m.observations.consistency = old.behavioral.consistency;
  if (old.coaching?.currentFocus) m.observations.currentFocus = old.coaching.currentFocus;
  if (old.coaching?.openItems?.length) m.observations.openItems = [...old.coaching.openItems];
  const notes = [];
  if (old.coaching?.notes?.length) notes.push(...old.coaching.notes);
  if (old.physical?.strengths?.length) notes.push(...old.physical.strengths.map(s=>`Strength: ${s}`));
  if (old.physical?.limiters?.length) notes.push(...old.physical.limiters.map(l=>`Limiter: ${l}`));
  m.observations.coachingNotes = notes;
  // Conversation summaries
  if (old.conversationSummaries?.length) {
    m.conversationSummaries = old.conversationSummaries.map(s =>
      typeof s === 'string' ? { date: '', summary: s } : s
    );
  }
  m.lastUpdated = old.lastUpdated || new Date().toISOString().split('T')[0];
  return m;
};

export const loadMemory = () => {
  try {
    const v2 = localStorage.getItem('coach_memory_v2');
    if (v2) return JSON.parse(v2);
    const v1 = localStorage.getItem('coach_memory_v1');
    if (v1) {
      const old = JSON.parse(v1);
      if (old.profile || old.physical || old.behavioral) {
        const migrated = migrateV1toV2(old);
        saveMemory(migrated);
        return migrated;
      }
    }
    return defaultMemory();
  } catch { return defaultMemory(); }
};
export const saveMemory = m => { try { localStorage.setItem(MEMORY_KEY, JSON.stringify(m)); } catch {} };

// Merge helpers
const _mergeAdditive = (target, source) => { const s = new Set(target); source.forEach(v => { if (v && !s.has(v)) { target.push(v); s.add(v); } }); };
const _mergeFuzzy = (target, source) => {
  source.forEach(v => {
    if (!v) return;
    const vl = v.toLowerCase();
    const isDupe = target.some(existing => {
      const el = existing.toLowerCase();
      return el === vl || (vl.length >= 15 && el.includes(vl)) || (el.length >= 15 && vl.includes(el));
    });
    if (!isDupe) target.push(v);
  });
};
const _mergeBenchmarks = (target, source) => {
  source.forEach(b => {
    if (!b?.metric) return;
    const idx = target.findIndex(e => e.metric === b.metric);
    if (idx >= 0) { if (!target[idx].testDate || (b.testDate && b.testDate > target[idx].testDate)) target[idx] = { ...target[idx], ...b }; }
    else target.push(b);
  });
};
const _mergeInjuries = (target, source) => {
  source.forEach(inj => {
    if (!inj?.area) return;
    const idx = target.findIndex(e => e.id === inj.id || e.area?.toLowerCase() === inj.area?.toLowerCase());
    if (idx >= 0) {
      const existing = target[idx];
      if (inj.status) existing.status = inj.status;
      if (inj.severity) existing.severity = inj.severity;
      if (inj.triggers?.length) _mergeAdditive(existing.triggers = existing.triggers || [], inj.triggers);
      if (inj.safeActivities?.length) _mergeAdditive(existing.safeActivities = existing.safeActivities || [], inj.safeActivities);
      if (inj.modifications?.length) _mergeAdditive(existing.modifications = existing.modifications || [], inj.modifications);
      if (inj.returnCriteria) existing.returnCriteria = inj.returnCriteria;
      if (inj.history?.length) (existing.history = existing.history || []).push(...inj.history);
      existing.lastUpdated = new Date().toISOString().split('T')[0];
    } else {
      target.push({ id: inj.id || (inj.area||'').toLowerCase().replace(/\s+/g,'-'), triggers: [], safeActivities: [], modifications: [], history: [], ...inj, lastUpdated: new Date().toISOString().split('T')[0] });
    }
  });
};
const _mergeSafetyRules = (target, source) => {
  source.forEach(r => {
    if (!r?.rule) return;
    if (!target.some(e => e.rule === r.rule)) target.push({ ...r, addedDate: r.addedDate || new Date().toISOString().split('T')[0] });
  });
};

export const mergeMemory = (existing, update) => {
  if (!update) return existing;
  const m = JSON.parse(JSON.stringify(existing));
  // Ensure all tiers exist (defensive)
  if (!m.permanent) m.permanent = defaultMemory().permanent;
  if (!m.benchmarks) m.benchmarks = [];
  if (!m.injuries) m.injuries = [];
  if (!m.observations) m.observations = defaultMemory().observations;
  if (!m.responseProfile) m.responseProfile = defaultMemory().responseProfile;
  if (!m.conversationSummaries) m.conversationSummaries = [];
  if (!m.periodSummaries) m.periodSummaries = [];
  // Permanent
  if (update.permanent) {
    ['equipment','facilities','medicalHistory','dietaryConstraints'].forEach(k => {
      if (update.permanent[k]?.length) _mergeAdditive(m.permanent[k] = m.permanent[k] || [], update.permanent[k]);
    });
    if (update.permanent.schedule) {
      if (!m.permanent.schedule) m.permanent.schedule = { availableDays: 0, preferredTimes: '', constraints: [] };
      if (update.permanent.schedule.availableDays > 0) m.permanent.schedule.availableDays = update.permanent.schedule.availableDays;
      if (update.permanent.schedule.preferredTimes?.trim()) m.permanent.schedule.preferredTimes = update.permanent.schedule.preferredTimes;
      if (update.permanent.schedule.constraints?.length) _mergeAdditive(m.permanent.schedule.constraints, update.permanent.schedule.constraints);
    }
    if (update.permanent.communicationPrefs?.trim()) m.permanent.communicationPrefs = update.permanent.communicationPrefs;
    if (update.permanent.safetyRules?.length) _mergeSafetyRules(m.permanent.safetyRules = m.permanent.safetyRules || [], update.permanent.safetyRules);
  }
  // Benchmarks
  if (update.benchmarks?.length) _mergeBenchmarks(m.benchmarks, update.benchmarks);
  // Injuries
  if (update.injuries?.length) _mergeInjuries(m.injuries, update.injuries);
  // Observations
  if (update.observations) {
    ['patterns','motivators','coachingNotes'].forEach(k => {
      if (update.observations[k]?.length) _mergeFuzzy(m.observations[k] = m.observations[k] || [], update.observations[k]);
    });
    if (update.observations.consistency?.trim()) m.observations.consistency = update.observations.consistency;
    if (update.observations.currentFocus?.trim()) m.observations.currentFocus = update.observations.currentFocus;
    if (update.observations.openItems?.length) _mergeAdditive(m.observations.openItems = m.observations.openItems || [], update.observations.openItems);
  }
  // Response profile
  if (update.responseProfile) {
    ['volumeVsIntensity','recoveryRate','easyDayDiscipline','sessionPreferences','communicationNeeds'].forEach(k => {
      if (update.responseProfile[k]?.trim()) m.responseProfile[k] = update.responseProfile[k];
    });
    if (update.responseProfile.skipPatterns?.length) _mergeAdditive(m.responseProfile.skipPatterns = m.responseProfile.skipPatterns || [], update.responseProfile.skipPatterns);
  }
  // Conversation summary
  if (update.conversationSummary) {
    m.conversationSummaries.push({ date: new Date().toISOString().split('T')[0], summary: update.conversationSummary });
  }
  m.lastUpdated = new Date().toISOString().split('T')[0];
  return m;
};

export const MEMORY_EXTRACTION_PROMPT = `Analyze this coaching conversation and extract new facts about the athlete.
Return ONLY a JSON object (no markdown). Only include fields with genuinely new information — omit empty fields.

Classify each fact into the correct tier:
- permanent: equipment, facilities, schedule, medical history, dietary constraints, communication preferences, safety rules (things that rarely change)
- benchmarks: test results with metric name, value, date, method
- injuries: body area, status (active/monitoring/resolved), severity (mild/moderate/severe), triggers, safe activities, modifications
- observations: training patterns, motivators, consistency notes, coaching focus, open items, coaching notes
- responseProfile: how this athlete responds to training. Only update fields where you have clear evidence from the conversation:
  - volumeVsIntensity: does the athlete get fitter from more easy miles, or from harder sessions? (e.g. "improves with volume, breaks down with speed work")
  - recoveryRate: how quickly do they bounce back from hard sessions? (e.g. "always wiped the day after intervals", "recovers fast, can handle back-to-back hard days")
  - easyDayDiscipline: do they run easy days too hard? (e.g. "easy runs are always 8:30 pace, should be 9:30+")
  - sessionPreferences: what do they gravitate toward or avoid? (e.g. "loves long rides, dreads the pool")
  - skipPatterns: what gets dropped first under stress? (e.g. "swim is the first thing cut", "skips evening sessions")
  - communicationNeeds: what coaching style lands? (e.g. "wants data and rationale", "responds to accountability", "needs encouragement not criticism")

JSON shape:
{"permanent":{"equipment":[],"facilities":[],"schedule":{"availableDays":0,"preferredTimes":"","constraints":[]},"medicalHistory":[],"dietaryConstraints":[],"communicationPrefs":"","safetyRules":[{"rule":"","reason":""}]},
"benchmarks":[{"metric":"","value":"","testDate":"","method":""}],
"injuries":[{"area":"","status":"","severity":"","triggers":[],"safeActivities":[],"modifications":[],"returnCriteria":"","history":[{"date":"","note":""}]}],
"observations":{"patterns":[],"motivators":[],"consistency":"","currentFocus":"","openItems":[],"coachingNotes":[]},
"responseProfile":{"volumeVsIntensity":"","recoveryRate":"","easyDayDiscipline":"","sessionPreferences":"","skipPatterns":[],"communicationNeeds":""},
"conversationSummary":"1-2 sentence summary"}`;