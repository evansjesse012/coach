"use client";
import React from "react";
import { C, S, F } from '../../lib/theme.js';
import { exSlug, fmtPR, fmtDateSh, epley } from '../../lib/utils.js';
import { Sheet, Label, Card, Pill } from '../../ui/primitives.js';

export function ExerciseDetailSheet({ exerciseName, strengthHistory, prs, onClose }) {
  const slug = exSlug(exerciseName);
  const pr = prs[slug];

  const sessions = [];
  for (const s of strengthHistory) {
    const ex = s.exercises?.find(e => (e.slug || exSlug(e.name || '')) === slug || e.exerciseId === slug);
    if (ex) {
      const completedSets = ex.sets?.filter(s => s.completed) || [];
      if (completedSets.length > 0) {
        const exType = ex.exerciseType || 'weighted';
        const bestSet = exType === 'timed'
          ? completedSets.reduce((b, s) => (s.duration || 0) > (b.duration || 0) ? s : b)
          : exType === 'weighted'
            ? completedSets.reduce((b, s) => epley(s.weight || 0, s.reps || 0) > epley(b.weight || 0, b.reps || 0) ? s : b)
            : completedSets.reduce((b, s) => (s.reps || 0) > (b.reps || 0) ? s : b);
        sessions.push({ date: s.date, name: s.name, sets: completedSets, bestSet, exerciseType: exType });
      }
    }
  }
  sessions.sort((a, b) => b.date.localeCompare(a.date));

  const totalSessions = sessions.length;
  const lastPerformed = sessions[0]?.date;
  const exerciseType = sessions[0]?.exerciseType || 'weighted';

  const fmtSet = (s, et) => et === 'timed' ? `${s.duration}s` : et === 'banded' ? `${s.band} ×${s.reps}` : s.weight > 0 ? `${s.weight} × ${s.reps}` : `${s.reps} reps`;
  const fmtBest = (s, et) => et === 'timed' ? `${s.duration}s` : et === 'weighted' && s.weight > 0 ? `${s.weight}lb × ${s.reps}` : `${s.reps} reps`;

  return (
    <Sheet onClose={onClose} title={exerciseName}>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 10, marginBottom: 20 }}>
        <Card style={{ textAlign: 'center', padding: '14px 8px' }}>
          <div style={{ fontFamily: F.display, fontSize: 24, fontWeight: 700, color: C.text, lineHeight: 1 }}>{totalSessions}</div>
          <div style={{ fontFamily: F.ui, fontSize: 11, color: C.muted, marginTop: 5 }}>Sessions</div>
        </Card>
        <Card style={{ textAlign: 'center', padding: '14px 8px' }}>
          <div style={{ fontFamily: F.display, fontSize: 24, fontWeight: 700, color: C.green, lineHeight: 1 }}>{pr ? fmtPR(pr) : '—'}</div>
          <div style={{ fontFamily: F.ui, fontSize: 11, color: C.muted, marginTop: 5 }}>PR</div>
        </Card>
        <Card style={{ textAlign: 'center', padding: '14px 8px' }}>
          <div style={{ fontFamily: F.display, fontSize: 24, fontWeight: 700, color: C.cyan, lineHeight: 1 }}>{lastPerformed ? fmtDateSh(lastPerformed) : '—'}</div>
          <div style={{ fontFamily: F.ui, fontSize: 11, color: C.muted, marginTop: 5 }}>Last done</div>
        </Card>
      </div>

      {pr?.history?.length > 0 && <div style={{ marginBottom: 20 }}>
        <Label>PR progression</Label>
        <Card style={{ padding: '12px 16px' }}>
          {[...(pr.history || []), { ...pr }].map((h, i, arr) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '6px 0', borderTop: i > 0 ? `1px solid ${C.border}` : 'none' }}>
              <div style={{ width: 8, height: 8, borderRadius: '50%', background: i === arr.length - 1 ? C.green : C.muted, flexShrink: 0 }} />
              <span style={{ fontFamily: F.mono, fontSize: 13, color: i === arr.length - 1 ? C.green : C.text, fontWeight: i === arr.length - 1 ? 700 : 400, flex: 1 }}>{fmtPR(h)}</span>
              <span style={{ fontFamily: F.ui, fontSize: 11, color: C.muted }}>{h.date ? fmtDateSh(h.date) : ''}</span>
            </div>
          ))}
        </Card>
      </div>}

      <Label>History ({totalSessions} session{totalSessions !== 1 ? 's' : ''})</Label>
      {sessions.map((s, i) => (
        <Card key={i} style={{ marginBottom: 8, padding: '12px 16px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
            <span style={{ fontFamily: F.ui, fontSize: 13, fontWeight: 600, color: C.text }}>{s.date ? fmtDateSh(s.date) : '—'}</span>
            <span style={{ fontFamily: F.mono, fontSize: 12, color: C.green, fontWeight: 600 }}>Best: {fmtBest(s.bestSet, s.exerciseType)}</span>
          </div>
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
            {s.sets.map((set, j) => (
              <span key={j} style={{ fontFamily: F.mono, fontSize: 12, color: C.subtle, background: C.elevated, borderRadius: 8, padding: '4px 10px' }}>{fmtSet(set, s.exerciseType)}</span>
            ))}
          </div>
        </Card>
      ))}

      {totalSessions === 0 && <Card style={{ textAlign: 'center', padding: 32 }}>
        <div style={{ fontFamily: F.ui, fontSize: 14, color: C.muted }}>No history yet for this exercise.</div>
      </Card>}
    </Sheet>
  );
}
