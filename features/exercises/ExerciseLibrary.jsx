"use client";
import React, { useState, useRef, useMemo } from "react";
import { C, S, F } from '../../lib/theme.js';
import { Icon } from '../../lib/icons.js';
import { exSlug, fmtPR } from '../../lib/utils.js';
import { BODY_PART_COLORS, BODY_PARTS, CATEGORIES } from '../../lib/constants.js';
import { getExerciseDB } from '../../lib/exercises.js';
import { Inp, Card, Btn, Pill, Sheet } from '../../ui/primitives.js';

export function ExerciseAvatar({name, bodyPart, size=36}) {
  const color = BODY_PART_COLORS[bodyPart] || C.muted;
  const letter = (name||'?')[0].toUpperCase();
  return (<div style={{width:size,height:size,borderRadius:size/2,background:color+'20',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
    <span style={{fontFamily:F.display,fontSize:size*0.42,fontWeight:700,color,lineHeight:1}}>{letter}</span>
  </div>);
}

export function NewExerciseSheet({ onSave, onClose }) {
  const [name, setName] = useState('');
  const [bodyPart, setBP] = useState('Chest');
  const [category, setCat] = useState('Barbell');
  const [exerciseType, setET] = useState('weighted');
  const types = ['weighted', 'bodyweight', 'banded', 'timed', 'cardio-drill'];
  return (
    <Sheet onClose={onClose} title="New Exercise">
      <label style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:C.muted,textTransform:'uppercase',letterSpacing:'.08em',marginBottom:10,display:'block'}}>Exercise Name</label>
      <Inp placeholder="e.g. Zercher Squat" value={name} onChange={e => setName(e.target.value)} style={{ marginBottom: 16 }} />
      <label style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:C.muted,textTransform:'uppercase',letterSpacing:'.08em',marginBottom:10,display:'block'}}>Body Part</label>
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 16 }}>
        {BODY_PARTS.map(bp => <button key={bp} onClick={() => setBP(bp)} style={{ padding: '6px 12px', borderRadius: 16, background: bp === bodyPart ? (BODY_PART_COLORS[bp]||C.accent)+'20' : C.elevated, border: `1.5px solid ${bp === bodyPart ? (BODY_PART_COLORS[bp]||C.accent) : C.border}`, color: bp === bodyPart ? (BODY_PART_COLORS[bp]||C.accent) : C.muted, fontFamily: F.ui, fontSize: 12, fontWeight: 600, cursor: 'pointer' }}>{bp}</button>)}
      </div>
      <label style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:C.muted,textTransform:'uppercase',letterSpacing:'.08em',marginBottom:10,display:'block'}}>Category</label>
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 16 }}>
        {CATEGORIES.map(cat => <button key={cat} onClick={() => setCat(cat)} style={{ padding: '6px 12px', borderRadius: 16, background: cat === category ? C.accent+'20' : C.elevated, border: `1.5px solid ${cat === category ? C.accent : C.border}`, color: cat === category ? C.accent : C.muted, fontFamily: F.ui, fontSize: 12, fontWeight: 600, cursor: 'pointer' }}>{cat}</button>)}
      </div>
      <label style={{fontFamily:F.ui,fontSize:12,fontWeight:600,color:C.muted,textTransform:'uppercase',letterSpacing:'.08em',marginBottom:10,display:'block'}}>Exercise Type</label>
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 24 }}>
        {types.map(t => <button key={t} onClick={() => setET(t)} style={{ padding: '6px 12px', borderRadius: 16, background: t === exerciseType ? C.green+'20' : C.elevated, border: `1.5px solid ${t === exerciseType ? C.green : C.border}`, color: t === exerciseType ? C.green : C.muted, fontFamily: F.ui, fontSize: 12, fontWeight: 600, cursor: 'pointer' }}>{t}</button>)}
      </div>
      <Btn onClick={() => { if (!name.trim()) return; onSave({ name: name.trim(), bodyPart, category, exerciseType }); }} disabled={!name.trim()} color={C.green} style={{ width: '100%' }}>Add Exercise</Btn>
    </Sheet>
  );
}

export function ExercisePickerSheet({ customExercises, onPick, onClose, multi }) {
  const [search, setSearch] = useState('');
  const [bodyPartFilter, setBPF] = useState('');
  const [categoryFilter, setCF] = useState('');
  const [selected, setSelected] = useState([]);

  const allExercises = useMemo(() => getExerciseDB(customExercises), [customExercises]);
  const filtered = useMemo(() => {
    let list = allExercises;
    if (search.trim()) { const q = search.toLowerCase(); list = list.filter(e => e.name.toLowerCase().includes(q)); }
    if (bodyPartFilter) list = list.filter(e => e.bodyPart === bodyPartFilter);
    if (categoryFilter) list = list.filter(e => e.category === categoryFilter);
    return list.sort((a, b) => a.name.localeCompare(b.name));
  }, [allExercises, search, bodyPartFilter, categoryFilter]);

  const toggleSelect = (ex) => {
    if (multi) {
      setSelected(prev => {
        const slug = exSlug(ex.name);
        return prev.some(e => exSlug(e.name) === slug) ? prev.filter(e => exSlug(e.name) !== slug) : [...prev, ex];
      });
    } else {
      onPick([ex]);
    }
  };

  return (
    <Sheet onClose={onClose} title={multi ? "Add Exercises" : "Pick Exercise"}>
      <div style={{ position: 'relative', marginBottom: 12 }}>
        <Inp placeholder="Search exercises..." value={search} onChange={e => setSearch(e.target.value)} style={{ paddingLeft: 40, padding: '11px 14px 11px 40px' }} />
        <div style={{ position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none' }}><Icon name='search' size={16} color={C.muted} /></div>
      </div>
      <div style={{ display: 'flex', gap: 6, marginBottom: 10, overflowX: 'auto', scrollbarWidth: 'none' }}>
        <button onClick={() => setBPF('')} style={{ padding: '5px 10px', borderRadius: 16, background: !bodyPartFilter ? C.accent+'20' : C.surface, border: `1px solid ${!bodyPartFilter ? C.accent : C.border}`, color: !bodyPartFilter ? C.accent : C.muted, fontFamily: F.ui, fontSize: 11, fontWeight: 600, cursor: 'pointer', flexShrink: 0 }}>All</button>
        {BODY_PARTS.map(bp => <button key={bp} onClick={() => setBPF(bp === bodyPartFilter ? '' : bp)} style={{ padding: '5px 10px', borderRadius: 16, background: bp === bodyPartFilter ? (BODY_PART_COLORS[bp]||C.accent)+'20' : C.surface, border: `1px solid ${bp === bodyPartFilter ? (BODY_PART_COLORS[bp]||C.accent) : C.border}`, color: bp === bodyPartFilter ? (BODY_PART_COLORS[bp]||C.accent) : C.muted, fontFamily: F.ui, fontSize: 11, fontWeight: 600, cursor: 'pointer', flexShrink: 0 }}>{bp}</button>)}
      </div>
      <div style={{ maxHeight: '50vh', overflowY: 'auto', margin: '0 -20px', padding: '0 20px' }}>
        {filtered.map(ex => {
          const slug = exSlug(ex.name);
          const isSel = multi && selected.some(e => exSlug(e.name) === slug);
          return (
            <div key={slug} onClick={() => toggleSelect(ex)} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 4px', cursor: 'pointer', borderBottom: `1px solid ${C.border}15`, background: isSel ? C.green+'0A' : 'transparent' }}>
              <ExerciseAvatar name={ex.name} bodyPart={ex.bodyPart} size={34} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontFamily: F.ui, fontWeight: 600, fontSize: 14, color: C.text, overflow: 'hidden', whiteSpace: 'nowrap', textOverflow: 'ellipsis' }}>{ex.name}</div>
                <div style={{ fontFamily: F.ui, fontSize: 11, color: BODY_PART_COLORS[ex.bodyPart] || C.muted }}>{ex.bodyPart} · {ex.category}</div>
              </div>
              {isSel && <div style={{ width: 24, height: 24, borderRadius: 12, background: C.green, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><span style={{ color: '#fff', fontSize: 14, fontWeight: 700 }}>✓</span></div>}
            </div>
          );
        })}
      </div>
      {multi && <div style={{ marginTop: 16 }}>
        <Btn onClick={() => { if (selected.length > 0) onPick(selected); }} disabled={selected.length === 0} color={C.green} style={{ width: '100%' }}>Add {selected.length} exercise{selected.length !== 1 ? 's' : ''}</Btn>
      </div>}
    </Sheet>
  );
}

export function ExerciseLibrary({ strengthHistory, prs, customExercises, onSelectExercise, onAddCustom }) {
  const [search, setSearch] = useState('');
  const [bodyPartFilter, setBPF] = useState('');
  const [categoryFilter, setCF] = useState('');
  const [showNewEx, setShowNewEx] = useState(false);
  const listRef = useRef(null);

  const historyMap = useMemo(() => {
    const m = {};
    for (const s of strengthHistory) {
      for (const ex of (s.exercises || [])) {
        if (!ex.name) continue;
        const slug = ex.slug || exSlug(ex.name);
        if (!m[slug]) m[slug] = { sessions: 0, lastDate: '' };
        m[slug].sessions++;
        if (s.date > m[slug].lastDate) m[slug].lastDate = s.date;
      }
    }
    return m;
  }, [strengthHistory]);

  const allExercises = useMemo(() => {
    const db = getExerciseDB(customExercises);
    const slugSet = new Set(db.map(e => exSlug(e.name)));
    for (const s of strengthHistory) {
      for (const ex of (s.exercises || [])) {
        if (!ex.name) continue;
        const slug = ex.slug || exSlug(ex.name);
        if (!slugSet.has(slug)) {
          slugSet.add(slug);
          db.push({ name: ex.name, bodyPart: 'Other', category: 'Other', exerciseType: ex.exerciseType || 'weighted', fromHistory: true });
        }
      }
    }
    return db;
  }, [customExercises, strengthHistory]);

  const filtered = useMemo(() => {
    let list = allExercises;
    if (search.trim()) {
      const q = search.toLowerCase();
      list = list.filter(e => e.name.toLowerCase().includes(q));
    }
    if (bodyPartFilter) list = list.filter(e => e.bodyPart === bodyPartFilter);
    if (categoryFilter) list = list.filter(e => e.category === categoryFilter);
    return list.sort((a, b) => a.name.localeCompare(b.name));
  }, [allExercises, search, bodyPartFilter, categoryFilter]);

  const groups = useMemo(() => {
    const g = {};
    for (const ex of filtered) {
      const letter = ex.name[0].toUpperCase();
      if (!g[letter]) g[letter] = [];
      g[letter].push(ex);
    }
    return g;
  }, [filtered]);
  const letters = Object.keys(groups).sort();
  const allLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');

  const scrollToLetter = (l) => {
    const el = document.getElementById(`ex-section-${l}`);
    if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };

  const filterBtn = (label, active, onClick) => (
    <button onClick={onClick} style={{padding:'7px 14px',borderRadius:20,background:active?C.accent+'18':C.surface,border:`1.5px solid ${active?C.accent:C.border}`,color:active?C.accent:C.muted,fontFamily:F.ui,fontSize:12,fontWeight:600,cursor:'pointer',transition:'all .15s',flexShrink:0,whiteSpace:'nowrap'}}>{label}</button>
  );

  return (
    <div style={{ position: 'relative' }}>
      <div style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
        <div style={{ flex: 1, position: 'relative' }}>
          <Inp placeholder="Search exercises..." value={search} onChange={e => setSearch(e.target.value)} style={{ paddingLeft: 40, padding: '11px 14px 11px 40px' }} />
          <div style={{ position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none' }}><Icon name='search' size={16} color={C.muted} /></div>
        </div>
        <button onClick={() => setShowNewEx(true)} style={{ width: 44, height: 44, borderRadius: 12, background: C.accent+'15', border: `1.5px solid ${C.accent}30`, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: C.accent, flexShrink: 0 }}><Icon name='plus' size={18} color={C.accent} /></button>
      </div>

      <div style={{ display: 'flex', gap: 6, marginBottom: 6, overflowX: 'auto', scrollbarWidth: 'none', paddingBottom: 4 }}>
        {filterBtn(bodyPartFilter || 'Any Body Part', !!bodyPartFilter, () => setBPF(p => p ? '' : BODY_PARTS[0]))}
        {filterBtn(categoryFilter || 'Any Category', !!categoryFilter, () => setCF(p => p ? '' : CATEGORIES[0]))}
      </div>
      {bodyPartFilter && <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap', marginBottom: 10 }}>
        {BODY_PARTS.map(bp => <button key={bp} onClick={() => setBPF(bp === bodyPartFilter ? '' : bp)} style={{ padding: '5px 10px', borderRadius: 16, background: bp === bodyPartFilter ? (BODY_PART_COLORS[bp]||C.accent)+'20' : C.surface, border: `1px solid ${bp === bodyPartFilter ? (BODY_PART_COLORS[bp]||C.accent) : C.border}`, color: bp === bodyPartFilter ? (BODY_PART_COLORS[bp]||C.accent) : C.muted, fontFamily: F.ui, fontSize: 11, fontWeight: 600, cursor: 'pointer' }}>{bp}</button>)}
      </div>}
      {categoryFilter && <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap', marginBottom: 10 }}>
        {CATEGORIES.map(cat => <button key={cat} onClick={() => setCF(cat === categoryFilter ? '' : cat)} style={{ padding: '5px 10px', borderRadius: 16, background: cat === categoryFilter ? C.accent+'20' : C.surface, border: `1px solid ${cat === categoryFilter ? C.accent : C.border}`, color: cat === categoryFilter ? C.accent : C.muted, fontFamily: F.ui, fontSize: 11, fontWeight: 600, cursor: 'pointer' }}>{cat}</button>)}
      </div>}

      <div style={{ display: 'flex', gap: 0 }}>
        <div ref={listRef} style={{ flex: 1, minWidth: 0 }}>
          {filtered.length === 0 && <Card style={{ textAlign: 'center', padding: 32 }}>
            <div style={{ fontFamily: F.ui, fontSize: 14, color: C.muted }}>No exercises match your filters.</div>
          </Card>}
          {letters.map(letter => (
            <div key={letter} id={`ex-section-${letter}`}>
              <div style={{ fontFamily: F.display, fontSize: 14, fontWeight: 700, color: C.muted, padding: '10px 4px 4px', borderBottom: `1px solid ${C.border}`, marginBottom: 2 }}>{letter}</div>
              {groups[letter].map(ex => {
                const slug = exSlug(ex.name);
                const pr = prs[slug];
                const hist = historyMap[slug];
                const bpColor = BODY_PART_COLORS[ex.bodyPart] || C.muted;
                return (
                  <div key={slug} onClick={() => onSelectExercise(ex.name)} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 4px', cursor: 'pointer', borderBottom: `1px solid ${C.border}08`, transition: 'background .1s' }} onMouseEnter={e => e.currentTarget.style.background=C.elevated} onMouseLeave={e => e.currentTarget.style.background='transparent'}>
                    <ExerciseAvatar name={ex.name} bodyPart={ex.bodyPart} size={38} />
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ fontFamily: F.ui, fontWeight: 600, fontSize: 15, color: C.text, overflow: 'hidden', whiteSpace: 'nowrap', textOverflow: 'ellipsis' }}>{ex.name}</div>
                      <div style={{ fontFamily: F.ui, fontSize: 12, color: bpColor, marginTop: 1 }}>{ex.bodyPart}{hist ? ` · ${hist.sessions}x` : ''}</div>
                    </div>
                    {pr && <div style={{ textAlign: 'right', flexShrink: 0 }}>
                      <div style={{ fontFamily: F.mono, fontSize: 13, fontWeight: 700, color: C.green }}>{fmtPR(pr)}</div>
                    </div>}
                  </div>
                );
              })}
            </div>
          ))}
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '8px 2px', width: 22, flexShrink: 0, position: 'sticky', top: 100, alignSelf: 'flex-start' }}>
          {allLetters.map(l => {
            const hasEntries = letters.includes(l);
            return <button key={l} onClick={() => hasEntries && scrollToLetter(l)} style={{ background: 'none', border: 'none', padding: '1px 0', fontFamily: F.ui, fontSize: 10, fontWeight: 700, color: hasEntries ? C.accent : C.muted+'60', cursor: hasEntries ? 'pointer' : 'default', lineHeight: 1.4 }}>{l}</button>;
          })}
        </div>
      </div>

      {showNewEx && <NewExerciseSheet onSave={ex => { onAddCustom(ex); setShowNewEx(false); }} onClose={() => setShowNewEx(false)} />}
    </div>
  );
}
