-- 011_strength_rpe.sql
-- Adds session-RPE to strength sessions. Drives the session-RPE TSS
-- estimate (Foster's method): TSS = RPE × duration_min / 10.
--
-- Session-RPE is the validated method for resistance work — TrainingPeaks,
-- intervals.icu, and most coaching platforms use it because volume-load
-- and HR-based methods are unreliable for strength training. The athlete
-- enters a single 1–10 number at the end of the session.
--
-- Nullable so existing rows decode unchanged; the TSS ladder falls back
-- to a sport_default estimate when rpe is null.

ALTER TABLE strength_sessions
    ADD COLUMN rpe INTEGER CHECK (rpe IS NULL OR (rpe BETWEEN 1 AND 10));
