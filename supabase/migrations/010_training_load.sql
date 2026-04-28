-- 010_training_load.sql
-- Phase 1 of the training-load redesign:
--   * `daily_training_load`  — one row per (user_id, date) holding the
--     authoritative CTL/ATL/TSB and a JSONB breakdown of the per-workout
--     TSS sources that produced the day's total. Past rows are immutable
--     by default; only edits to a workout in the row's date range trigger
--     a forward recompute (handled client-side in TrainingLoadService).
--   * `benchmark_history` — versioned timeline of athlete thresholds
--     (LTHR, FTP, threshold pace, CSS, max HR). TSS for a workout dated
--     2024-08-15 uses the row whose `effective_from <= 2024-08-15` and is
--     the latest such row, so historical workouts get historical
--     thresholds instead of being recomputed against today's FTP.

-- ─── Daily training load ────────────────────────────────────────────────
CREATE TABLE daily_training_load (
    user_id     UUID    NOT NULL DEFAULT auth.uid()
                         REFERENCES auth.users(id) ON DELETE CASCADE,
    date        DATE    NOT NULL,
    total_tss   NUMERIC NOT NULL DEFAULT 0,
    ctl         NUMERIC NOT NULL DEFAULT 0,    -- chronic load (fitness, τ=42)
    atl         NUMERIC NOT NULL DEFAULT 0,    -- acute load   (fatigue, τ=7)
    tsb         NUMERIC NOT NULL DEFAULT 0,    -- ctl − atl (form)
    sources     JSONB   NOT NULL DEFAULT '[]'::jsonb,
                                               -- [{workoutId, kind:"cardio"|"strength",
                                               --   tss, method, confidence:"high"|"medium"|"low"}]
    computed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    recompute_reason TEXT,                     -- "initial" | "new_workout" |
                                               -- "workout_edited" | "workout_deleted" |
                                               -- "threshold_changed" | "backfill"
    PRIMARY KEY (user_id, date)
);

CREATE INDEX idx_daily_training_load_user_date_desc
    ON daily_training_load (user_id, date DESC);

ALTER TABLE daily_training_load ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own training load"
    ON daily_training_load FOR ALL USING (user_id = auth.uid());

-- ─── Benchmark history (versioned thresholds) ───────────────────────────
CREATE TABLE benchmark_history (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID    NOT NULL DEFAULT auth.uid()
                             REFERENCES auth.users(id) ON DELETE CASCADE,
    kind            TEXT    NOT NULL,
                             -- "lthr" | "max_hr" | "ftp" | "threshold_pace" |
                             -- "css" | "vo2max" | other free-form metrics
    value           NUMERIC NOT NULL,
    unit            TEXT,                      -- "bpm" | "watts" | "min/mi" | "min/100m" | etc.
    effective_from  DATE    NOT NULL,
    source          TEXT    NOT NULL DEFAULT 'manual',
                             -- "manual" | "test" | "estimated" | "imported"
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Picking the threshold for a workout dated D is:
--   SELECT value FROM benchmark_history
--   WHERE user_id = $u AND kind = $k AND effective_from <= D
--   ORDER BY effective_from DESC LIMIT 1
-- This index makes that lookup an index seek.
CREATE INDEX idx_benchmark_history_user_kind_eff
    ON benchmark_history (user_id, kind, effective_from DESC);

ALTER TABLE benchmark_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own benchmark history"
    ON benchmark_history FOR ALL USING (user_id = auth.uid());

-- ─── Backfill from coaching_memory.benchmarks ───────────────────────────
-- Existing benchmarks live as a JSONB array on coaching_memory. We seed
-- them as today-effective rows so future TSS computations have something
-- to use. We don't pretend to know historical effective dates — those
-- will be filled in over time as the athlete (or coach AI) records new
-- benchmark values, each with its own effective_from.
INSERT INTO benchmark_history (user_id, kind, value, unit, effective_from, source, notes)
SELECT
    cm.user_id,
    -- Normalize the metric key to a stable lowercase slug.
    lower(regexp_replace(coalesce(b->>'metric', ''), '\s+', '_', 'g')) AS kind,
    -- The legacy schema stores `value` as text ("165 bpm", "265", "6:30"),
    -- so we extract the leading numeric portion. Anything we can't parse is
    -- skipped (the WHERE filter below).
    NULLIF(
        substring(coalesce(b->>'value', '') from '^[0-9]+(\.[0-9]+)?'),
        ''
    )::numeric AS value,
    -- Best-effort unit: inferred from common patterns; otherwise null.
    CASE
        WHEN coalesce(b->>'value', '') ~* 'bpm'    THEN 'bpm'
        WHEN coalesce(b->>'value', '') ~* 'watts?' THEN 'watts'
        WHEN coalesce(b->>'value', '') ~* '/mi'    THEN 'min/mi'
        WHEN coalesce(b->>'value', '') ~* '/km'    THEN 'min/km'
        WHEN coalesce(b->>'value', '') ~* '/100m'  THEN 'min/100m'
        ELSE NULL
    END AS unit,
    CURRENT_DATE AS effective_from,
    'imported' AS source,
    'Backfilled from coaching_memory at migration time' AS notes
FROM coaching_memory cm,
     LATERAL jsonb_array_elements(coalesce(cm.benchmarks, '[]'::jsonb)) AS b
WHERE
    -- Skip rows we can't parse a numeric value out of.
    substring(coalesce(b->>'value', '') from '^[0-9]+(\.[0-9]+)?') IS NOT NULL
    AND coalesce(b->>'metric', '') <> '';
