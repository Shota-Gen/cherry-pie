-- Add session metadata columns for private study sessions
-- session_type: 'private' or 'public' (defaults to 'public' for backward compat)
-- title:       optional human-friendly name for the session
-- description:  optional details about what will be studied

CREATE TYPE public.session_type AS ENUM ('public', 'private');

ALTER TABLE public.sessions
    ADD COLUMN session_type public.session_type NOT NULL DEFAULT 'public',
    ADD COLUMN title        TEXT,
    ADD COLUMN description  TEXT;

-- Index for quick lookups of private sessions by creator
CREATE INDEX sessions_private_creator_idx
    ON public.sessions (created_by)
    WHERE session_type = 'private';
