-- 015_adherence_read_model.sql
-- Phase 3 of BACKEND_FOUNDATION_PLAN.md: honest, persisted adherence.
--
-- Today computeWeekAdherence (AdherenceComputation.swift:104-202) runs on the
-- DEVICE against the live (mutable) blob, and only a single scalar
-- weekly_reviews.adherence_pct (012:45) survives — so historical adherence is
-- silently recomputed against the edited plan, and the rich breakdown is thrown
-- away. Two changes fix that:
--
--   1. Add a 'week_start' source to weekly_plan_snapshots so a snapshot can be
--      frozen when the week BEGINS (the committed baseline), not only at
--      generation time. The pg-boss `freeze-week-start` job writes these.
--   2. Add week_adherence: the breakdown computed once, server-side, at week
--      close (the pg-boss `close-week-adherence` job), measured against the
--      week-start snapshot and persisted for exact, chartable history.

-- ─── Allow week-start snapshots ──────────────────────────────────────────────
-- The original inline CHECK (013:47) is auto-named weekly_plan_snapshots_source_check.
ALTER TABLE weekly_plan_snapshots
    DROP CONSTRAINT IF EXISTS weekly_plan_snapshots_source_check;
ALTER TABLE weekly_plan_snapshots
    ADD CONSTRAINT weekly_plan_snapshots_source_check
    CHECK (source IN ('create_plan', 'generate_week', 'regenerate_week', 'week_start'));

-- At most one week-start snapshot per (plan, week): the baseline is committed once.
CREATE UNIQUE INDEX idx_snapshots_week_start_unique
    ON weekly_plan_snapshots (plan_id, week_number)
    WHERE source = 'week_start';

-- ─── Persisted adherence read-model ──────────────────────────────────────────
CREATE TABLE week_adherence (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL DEFAULT auth.uid()
                     REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_id         TEXT NOT NULL REFERENCES training_plans(id) ON DELETE CASCADE,
    week_number     INTEGER NOT NULL,
    phase           INTEGER,
    prescribed      INTEGER NOT NULL DEFAULT 0,
    completed       INTEGER NOT NULL DEFAULT 0,
    shortened       INTEGER NOT NULL DEFAULT 0,
    missed          INTEGER NOT NULL DEFAULT 0,
    substituted     INTEGER NOT NULL DEFAULT 0,
    by_sport        JSONB NOT NULL DEFAULT '{}',
    adherence_pct   NUMERIC,
    snapshot_id     UUID REFERENCES weekly_plan_snapshots(id) ON DELETE SET NULL,
    computed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (week_number >= 1),
    UNIQUE (plan_id, week_number)        -- one adherence row per plan-week (upserted)
);

CREATE INDEX idx_week_adherence_user_plan
    ON week_adherence (user_id, plan_id, week_number);

ALTER TABLE week_adherence ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read their own week adherence"
    ON week_adherence FOR SELECT USING (user_id = auth.uid());
