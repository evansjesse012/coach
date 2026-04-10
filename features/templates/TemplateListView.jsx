"use client";
import React from "react";
import { C, S, F } from '../../lib/theme.js';
import { Icon } from '../../lib/icons.js';
import { fmtDateSh } from '../../lib/utils.js';
import { BODY_PART_COLORS } from '../../lib/constants.js';
import { lookupExercise } from '../../lib/exercises.js';
import { Card, Btn, Label, Pill } from '../../ui/primitives.js';
import { confirmDialog } from '../../ui/confirm.js';

export function TemplateListView({ templates, onStartTemplate, onEditTemplate, onDeleteTemplate, onCreate }) {
  if (!templates.length) return (
    <div>
      <Card onClick={onCreate} accent={C.accent} style={{ textAlign: 'center', padding: 32, cursor: 'pointer' }}>
        <div style={{ marginBottom: 12 }}><Icon name='plus' size={36} color={C.accent} /></div>
        <div style={{ fontFamily: F.display, fontSize: 18, fontWeight: 700, color: C.text, marginBottom: 6 }}>Create a Template</div>
        <div style={{ fontFamily: F.ui, fontSize: 14, color: C.subtle }}>Build custom workout routines with exercises from the library.</div>
      </Card>
    </div>
  );

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
        <Label style={{ marginBottom: 0 }}>{templates.length} template{templates.length !== 1 ? 's' : ''}</Label>
        <button onClick={onCreate} style={{ background: C.accent+'15', border: `1.5px solid ${C.accent}30`, borderRadius: 10, padding: '5px 14px', fontFamily: F.ui, fontSize: 12, fontWeight: 600, color: C.accent, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 4 }}><Icon name='plus' size={13} color={C.accent} /> New</button>
      </div>
      {templates.map(t => {
        const bodyParts = [...new Set(t.exercises.map(e => {
          const dbEx = lookupExercise(e.name);
          return dbEx?.bodyPart || 'Other';
        }))].slice(0, 3);
        return (
          <Card key={t.id} style={{ marginBottom: 10, padding: 0, overflow: 'hidden' }}>
            <div style={{ padding: '14px 16px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 8 }}>
                <div>
                  <div style={{ fontFamily: F.display, fontSize: 18, fontWeight: 700, color: C.text }}>{t.name}</div>
                  <div style={{ fontFamily: F.ui, fontSize: 12, color: C.muted, marginTop: 2 }}>
                    {t.exercises.length} exercise{t.exercises.length !== 1 ? 's' : ''}
                    {t.lastUsed ? ` · Last: ${fmtDateSh(t.lastUsed)}` : ''}
                  </div>
                </div>
                <div style={{ display: 'flex', gap: 6 }}>
                  <button onClick={() => onEditTemplate(t)} style={{ width: 32, height: 32, borderRadius: 10, background: C.elevated, border: `1px solid ${C.border}`, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: C.subtle }}><Icon name='pencil' size={14} /></button>
                  <button onClick={async () => { const ok = await confirmDialog('Delete template?', `"${t.name}" will be removed.`); if (ok) onDeleteTemplate(t.id); }} style={{ width: 32, height: 32, borderRadius: 10, background: C.elevated, border: `1px solid ${C.border}`, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: C.subtle }}><span style={{ fontSize: 14 }}>✕</span></button>
                </div>
              </div>
              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 10 }}>
                {bodyParts.map(bp => <Pill key={bp} color={BODY_PART_COLORS[bp] || C.muted} small>{bp}</Pill>)}
              </div>
              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 4 }}>
                {t.exercises.slice(0, 5).map((ex, i) => (
                  <span key={i} style={{ fontFamily: F.ui, fontSize: 12, color: C.subtle }}>{ex.sets || 3} × {ex.name}{i < Math.min(t.exercises.length, 5) - 1 ? ',' : ''}</span>
                ))}
                {t.exercises.length > 5 && <span style={{ fontFamily: F.ui, fontSize: 12, color: C.muted }}>+{t.exercises.length - 5} more</span>}
              </div>
            </div>
            <button onClick={() => onStartTemplate(t)} style={{ width: '100%', padding: '12px', background: C.accent+'10', border: 'none', borderTop: `1px solid ${C.border}`, fontFamily: F.display, fontSize: 15, fontWeight: 700, color: C.accent, cursor: 'pointer', transition: 'background .15s' }} onMouseEnter={e => e.currentTarget.style.background=C.accent+'20'} onMouseLeave={e => e.currentTarget.style.background=C.accent+'10'}>Start Workout</button>
          </Card>
        );
      })}
    </div>
  );
}
