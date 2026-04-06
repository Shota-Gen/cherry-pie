-- Add user_status and friend_status columns to friends table for friend requests.
-- user_status: the status from the perspective of user_id (sender), auto-accepted.
-- friend_status: the status from the perspective of friend_id (receiver), starts pending.
-- When both are 'accepted', the friendship is confirmed.
-- Rejection simply deletes the row.

ALTER TABLE public.friends
    ADD COLUMN user_status TEXT NOT NULL DEFAULT 'accepted'
        CHECK (user_status IN ('accepted', 'pending')),
    ADD COLUMN friend_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (friend_status IN ('accepted', 'pending'));

-- Index for quickly finding pending requests for a user (as receiver)
CREATE INDEX friends_pending_requests_idx
    ON public.friends (friend_id)
    WHERE friend_status = 'pending';
