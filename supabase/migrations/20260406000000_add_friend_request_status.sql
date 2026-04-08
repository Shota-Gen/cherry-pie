-- Add columns safely
ALTER TABLE public.friends
    ADD COLUMN IF NOT EXISTS user_status TEXT NOT NULL DEFAULT 'accepted',
    ADD COLUMN IF NOT EXISTS friend_status TEXT NOT NULL DEFAULT 'pending';

-- Add constraints safely (Postgres doesn't support IF NOT EXISTS inline for CHECK in ADD COLUMN)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'friends_user_status_check'
    ) THEN
        ALTER TABLE public.friends
        ADD CONSTRAINT friends_user_status_check
        CHECK (user_status IN ('accepted', 'pending'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'friends_friend_status_check'
    ) THEN
        ALTER TABLE public.friends
        ADD CONSTRAINT friends_friend_status_check
        CHECK (friend_status IN ('accepted', 'pending'));
    END IF;
END $$;

-- Index (this part is easy)
CREATE INDEX IF NOT EXISTS friends_pending_requests_idx
    ON public.friends (friend_id)
    WHERE friend_status = 'pending';