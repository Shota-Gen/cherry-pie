-- Add location_name column to sessions table.
-- location_name: free-form location text entered by the session creator.

ALTER TABLE public.sessions
    ADD COLUMN IF NOT EXISTS location_name TEXT;

COMMENT ON COLUMN public.sessions.location_name IS 'Free-form location name entered by the session creator';
