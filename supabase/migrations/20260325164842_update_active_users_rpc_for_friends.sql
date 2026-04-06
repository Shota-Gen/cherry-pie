-- Replace the no-arg version with one that filters by friends
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
    ON f.user_id = current_user_id AND f.friend_id = u.user_id
  JOIN public.study_spots s
    ON ST_Contains(
         s.geofence::geometry,
         ST_SetSRID(ST_MakePoint(u.last_known_lng, u.last_known_lat), 4326)
       )
  WHERE u.is_invisible = false
    AND u.last_known_lat IS NOT NULL
    AND u.last_known_lng IS NOT NULL;
$$;
