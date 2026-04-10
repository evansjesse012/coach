// ─── Adherence Computation ────────────────────────────────────────────────────
export function computeWeekAdherence(tp, weekNum, cardio, strength) {
  if (!tp?.weeklyPlans) return null;
  const wp = tp.weeklyPlans[String(weekNum)];
  if (!wp) return null;
  const planStart = new Date(tp.startDate + 'T00:00:00');
  const weekMonday = new Date(planStart);
  weekMonday.setDate(weekMonday.getDate() + (weekNum - 1) * 7);
  // Adjust to Monday if startDate isn't Monday
  const startDay = weekMonday.getDay();
  if (startDay !== 1) weekMonday.setDate(weekMonday.getDate() - ((startDay + 6) % 7));
  const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const todayStr_ = new Date().toISOString().split('T')[0];
  const days = (wp.sessions || []).map((dayObj, di) => {
    const dayDate = new Date(weekMonday);
    dayDate.setDate(dayDate.getDate() + di);
    const dateStr = dayDate.toISOString().split('T')[0];
    const isPast = dateStr < todayStr_;
    const isToday = dateStr === todayStr_;
    const dayCardio = cardio.filter(w => w.date === dateStr);
    const dayStrength = strength.filter(s => s.date === dateStr);
    const sessions = (dayObj.sessions || []).map(sess => {
      if (sess.type === 'brick') {
        const legsDone = (sess.legs || []).every(l => dayCardio.some(w => w.sport === l.sport));
        return { ...sess, status: legsDone ? 'completed' : (isPast ? 'missed' : 'upcoming'), dateStr };
      }
      const isStr = sess.type === 'strength';
      if (isStr) {
        const match = dayStrength.find(s => s.name === sess.label || s.templateId === sess.templateId);
        if (match) return { ...sess, status: 'completed', actualDuration: match.duration, dateStr };
        return { ...sess, status: isPast ? 'missed' : 'upcoming', dateStr };
      }
      const match = dayCardio.find(w => w.sport === sess.type);
      if (match) {
        const ratio = sess.duration ? match.duration / sess.duration : 1;
        return { ...sess, status: ratio >= 0.8 ? 'completed' : 'shortened', actualDuration: match.duration, dateStr };
      }
      // Check if different sport was logged (substitution)
      const anySport = dayCardio.length > 0 && !dayObj.sessions.some(s => s.type !== 'strength' && dayCardio.some(w => w.sport === s.type));
      if (isPast && anySport && dayCardio.length > 0) return { ...sess, status: 'substituted', substitute: dayCardio[0].sport, dateStr };
      return { ...sess, status: isPast ? 'missed' : (isToday ? 'today' : 'upcoming'), dateStr };
    });
    return { day: dayObj.day, dateStr, isPast, isToday, isRest: dayObj.isRest, sessions };
  });
  const allSessions = days.flatMap(d => d.sessions);
  const prescribed = allSessions.length;
  const completed = allSessions.filter(s => s.status === 'completed').length;
  const shortened = allSessions.filter(s => s.status === 'shortened').length;
  const missed = allSessions.filter(s => s.status === 'missed').length;
  const substituted = allSessions.filter(s => s.status === 'substituted').length;
  const missedByType = {};
  allSessions.filter(s => s.status === 'missed').forEach(s => { const t = s.type || 'other'; missedByType[t] = (missedByType[t] || 0) + 1; });
  const adherence = prescribed > 0 ? Math.round((completed + shortened * 0.5) / prescribed * 100) : 100;
  return { weekNumber: weekNum, days, prescribed, completed, shortened, missed, substituted, adherence, missedByType };
}

export function computeMultiWeekPatterns(tp, currentWeek, cardio, strength, lookback = 4) {
  const patterns = [];
  const weekReviews = [];
  for (let w = Math.max(1, currentWeek - lookback); w < currentWeek; w++) {
    const review = computeWeekAdherence(tp, w, cardio, strength);
    if (review) weekReviews.push(review);
  }
  if (!weekReviews.length) return patterns;
  // Detect sport-specific miss patterns
  const sportMissCounts = {};
  weekReviews.forEach(r => Object.entries(r.missedByType).forEach(([sport, count]) => { sportMissCounts[sport] = (sportMissCounts[sport] || 0) + count; }));
  Object.entries(sportMissCounts).forEach(([sport, count]) => {
    const weeksWithMiss = weekReviews.filter(r => r.missedByType[sport]).length;
    if (weeksWithMiss >= 2) patterns.push(`${sport} missed in ${weeksWithMiss} of last ${weekReviews.length} weeks (${count} total sessions)`);
  });
  // Detect adherence trend
  const adherences = weekReviews.map(r => r.adherence);
  if (adherences.length >= 3) {
    const recent = adherences.slice(-2);
    const earlier = adherences.slice(0, -2);
    const recentAvg = recent.reduce((a, b) => a + b, 0) / recent.length;
    const earlierAvg = earlier.reduce((a, b) => a + b, 0) / earlier.length;
    if (recentAvg < earlierAvg - 15) patterns.push(`Adherence declining: ${Math.round(earlierAvg)}% → ${Math.round(recentAvg)}%`);
    if (recentAvg > earlierAvg + 15) patterns.push(`Adherence improving: ${Math.round(earlierAvg)}% → ${Math.round(recentAvg)}%`);
  }
  return patterns;
}