"use client";
import React from "react";
import { C, S, F } from '../../lib/theme.js';
import { fmtDur, fmtDateSh, epley } from '../../lib/utils.js';
import { Sheet, Label, Card } from '../../ui/primitives.js';

export function StrengthDetailSheet({ workout, prs, onClose }) {
  const totalVol = (workout.exercises || []).reduce((s, e) =>
    (e.exerciseType || 'weighted') === 'weighted'
      ? s + (e.sets || []).filter(ss => ss.completed).reduce((ss, set) => ss + ((set.weight || 0) * (set.reps || 0)), 0)
      : s, 0);
  const totalSets = (workout.exercises || []).reduce((s, e) => s + (e.sets || []).filter(ss => ss.completed).length, 0);

  return (
    <Sheet onClose={onClose} title={workout.name || 'Strength Workout'}>
      <div style={{ fontFamily: F.ui, fontSize: 13, color: C.muted, marginBottom: 14 }}>
        {workout.date ? fmtDateSh(workout.date) : '—'}
        {workout.duration ? ` · ${fmtDur(workout.duration)}` : ''}
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 10, marginBottom: 20 }}>
        <Card style={{ textAlign: 'center', padding: '12px 8px' }}>
          <div style={{ fontFamily: F.display, fontSize: 22, fontWeight: 700, color: C.cyan, lineHeight: 1 }}>{fmtDur(workout.duration)}</div>
          <div style={{ fontFamily: F.ui, fontSize: 11, color: C.muted, marginTop: 4 }}>Duration</div>
        </Card>
        <Card style={{ textAlign: 'center', padding: '12px 8px' }}>
          <div style={{ fontFamily: F.display, fontSize: 22, fontWeight: 700, color: C.text, lineHeight: 1 }}>{totalVol > 0 ? `${(totalVol / 1000).toFixed(1)}k` : totalSets}</div>
          <div style={{ fontFamily: F.ui, fontSize: 11, color: C.muted, marginTop: 4 }}>{totalVol > 0 ? 'Volume (lb)' : 'Sets'}</div>
        </Card>
        <Card style={{ textAlign: 'center', padding: '12px 8px' }}>
          <div style={{ fontFamily: F.display, fontSize: 22, fontWeight: 700, color: C.green, lineHeight: 1 }}>{totalSets}</div>
          <div style={{ fontFamily: F.ui, fontSize: 11, color: C.muted, marginTop: 4 }}>Sets</div>
        </Card>
      </div>

      {(workout.exercises || []).map((ex, ei) => {
        const eType = ex.exerciseType || 'weighted';
        const completedSets = (ex.sets || []).filter(s => s.completed);
        if (!completedSets.length) return null;
        return (
          <Card key={ei} style={{ marginBottom: 10, padding: '12px 16px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
              <div style={{ fontFamily: F.ui, fontWeight: 700, fontSize: 15, color: C.accent }}>{ex.name}</div>
              {eType === 'weighted' && <span style={{ fontFamily: F.ui, fontSize: 11, fontWeight: 600, color: C.muted }}>1RM</span>}
            </div>
            {completedSets.map((set, si) => {
              const est1RM = eType === 'weighted' && set.weight > 0 ? epley(set.weight, set.reps) : 0;
              return (
                <div key={si} style={{ display: 'flex', alignItems: 'center', padding: '5px 0', borderTop: si > 0 ? `1px solid ${C.border}` : 'none' }}>
                  <span style={{ fontFamily: F.mono, fontSize: 12, color: C.muted, width: 24 }}>{si + 1}</span>
                  <span style={{ flex: 1, fontFamily: F.mono, fontSize: 14, color: C.text }}>
                    {eType === 'timed' ? `${set.duration}s` : eType === 'banded' ? `${set.band} × ${set.reps}` : set.weight > 0 ? `${set.weight} lb × ${set.reps}` : `${set.reps} reps`}
                  </span>
                  {est1RM > 0 && <span style={{ fontFamily: F.mono, fontSize: 13, color: C.muted, fontWeight: 500 }}>{est1RM}</span>}
                </div>
              );
            })}
          </Card>
        );
      })}
    </Sheet>
  );
}
