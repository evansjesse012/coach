-- Coach App: Voice, Messaging & Calling feature tables
-- Adds support for SMS messaging, voice calls, and scheduled check-ins

-- ─── Settings: Add voice & messaging columns ────────────────────────────────
ALTER TABLE settings
  ADD COLUMN IF NOT EXISTS voice_output_enabled BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS phone_number TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS sms_enabled BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS calls_enabled BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS scheduled_check_ins JSONB DEFAULT '[]';

-- ─── Coach Messages (SMS audit log) ─────────────────────────────────────────
CREATE TABLE coach_messages (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  channel TEXT NOT NULL DEFAULT 'sms',    -- 'sms' | 'push' | 'call'
  direction TEXT NOT NULL DEFAULT 'outbound', -- 'outbound' | 'inbound'
  content TEXT NOT NULL,
  to_number TEXT,
  from_number TEXT,
  twilio_sid TEXT,
  status TEXT DEFAULT 'sent',
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE coach_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own messages" ON coach_messages
  FOR ALL USING (auth.uid() = user_id);

CREATE INDEX idx_coach_messages_user ON coach_messages(user_id, created_at DESC);

-- ─── Coach Calls (Voice call log) ───────────────────────────────────────────
CREATE TABLE coach_calls (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  direction TEXT NOT NULL DEFAULT 'outbound',
  personality TEXT DEFAULT 'normal',
  twilio_sid TEXT,
  status TEXT DEFAULT 'initiated',   -- initiated, ringing, in-progress, completed, failed
  duration_seconds INTEGER,
  transcript TEXT,                    -- Full conversation transcript for memory extraction
  summary TEXT,                       -- AI-generated call summary
  side_effects JSONB DEFAULT '[]',   -- Actions taken during the call
  started_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE coach_calls ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own calls" ON coach_calls
  FOR ALL USING (auth.uid() = user_id);

CREATE INDEX idx_coach_calls_user ON coach_calls(user_id, created_at DESC);

-- ─── Scheduled Check-Ins ────────────────────────────────────────────────────
CREATE TABLE scheduled_check_ins (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL,                   -- morning_brief, pre_workout, post_workout, evening_review, accountability
  scheduled_at TIMESTAMPTZ NOT NULL,
  personality TEXT DEFAULT 'normal',
  message TEXT,                         -- Optional custom message/context
  channel TEXT DEFAULT 'push',          -- sms, push, call
  status TEXT DEFAULT 'pending',        -- pending, sent, completed, skipped
  recurrence TEXT,                      -- daily, weekdays, custom
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE scheduled_check_ins ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own check-ins" ON scheduled_check_ins
  FOR ALL USING (auth.uid() = user_id);

CREATE INDEX idx_check_ins_pending ON scheduled_check_ins(status, scheduled_at)
  WHERE status = 'pending';
