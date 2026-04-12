-- Rich workout data from HealthKit + GPS routes in Storage.

-- ─── Cardio columns ───────────────────────────────────────────────────────────
ALTER TABLE cardio_workouts
  ADD COLUMN health_data    JSONB,
  ADD COLUMN route_summary  JSONB,
  ADD COLUMN avg_cadence    INTEGER,
  ADD COLUMN avg_speed      REAL,
  ADD COLUMN elevation_gain INTEGER,
  ADD COLUMN weather        JSONB,
  ADD COLUMN synced_at      TIMESTAMPTZ;

CREATE INDEX idx_cardio_synced_at ON cardio_workouts(user_id, synced_at DESC);

-- ─── Storage bucket for full-fidelity GPS routes ─────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('workout-routes', 'workout-routes', false)
ON CONFLICT (id) DO NOTHING;

-- Path convention: {user_id}/{workout_id}.json
-- (storage.foldername(name))[1] returns the first folder segment.

CREATE POLICY "Users read own routes"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'workout-routes'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users insert own routes"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'workout-routes'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users update own routes"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'workout-routes'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users delete own routes"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'workout-routes'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
