-- 009_conversations.sql
-- Add conversation support to the chat system. Each conversation is a
-- distinct chat session that auto-closes after inactivity. Conversations
-- carry a summary generated on close so the coach has thread-to-thread
-- continuity without re-reading old transcripts.

-- ─── Conversations table ─────────────────────────────────────────────────
CREATE TABLE conversations (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_message_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    summary TEXT,
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own conversations"
    ON conversations FOR ALL USING (user_id = auth.uid());

CREATE INDEX idx_conversations_user_archived
    ON conversations (user_id, is_archived, last_message_at DESC);

-- ─── Link messages to conversations ──────────────────────────────────────
ALTER TABLE chat_messages ADD COLUMN conversation_id TEXT
    REFERENCES conversations(id) ON DELETE CASCADE;

CREATE INDEX idx_chat_messages_conversation
    ON chat_messages (conversation_id, created_at);
