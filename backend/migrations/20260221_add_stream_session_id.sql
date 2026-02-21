ALTER TABLE memos
ADD COLUMN IF NOT EXISTS stream_session_id text;
