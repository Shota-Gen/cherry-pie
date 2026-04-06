-- Update external_auth_tokens for Smart Scheduler Google Calendar integration
-- Adds provider tracking and scope tracking columns

-- Add provider column (defaults to 'google' since that's all we support now)
ALTER TABLE public.external_auth_tokens
    ADD COLUMN IF NOT EXISTS provider TEXT NOT NULL DEFAULT 'google';

-- Add scopes_granted to track which API scopes the user approved
ALTER TABLE public.external_auth_tokens
    ADD COLUMN IF NOT EXISTS scopes_granted TEXT[] NOT NULL DEFAULT '{}';

-- Add the user's Google email (may differ from their app email)
ALTER TABLE public.external_auth_tokens
    ADD COLUMN IF NOT EXISTS google_email TEXT;

-- Drop + recreate the primary key to allow multiple providers per user
ALTER TABLE public.external_auth_tokens
    DROP CONSTRAINT IF EXISTS external_auth_tokens_pkey;

ALTER TABLE public.external_auth_tokens
    ADD PRIMARY KEY (user_id, provider);

-- Index for quick lookup by provider
CREATE INDEX IF NOT EXISTS idx_external_auth_tokens_provider
    ON public.external_auth_tokens (provider);

-- Comment for documentation
COMMENT ON TABLE public.external_auth_tokens IS
    'Stores encrypted OAuth tokens for external services (Google, etc). '
    'Used by the backend to query Google Calendar FreeBusy on behalf of users.';
