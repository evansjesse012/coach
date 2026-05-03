-- 012_weekly_artifacts.sql
-- W1 PR 1.1 — Weekly review and preview artifacts.
--
-- Two tables, one per artifact, both keyed by (user_id, week_start_date).
-- The week_start_date is the Monday of the week the artifact covers,
-- stamped in the athlete's local time at insert time (single-user app
-- simplification — see W1_PLAN.md "Open questions").
--
--   * `weekly_reviews`  — the structured check-in for the week just
--     completed (Mon–Sun). Athlete-authored fields populated incrementally
--     by `populate_review_field`; `completed_at` stamped by
--     `complete_weekly_review`. AI-authored fields (`ai_response_text`,
--     `ai_response_components`, `patterns_detected`) are written by the
--     paired generator at completion time.
--
--   * `weekly_previews` — the AI-generated framing for the week ahead.
--     Always paired with the prior week's review when one exists;
--     `paired_review_id` is nullable to allow generic previews for skipped
--     check-ins (the "I built this without your input" path).
--
-- Engagement fields (`read_at`, `reread_count`, `responded_to`) on the
-- preview are W1 Phase 1 minimum scaffolding for later analytics — they
-- aren't surfaced in UI yet but are cheap to write at view time.

-- ─── Weekly reviews ──────────────────────────────────────────────────────
CREATE TABLE weekly_reviews (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                     UUID NOT NULL DEFAULT auth.uid()
                                 REFERENCES auth.users(id) ON DELETE CASCADE,
    week_start_date             DATE NOT NULL,            -- Monday, athlete-local
    week_end_date               DATE NOT NULL,            -- Sunday, athlete-local
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at                TIMESTAMPTZ,              -- null while in-progress

    -- Structured athlete inputs (populate_review_field writes these)
    sleep_avg_hours             NUMERIC,
    energy_rating               SMALLINT,                 -- 1..10
    motivation_rating           SMALLINT,                 -- 1..10
    soreness_level              TEXT,                     -- "none"|"mild"|"significant"|"concerning"
    soreness_location           TEXT,
    pain_flag                   BOOLEAN NOT NULL DEFAULT false,
    pain_description            TEXT,
    life_stress_rating          SMALLINT,                 -- 1..10
    body_weight                 NUMERIC,                  -- only if athlete tracks
    adherence_pct               NUMERIC,                  -- auto-computed at complete

    -- Free-text athlete inputs
    best_session_text           TEXT,
    best_session_id             UUID,
    worst_session_text          TEXT,
    worst_session_id            UUID,
    life_context                TEXT,
    questions                   TEXT,
    next_week_focus             TEXT,

    -- AI-authored
    ai_response_text            TEXT,                     -- the prose Half B
    ai_response_components      JSONB NOT NULL DEFAULT '{}'::jsonb,
                                                          -- {life_acknowledgment, week_assessment,
                                                          --  session_feedback:[{session_id, feedback}],
                                                          --  pattern_callout, questions_answered:[...],
                                                          --  bridge_to_next_week}
    patterns_detected           JSONB NOT NULL DEFAULT '[]'::jsonb,
                                                          -- ["tuesday_fatigue_3wk", ...]

    UNIQUE (user_id, week_start_date),
    CHECK (week_end_date >= week_start_date),
    CHECK (energy_rating       IS NULL OR energy_rating       BETWEEN 1 AND 10),
    CHECK (motivation_rating   IS NULL OR motivation_rating   BETWEEN 1 AND 10),
    CHECK (life_stress_rating  IS NULL OR life_stress_rating  BETWEEN 1 AND 10),
    CHECK (soreness_level      IS NULL OR soreness_level IN ('none','mild','significant','concerning'))
);

CREATE INDEX idx_weekly_reviews_user_week_desc
    ON weekly_reviews (user_id, week_start_date DESC);

ALTER TABLE weekly_reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own weekly reviews"
    ON weekly_reviews FOR ALL USING (user_id = auth.uid());

-- ─── Weekly previews ─────────────────────────────────────────────────────
CREATE TABLE weekly_previews (
    id                              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                         UUID NOT NULL DEFAULT auth.uid()
                                     REFERENCES auth.users(id) ON DELETE CASCADE,
    week_start_date                 DATE NOT NULL,
    week_end_date                   DATE NOT NULL,
    created_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- The review that informed this preview. Nullable so we can still
    -- generate a generic preview when the athlete skipped the check-in.
    -- ON DELETE SET NULL — if a review is deleted the preview survives
    -- as a standalone artifact rather than cascading away with it.
    paired_review_id                UUID
                                     REFERENCES weekly_reviews(id) ON DELETE SET NULL,

    -- Structured framing
    theme                           TEXT NOT NULL,         -- one-sentence header
    theme_category                  TEXT,                  -- enum'd in Phase 5;
                                                           -- free-form for now
    macro_position                  TEXT,                  -- "Week 4 of 8 in build, 12 weeks until Oceanside"

    -- Volume metrics
    total_planned_hours             NUMERIC,
    total_planned_distance          NUMERIC,
    total_planned_tss               NUMERIC,
    delta_from_previous_week_pct    NUMERIC,
    num_quality_sessions            INTEGER,
    num_easy_sessions               INTEGER,

    -- Structured authored content (rendered_prose carries the joined view)
    key_sessions                    JSONB NOT NULL DEFAULT '[]'::jsonb,
                                                           -- [{session_id, day_of_week, name,
                                                           --   why_it_matters, success_criteria, watch_for}]
    watch_outs                      JSONB NOT NULL DEFAULT '[]'::jsonb,
                                                           -- [{type, description, referenced_data}]
    tactical_notes                  JSONB NOT NULL DEFAULT '[]'::jsonb,
                                                           -- [{category, note}]
    life_management_notes           JSONB NOT NULL DEFAULT '[]'::jsonb,
                                                           -- [{referenced_context, note}]

    rendered_prose                  TEXT NOT NULL,         -- the body the athlete reads
    closing_question                TEXT,

    -- Engagement (Phase 1 writes are best-effort; UI consumes later)
    read_at                         TIMESTAMPTZ,
    reread_count                    INTEGER NOT NULL DEFAULT 0,
    responded_to                    BOOLEAN NOT NULL DEFAULT false,

    UNIQUE (user_id, week_start_date),
    CHECK (week_end_date >= week_start_date)
);

CREATE INDEX idx_weekly_previews_user_week_desc
    ON weekly_previews (user_id, week_start_date DESC);

CREATE INDEX idx_weekly_previews_paired_review
    ON weekly_previews (paired_review_id);

ALTER TABLE weekly_previews ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own weekly previews"
    ON weekly_previews FOR ALL USING (user_id = auth.uid());
