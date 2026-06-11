-- ─── Week-start day (configurable training-week anchor) ──────────────────────
--
-- Lets athletes choose which weekday their training week starts on
-- (Sunday and Monday being the common choices; any day is allowed).
--
-- Two columns, two scopes:
--   settings.week_start_day        — the athlete's CURRENT preference.
--     Drives the weekly review/preview ritual, analytics bucketing, and
--     the anchor frozen onto the next plan created.
--   training_plans.week_start_day  — frozen per plan at creation.
--     The plan's day grid (weekly_plans JSONB sessions arrays) is
--     positional, so this must never change for the life of a plan;
--     preference changes apply to the next plan only.
--
-- Values are lowercase day names ('monday' … 'sunday'), matching the
-- Swift `Weekday` enum raw values and the day names already stored in
-- weekly_plans day objects. NULL means Monday (every row written before
-- this migration), so no backfill is needed.

ALTER TABLE settings
  ADD COLUMN week_start_day TEXT
  CHECK (week_start_day IN ('monday','tuesday','wednesday','thursday','friday','saturday','sunday'));

ALTER TABLE training_plans
  ADD COLUMN week_start_day TEXT
  CHECK (week_start_day IN ('monday','tuesday','wednesday','thursday','friday','saturday','sunday'));
