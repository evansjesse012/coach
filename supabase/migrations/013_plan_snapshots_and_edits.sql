-- 013_plan_snapshots_and_edits.sql
-- Plan retrospective: snapshot the week at generation time + log every edit.
--
-- The training plan lived as a single mutable JSONB blob on
-- `training_plans.weekly_plans` (migration 001). `patch_weekly_plan`
-- rewrites that blob in place, so once a week is edited the "as
-- originally planned" version is lost. Two new tables fix that:
--
--   * `weekly_plan_snapshots` — one row per plan-generation event
--     (week populated by `create_training_plan` or `generate_week_plan`).
--     Immutable. Holds the full week as it was generated. Multiple rows
--     per (plan, week) are allowed: a regen via `generate_week_plan`
--     writes a fresh row and the prior one stays for history. The most
--     recent row by `frozen_at` is "the plan the athlete is currently
--     trying to follow."
--
--   * `plan_edits` — append-only log of every `patch_weekly_plan` op.
--     Captures the op payload, the affected slice before and after, and
--     the athlete's stated reason (when the model forwards one). Granular
--     at the op level so a multi-op patch produces multiple rows — each
--     row is what the retrospective UI renders as a single timeline entry.
--
-- Together they answer:
--   - "What was the plan originally?"   → most recent snapshot at-or-before t
--   - "What changed and why?"            → plan_edits since that snapshot
--   - "What's the plan right now?"       → training_plans.weekly_plans (unchanged)
--
-- The live JSONB blob stays the working copy; existing reads (adherence
-- math, Week tab, get_training_plan) keep functioning untouched. Snapshots
-- and the edit log are additive — no backfill required, pre-existing
-- weeks simply have no snapshot row until they're next regenerated.

-- ─── Weekly plan snapshots ──────────────────────────────────────────────
CREATE TABLE weekly_plan_snapshots (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL DEFAULT auth.uid()
                     REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_id         TEXT NOT NULL
                     REFERENCES training_plans(id) ON DELETE CASCADE,
    week_number     INTEGER NOT NULL,
    frozen_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    source          TEXT NOT NULL,        -- 'create_plan' | 'generate_week' | 'regenerate_week'
    sessions        JSONB NOT NULL,       -- WeeklyPlan.sessions at freeze time (7 day blobs)
    phase           INTEGER,              -- mirrors WeeklyPlan.phase at freeze time
    focus_of_week   TEXT,                 -- mirrors WeeklyPlan.focusOfWeek at freeze time
    CHECK (week_number >= 1),
    CHECK (source IN ('create_plan', 'generate_week', 'regenerate_week'))
);

CREATE INDEX idx_snapshots_user_plan_week_time
    ON weekly_plan_snapshots (user_id, plan_id, week_number, frozen_at DESC);

ALTER TABLE weekly_plan_snapshots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own snapshots"
    ON weekly_plan_snapshots FOR ALL USING (user_id = auth.uid());

-- ─── Plan edit log ──────────────────────────────────────────────────────
CREATE TABLE plan_edits (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL DEFAULT auth.uid()
                     REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_id         TEXT NOT NULL
                     REFERENCES training_plans(id) ON DELETE CASCADE,
    week_number     INTEGER NOT NULL,
    applied_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    snapshot_id     UUID
                     REFERENCES weekly_plan_snapshots(id) ON DELETE SET NULL,
                    -- The snapshot this edit was layered on top of —
                    -- the most-recent snapshot for (plan, week) as of
                    -- applied_at. Lets the retrospective bracket edits
                    -- under the snapshot they modified (useful when a
                    -- mid-week regen creates a new snapshot).
    op_type         TEXT NOT NULL,
    day             INTEGER,              -- 0..6; the affected day (or fromDay for move)
    session_index   INTEGER,              -- affected session index within day, when applicable
    payload         JSONB NOT NULL,       -- the raw op dict the model sent
    before_state    JSONB,                -- affected slice (day or session) BEFORE this op
    after_state     JSONB,                -- affected slice AFTER this op
    reason          TEXT,                 -- model-extracted athlete reason; nullable
    source          TEXT NOT NULL DEFAULT 'chat',
                                          -- 'chat' for model-driven; reserved for future origins
                                          -- (athlete_action, system, etc.)
    CHECK (op_type IN ('move', 'update', 'set_rest', 'add', 'delete')),
    CHECK (day IS NULL OR (day BETWEEN 0 AND 6)),
    CHECK (week_number >= 1)
);

CREATE INDEX idx_plan_edits_user_plan_week_time
    ON plan_edits (user_id, plan_id, week_number, applied_at DESC);

CREATE INDEX idx_plan_edits_snapshot
    ON plan_edits (snapshot_id);

ALTER TABLE plan_edits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own plan edits"
    ON plan_edits FOR ALL USING (user_id = auth.uid());
