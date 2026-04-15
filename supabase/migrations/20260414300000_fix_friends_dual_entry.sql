-- Migration: Convert friends table from single-entry dual-status model
-- to dual-entry single-status model.
--
-- OLD: one row per friendship with user_status/friend_status columns
-- NEW: two rows per accepted friendship (A→B + B→A), single 'status' column
--
-- Request flow:
--   Send request: INSERT (sender, receiver, 'pending')
--   Accept:       UPDATE that row → 'accepted', INSERT reverse (receiver, sender, 'accepted')
--   Reject:       DELETE the pending row
--   Unfriend:     DELETE both rows
--   Get friends:  WHERE user_id = me AND status = 'accepted'
--   Get requests: WHERE friend_id = me AND status = 'pending'

-- 1. Add new 'status' column
ALTER TABLE public.friends ADD COLUMN IF NOT EXISTS status TEXT;

-- 2. Migrate existing data:
--    - Rows where both user_status='accepted' AND friend_status='accepted' → status='accepted'
--    - Rows where friend_status='pending' → status='pending'
--    - Everything else → status='pending'
UPDATE public.friends
SET status = CASE
    WHEN user_status = 'accepted' AND friend_status = 'accepted' THEN 'accepted'
    ELSE 'pending'
END;

-- 3. For all accepted friendships, insert the reverse row if it doesn't exist
INSERT INTO public.friends (user_id, friend_id, created_at, status, user_status, friend_status)
SELECT f.friend_id, f.user_id, f.created_at, 'accepted', 'accepted', 'accepted'
FROM public.friends f
WHERE f.status = 'accepted'
  AND NOT EXISTS (
    SELECT 1 FROM public.friends f2
    WHERE f2.user_id = f.friend_id AND f2.friend_id = f.user_id
  );

-- 4. Update any existing reverse rows that may have been inserted with wrong status
UPDATE public.friends f
SET status = 'accepted'
WHERE EXISTS (
    SELECT 1 FROM public.friends f2
    WHERE f2.user_id = f.friend_id
      AND f2.friend_id = f.user_id
      AND f2.status = 'accepted'
)
AND f.status != 'accepted';

-- 5. Make status NOT NULL with default
ALTER TABLE public.friends ALTER COLUMN status SET NOT NULL;
ALTER TABLE public.friends ALTER COLUMN status SET DEFAULT 'pending';

-- 6. Add constraint for status values
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'friends_status_check'
    ) THEN
        ALTER TABLE public.friends
        ADD CONSTRAINT friends_status_check
        CHECK (status IN ('accepted', 'pending'));
    END IF;
END $$;

-- 7. Drop old columns and their constraints
ALTER TABLE public.friends DROP CONSTRAINT IF EXISTS friends_user_status_check;
ALTER TABLE public.friends DROP CONSTRAINT IF EXISTS friends_friend_status_check;
ALTER TABLE public.friends DROP COLUMN IF EXISTS user_status;
ALTER TABLE public.friends DROP COLUMN IF EXISTS friend_status;

-- 8. Drop old partial index on friend_status, create new one on status
DROP INDEX IF EXISTS friends_pending_requests_idx;
CREATE INDEX IF NOT EXISTS friends_pending_requests_idx
    ON public.friends (friend_id)
    WHERE status = 'pending';

-- Add index for fast friend list lookup
CREATE INDEX IF NOT EXISTS friends_user_accepted_idx
    ON public.friends (user_id)
    WHERE status = 'accepted';

-- 9. Update RPC: get_users_in_study_spots — now single-direction + status check
CREATE OR REPLACE FUNCTION get_users_in_study_spots(current_user_id uuid)
RETURNS TABLE (
    user_id uuid,
    display_name text,
    last_known_lat double precision,
    last_known_lng double precision,
    spot_name text
)
LANGUAGE sql
AS $$
  SELECT
      u.user_id,
      u.display_name,
      u.last_known_lat,
      u.last_known_lng,
      s.name AS spot_name
  FROM public.users u
  JOIN public.friends f
    ON f.user_id = current_user_id
   AND f.friend_id = u.user_id
   AND f.status = 'accepted'
  JOIN public.study_spots s
    ON ST_Contains(
         s.geofence::geometry,
         ST_SetSRID(ST_MakePoint(u.last_known_lng, u.last_known_lat), 4326)
       )
  WHERE u.is_invisible = false
    AND u.last_known_lat IS NOT NULL
    AND u.last_known_lng IS NOT NULL;
$$;

-- 10. Update RPC: get_friends_in_same_study_spot — now single-direction only
CREATE OR REPLACE FUNCTION get_friends_in_same_study_spot(current_user_id uuid)
RETURNS TABLE (
    user_id uuid,
    display_name text,
    last_known_lat double precision,
    last_known_lng double precision,
    altitude double precision,
    spot_name text
)
LANGUAGE sql
AS $$
  WITH my_spot AS (
    SELECT s.spot_id, s.geofence
    FROM public.users me
    JOIN public.study_spots s
      ON ST_Contains(
           s.geofence::geometry,
           ST_SetSRID(ST_MakePoint(me.last_known_lng, me.last_known_lat), 4326)
         )
    WHERE me.user_id = current_user_id
      AND me.last_known_lat IS NOT NULL
      AND me.last_known_lng IS NOT NULL
    LIMIT 1
  )
  SELECT
      u.user_id,
      u.display_name,
      u.last_known_lat,
      u.last_known_lng,
      u.altitude,
      s.name AS spot_name
  FROM public.users u
  JOIN public.friends f
    ON f.user_id = current_user_id
   AND f.friend_id = u.user_id
   AND f.status = 'accepted'
  JOIN my_spot ms ON TRUE
  JOIN public.study_spots s
    ON s.spot_id = ms.spot_id
   AND ST_Contains(
         s.geofence::geometry,
         ST_SetSRID(ST_MakePoint(u.last_known_lng, u.last_known_lat), 4326)
       )
  WHERE u.is_invisible = false
    AND u.last_known_lat IS NOT NULL
    AND u.last_known_lng IS NOT NULL;
$$;
