-- 014_normalized_prescriptions.sql
-- Phase 2 of BACKEND_FOUNDATION_PLAN.md: move the live training plan out of the
-- single JSONB blob (training_plans.weekly_plans) into queryable rows, and split
-- the prescription lifecycle from the completion lifecycle.
--
-- Today one PrescribedSession struct (TrainingPlan.swift:234-306) carries BOTH
-- the prescription and the actuals (completionStatus, actualDuration, rpe, …),
-- and its id is the non-stable computed "type-label". These tables fix both:
-- stable UUID identity, soft-delete tombstones, and a separate completion ledger.
--
-- Contract: the backend (service-role connection) is the only writer. RLS below
-- grants the device (anon key, via PostgREST) READ access for the still-direct
-- read path (plan §3.3); it intentionally grants no client write — writes go
-- through the API. The service role bypasses RLS by design.

-- ─── Day-level properties (rest days are a property, not a fake row) ─────────
CREATE TABLE prescribed_days (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL DEFAULT auth.uid()
                     REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_id         TEXT NOT NULL REFERENCES training_plans(id) ON DELETE CASCADE,
    week_number     INTEGER NOT NULL,
    day             SMALLINT NOT NULL,            -- 0..6
    is_rest         BOOLEAN NOT NULL DEFAULT FALSE,
    rest_note       TEXT,
    CHECK (week_number >= 1),
    CHECK (day BETWEEN 0 AND 6),
    UNIQUE (plan_id, week_number, day)
);

CREATE INDEX idx_prescribed_days_plan_week
    ON prescribed_days (user_id, plan_id, week_number);

ALTER TABLE prescribed_days ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read their own prescribed days"
    ON prescribed_days FOR SELECT USING (user_id = auth.uid());

-- ─── The live, editable plan, as rows ────────────────────────────────────────
CREATE TABLE prescribed_workouts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL DEFAULT auth.uid()
                     REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_id         TEXT NOT NULL REFERENCES training_plans(id) ON DELETE CASCADE,
    week_number     INTEGER NOT NULL,
    day             SMALLINT NOT NULL,            -- 0..6
    position        SMALLINT NOT NULL DEFAULT 0,  -- order within the day
    type            TEXT NOT NULL,                -- sport | 'strength' | 'brick'
    label           TEXT,
    duration        INTEGER,
    distance        NUMERIC,
    zone            TEXT,
    pace            TEXT,
    effort_category TEXT,
    priority        TEXT,
    purpose         TEXT,
    detail          JSONB NOT NULL DEFAULT '{}',  -- workout text, fuel, legs, notes, warning, …
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at      TIMESTAMPTZ,                  -- SOFT DELETE; never hard-delete
    CHECK (week_number >= 1),
    CHECK (day BETWEEN 0 AND 6)
);

CREATE INDEX idx_prescribed_workouts_plan_week
    ON prescribed_workouts (user_id, plan_id, week_number)
    WHERE deleted_at IS NULL;

ALTER TABLE prescribed_workouts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read their own prescribed workouts"
    ON prescribed_workouts FOR SELECT USING (user_id = auth.uid());

-- ─── Strength exercises, linked to the catalog by stable slug ────────────────
CREATE TABLE prescribed_exercises (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prescribed_workout_id UUID NOT NULL
                          REFERENCES prescribed_workouts(id) ON DELETE CASCADE,
    catalog_exercise_slug TEXT REFERENCES exercises(slug),  -- stable link (007/008)
    position              SMALLINT NOT NULL DEFAULT 0,
    prescription          JSONB NOT NULL DEFAULT '{}'        -- prescribed sets/reps/load
);

CREATE INDEX idx_prescribed_exercises_workout
    ON prescribed_exercises (prescribed_workout_id);

ALTER TABLE prescribed_exercises ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read exercises for their own workouts"
    ON prescribed_exercises FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM prescribed_workouts pw
            WHERE pw.id = prescribed_exercises.prescribed_workout_id
              AND pw.user_id = auth.uid()
        )
    );

-- ─── Completion ledger — separate lifecycle from the prescription ────────────
CREATE TABLE workout_completions (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id               UUID NOT NULL DEFAULT auth.uid()
                          REFERENCES auth.users(id) ON DELETE CASCADE,
    prescribed_workout_id UUID                       -- nullable: unplanned sessions
                          REFERENCES prescribed_workouts(id) ON DELETE SET NULL,
    status                TEXT NOT NULL,             -- completed|shortened|missed|substituted|swapped
    actual_duration       INTEGER,
    actual_distance       NUMERIC,
    actual_sport          TEXT,
    rpe                   SMALLINT,
    fatigue               SMALLINT,
    athlete_note          TEXT,
    completion_note       TEXT,
    linked_workout_id     UUID,                      -- HealthKit / cardio link
    resolved_at           TIMESTAMPTZ,
    needs_review          BOOLEAN NOT NULL DEFAULT FALSE,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (status IN ('completed','shortened','missed','substituted','swapped'))
);

CREATE INDEX idx_workout_completions_prescribed
    ON workout_completions (prescribed_workout_id);
CREATE INDEX idx_workout_completions_user
    ON workout_completions (user_id);

ALTER TABLE workout_completions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read their own completions"
    ON workout_completions FOR SELECT USING (user_id = auth.uid());
