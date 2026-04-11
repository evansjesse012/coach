-- Coach iOS App: Initial Supabase Schema
-- Migrates all localStorage data models to Postgres tables with RLS

-- ─── Profiles ──────────────────────────────────────────────────────────────────
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own profile" ON profiles
  FOR ALL USING (auth.uid() = id);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id) VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ─── Events (Goals / Races) ───────────────────────────────────────────────────
CREATE TABLE events (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  preset_id TEXT NOT NULL DEFAULT '',
  name TEXT NOT NULL,
  date TEXT,
  location TEXT,
  mode TEXT NOT NULL DEFAULT 'goal', -- 'goal' | 'race' | 'pr'
  goal TEXT,
  stretch_goal TEXT,
  baseline TEXT,
  result TEXT,
  completed BOOLEAN DEFAULT FALSE,
  notes JSONB DEFAULT '[]',
  splits JSONB,          -- {swim, t1, bike, t2, run, total}
  bib_number TEXT,
  age_group TEXT,
  placement TEXT,
  gender_placement TEXT,
  age_group_placement TEXT,
  plan_sections JSONB,   -- {strategy, nutrition, pacing, gear, mentalPlan}
  ai_conditions JSONB,   -- {summary, terrain, elevation, climate, tips}
  linked_race_id TEXT,
  url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own events" ON events
  FOR ALL USING (auth.uid() = user_id);

-- ─── Cardio Workouts ──────────────────────────────────────────────────────────
CREATE TABLE cardio_workouts (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  sport TEXT NOT NULL,     -- run, bike, swim, hike, other
  duration INTEGER NOT NULL,
  distance TEXT,
  pace TEXT,
  avg_hr INTEGER,
  max_hr INTEGER,
  calories INTEGER,
  avg_power INTEGER,
  hr_zones JSONB,          -- {Z1, Z2, Z3, Z4, Z5}
  notes TEXT,
  date TEXT NOT NULL,
  start_time TEXT,
  end_time TEXT,
  location TEXT,
  source TEXT DEFAULT 'manual', -- 'manual' | 'healthkit'
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE cardio_workouts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own cardio" ON cardio_workouts
  FOR ALL USING (auth.uid() = user_id);

CREATE INDEX idx_cardio_user_date ON cardio_workouts(user_id, date DESC);
CREATE INDEX idx_cardio_user_sport ON cardio_workouts(user_id, sport);

-- ─── Strength Sessions ────────────────────────────────────────────────────────
CREATE TABLE strength_sessions (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  date TEXT NOT NULL,
  duration INTEGER,
  exercises JSONB NOT NULL, -- [{name, exerciseType, sets: [{weight, reps, duration, band, completed}]}]
  template_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE strength_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own strength" ON strength_sessions
  FOR ALL USING (auth.uid() = user_id);

CREATE INDEX idx_strength_user_date ON strength_sessions(user_id, date DESC);

-- ─── Personal Records ─────────────────────────────────────────────────────────
CREATE TABLE personal_records (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  exercise_slug TEXT NOT NULL,
  exercise_type TEXT NOT NULL, -- 'weighted' | 'bodyweight' | 'banded' | 'timed' | 'cardio-drill'
  weight REAL,
  reps INTEGER,
  estimated_1rm REAL,
  best_reps INTEGER,
  best_duration REAL,
  band TEXT,
  date TEXT,
  history JSONB DEFAULT '[]',
  PRIMARY KEY (user_id, exercise_slug)
);

ALTER TABLE personal_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own PRs" ON personal_records
  FOR ALL USING (auth.uid() = user_id);

-- ─── Nutrition ────────────────────────────────────────────────────────────────
CREATE TABLE nutrition (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  meal TEXT NOT NULL,
  timing TEXT NOT NULL,       -- pre | during | post | general
  related_workout TEXT,
  date TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE nutrition ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own nutrition" ON nutrition
  FOR ALL USING (auth.uid() = user_id);

CREATE INDEX idx_nutrition_user_date ON nutrition(user_id, date DESC);

-- ─── Bricks (Multi-sport sessions) ───────────────────────────────────────────
CREATE TABLE bricks (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  date TEXT NOT NULL,
  legs JSONB NOT NULL,        -- [{workoutId}]
  transition_time INTEGER,
  transition_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE bricks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own bricks" ON bricks
  FOR ALL USING (auth.uid() = user_id);

-- ─── Training Plans ───────────────────────────────────────────────────────────
CREATE TABLE training_plans (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  goal_id TEXT,
  race_name TEXT,
  race_date TEXT,
  start_date TEXT,
  total_weeks INTEGER,
  current_week INTEGER DEFAULT 1,
  current_phase INTEGER DEFAULT 1,
  training_days_per_week INTEGER,
  phases JSONB NOT NULL,        -- [{number, name, startDate, endDate, weeks, ...}]
  weekly_plans JSONB DEFAULT '{}', -- keyed by week number string
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE training_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own plans" ON training_plans
  FOR ALL USING (auth.uid() = user_id);

-- ─── Plan History (Archived) ──────────────────────────────────────────────────
CREATE TABLE plan_history (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  race_name TEXT,
  goal_id TEXT,
  race_date TEXT,
  start_date TEXT,
  ended_date TEXT,
  total_weeks INTEGER,
  completed_weeks INTEGER,
  total_phases INTEGER,
  phases_completed INTEGER,
  phases JSONB,
  end_reason TEXT,
  end_notes TEXT,
  adherence TEXT,
  weekly_adherence JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE plan_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own plan history" ON plan_history
  FOR ALL USING (auth.uid() = user_id);

-- ─── Coaching Memory ──────────────────────────────────────────────────────────
CREATE TABLE coaching_memory (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  permanent JSONB DEFAULT '{}',
  benchmarks JSONB DEFAULT '[]',
  injuries JSONB DEFAULT '[]',
  observations JSONB DEFAULT '{}',
  response_profile JSONB DEFAULT '{}',
  conversation_summaries JSONB DEFAULT '[]',
  period_summaries JSONB DEFAULT '[]',
  last_updated TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE coaching_memory ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own memory" ON coaching_memory
  FOR ALL USING (auth.uid() = user_id);

-- ─── Chat Messages ────────────────────────────────────────────────────────────
CREATE TABLE chat_messages (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role TEXT NOT NULL,          -- 'user' | 'assistant'
  content TEXT NOT NULL,
  metadata JSONB,              -- {logged, nutritionLogged, planChanged, appActionTaken, isError}
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own messages" ON chat_messages
  FOR ALL USING (auth.uid() = user_id);

CREATE INDEX idx_messages_user_created ON chat_messages(user_id, created_at DESC);

-- ─── Settings ─────────────────────────────────────────────────────────────────
CREATE TABLE settings (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  personality TEXT DEFAULT 'normal',
  custom_prompt TEXT DEFAULT '',
  dark_mode BOOLEAN DEFAULT FALSE,
  push_message JSONB,          -- {text, actions, count, ts}
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own settings" ON settings
  FOR ALL USING (auth.uid() = user_id);

-- ─── Templates ────────────────────────────────────────────────────────────────
CREATE TABLE templates (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  exercises JSONB NOT NULL,
  last_used TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own templates" ON templates
  FOR ALL USING (auth.uid() = user_id);

-- ─── Custom Exercises ─────────────────────────────────────────────────────────
CREATE TABLE custom_exercises (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  body_part TEXT,
  category TEXT,
  exercise_type TEXT NOT NULL   -- 'weighted' | 'bodyweight' | 'banded' | 'timed' | 'cardio-drill'
);

ALTER TABLE custom_exercises ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own exercises" ON custom_exercises
  FOR ALL USING (auth.uid() = user_id);
