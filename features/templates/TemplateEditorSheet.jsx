"use client";
import React, { useState } from "react";
import { C, S, F } from '../../lib/theme.js';
import { Icon } from '../../lib/icons.js';
import { uid, todayStr, exSlug } from '../../lib/utils.js';
import { BODY_PART_COLORS } from '../../lib/constants.js';
import { lookupExercise } from '../../lib/exercises.js';
import { Sheet, Btn, Inp, Card, Label } from '../../ui/primitives.js';
import { ExerciseAvatar, ExercisePickerSheet } from '../exercises/ExerciseLibrary.jsx';

export function TemplateEditorSheet({ template, customExercises, onSave, onClose }) {
  const [name, setName] = useState(template?.name || '');
  const [exercises, setExercises] = useState(template?.exercises || []);
  const [showPicker, setShowPicker] = useState(false);

  const moveEx = (idx, dir) => {
    const newIdx = idx + dir;
    if (newIdx < 0 || newIdx >= exercises.length) return;
    const arr = [...exercises];
    [arr[idx], arr[newIdx]] = [arr[newIdx], arr[idx]];
    setExercises(arr);
  };

  const removeEx = (idx) => setExercises(prev => prev.filter((_, i) => i !== idx));

  const updateEx = (idx, field, value) => setExercises(prev => prev.map((e, i) => i !== idx ? e : { ...e, [field]: value }));

  const addExercises = (picked) => {
    const newExs = picked.map(ex => ({
      name: ex.name, slug: exSlug(ex.name), exerciseType: ex.exerciseType || 'weighted',
      sets: 3, reps: ex.exerciseType === 'timed' ? undefined : 10,
      duration: ex.exerciseType === 'timed' ? 30 : undefined,
      weight: 0, rest: 60, notes: ''
    }));
    setExercises(prev => [...prev, ...newExs]);
    setShowPicker(false);
  };

  const handleSave = () => {
    if (!name.trim() || exercises.length === 0) return;
    onSave({
      id: template?.id || uid(),
      name: name.trim(),
      exercises,
      createdAt: template?.createdAt || todayStr(),
      lastUsed: template?.lastUsed || null
    });
  };

  return (
    <Sheet onClose={onClose} title={template ? 'Edit Template' : 'New Template'}>
      <Label>Template Name</Label>
      <Inp placeholder="e.g. Push Day, Upper Body, Leg Day..." value={name} onChange={e => setName(e.target.value)} style={{ marginBottom: 16 }} />
      <Label>Exercises ({exercises.length})</Label>
      {exercises.map((ex, i) => {
        const dbEx = lookupExercise(ex.name);
        const bpColor = BODY_PART_COLORS[dbEx?.bodyPart] || C.muted;
        return (
          <Card key={i} style={{ marginBottom: 8, padding: '10px 14px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8 }}>
              <ExerciseAvatar name={ex.name} bodyPart={dbEx?.bodyPart || 'Other'} size={30} />
              <div style={{ flex: 1, minWidth: 0, fontFamily: F.ui, fontWeight: 600, fontSize: 14, color: C.text, overflow: 'hidden', whiteSpace: 'nowrap', textOverflow: 'ellipsis' }}>{ex.name}</div>
              <div style={{ display: 'flex', gap: 4 }}>
                <button onClick={() => moveEx(i, -1)} disabled={i === 0} style={{ width: 26, height: 26, borderRadius: 8, background: C.elevated, border: 'none', cursor: i === 0 ? 'default' : 'pointer', color: i === 0 ? C.muted+'40' : C.muted, fontSize: 12, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name='chevUp' size={12} /></button>
                <button onClick={() => moveEx(i, 1)} disabled={i === exercises.length - 1} style={{ width: 26, height: 26, borderRadius: 8, background: C.elevated, border: 'none', cursor: i === exercises.length - 1 ? 'default' : 'pointer', color: i === exercises.length - 1 ? C.muted+'40' : C.muted, fontSize: 12, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name='chevDown' size={12} /></button>
                <button onClick={() => removeEx(i)} style={{ width: 26, height: 26, borderRadius: 8, background: C.elevated, border: 'none', cursor: 'pointer', color: C.red, fontSize: 14, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>✕</button>
              </div>
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: F.ui, fontSize: 10, fontWeight: 600, color: C.muted, marginBottom: 3 }}>SETS</div>
                <input type="number" value={ex.sets || 3} onChange={e => updateEx(i, 'sets', parseInt(e.target.value) || 1)} style={{ width: '100%', background: C.elevated, border: `1px solid ${C.border}`, borderRadius: 8, padding: '6px 8px', fontFamily: F.mono, fontSize: 14, color: C.text, textAlign: 'center', outline: 'none' }} />
              </div>
              {ex.exerciseType === 'timed' ? <div style={{ flex: 1 }}>
                <div style={{ fontFamily: F.ui, fontSize: 10, fontWeight: 600, color: C.muted, marginBottom: 3 }}>SECS</div>
                <input type="number" value={ex.duration || 30} onChange={e => updateEx(i, 'duration', parseInt(e.target.value) || 0)} style={{ width: '100%', background: C.elevated, border: `1px solid ${C.border}`, borderRadius: 8, padding: '6px 8px', fontFamily: F.mono, fontSize: 14, color: C.text, textAlign: 'center', outline: 'none' }} />
              </div> : <div style={{ flex: 1 }}>
                <div style={{ fontFamily: F.ui, fontSize: 10, fontWeight: 600, color: C.muted, marginBottom: 3 }}>REPS</div>
                <input type="number" value={ex.reps || 10} onChange={e => updateEx(i, 'reps', parseInt(e.target.value) || 0)} style={{ width: '100%', background: C.elevated, border: `1px solid ${C.border}`, borderRadius: 8, padding: '6px 8px', fontFamily: F.mono, fontSize: 14, color: C.text, textAlign: 'center', outline: 'none' }} />
              </div>}
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: F.ui, fontSize: 10, fontWeight: 600, color: C.muted, marginBottom: 3 }}>REST</div>
                <input type="number" value={ex.rest || 60} onChange={e => updateEx(i, 'rest', parseInt(e.target.value) || 0)} style={{ width: '100%', background: C.elevated, border: `1px solid ${C.border}`, borderRadius: 8, padding: '6px 8px', fontFamily: F.mono, fontSize: 14, color: C.text, textAlign: 'center', outline: 'none' }} />
              </div>
            </div>
          </Card>
        );
      })}

      <button onClick={() => setShowPicker(true)} style={{ width: '100%', padding: '12px', borderRadius: 14, background: C.elevated, border: `2px dashed ${C.border}`, fontFamily: F.ui, fontSize: 14, fontWeight: 600, color: C.accent, cursor: 'pointer', marginBottom: 20, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6 }}><Icon name='plus' size={16} color={C.accent} /> Add Exercise</button>

      <div style={{ display: 'flex', gap: 10 }}>
        <Btn onClick={onClose} outline style={{ flex: 1 }}>Cancel</Btn>
        <Btn onClick={handleSave} disabled={!name.trim() || exercises.length === 0} color={C.green} style={{ flex: 2 }}>Save Template</Btn>
      </div>

      {showPicker && <ExercisePickerSheet customExercises={customExercises} onPick={addExercises} onClose={() => setShowPicker(false)} multi />}
    </Sheet>
  );
}
