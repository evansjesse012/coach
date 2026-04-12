-- Set user_id default to auth.uid() so app inserts don't need to send it.
-- Without this, every table's NOT NULL user_id forced clients to either embed
-- it in the model or fail with a constraint violation.

ALTER TABLE events            ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE cardio_workouts   ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE strength_sessions ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE personal_records  ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE nutrition         ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE bricks            ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE training_plans    ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE plan_history      ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE coaching_memory   ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE chat_messages     ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE settings          ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE templates         ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE custom_exercises  ALTER COLUMN user_id SET DEFAULT auth.uid();
