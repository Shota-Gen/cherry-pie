-- Restore Smart Scheduler columns on external_auth_tokens
-- These were dropped by the remote_schema migration pull and are required
-- by the /scheduler/store-token endpoint.

-- Add provider column (defaults to 'google')
ALTER TABLE public.external_auth_tokens
    ADD COLUMN IF NOT EXISTS provider TEXT NOT NULL DEFAULT 'google';

-- Add scopes_granted to track which API scopes the user approved
ALTER TABLE public.external_auth_tokens
    ADD COLUMN IF NOT EXISTS scopes_granted TEXT[] NOT NULL DEFAULT '{}';

-- Add the user's Google email (may differ from their app email)
ALTER TABLE public.external_auth_tokens
    ADD COLUMN IF NOT EXISTS google_email TEXT;

-- Recreate composite primary key (user_id, provider) to support multiple providers
ALTER TABLE public.external_auth_tokens
    DROP CONSTRAINT IF EXISTS external_auth_tokens_pkey;

ALTER TABLE public.external_auth_tokens
    ADD PRIMARY KEY (user_id, provider);

-- Index for quick lookup by provider
CREATE INDEX IF NOT EXISTS idx_external_auth_tokens_provider
    ON public.external_auth_tokens (provider);
