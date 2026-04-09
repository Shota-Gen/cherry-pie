-- Returns visible friends who are in the SAME study spot as the current user.
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
    ON f.user_id = current_user_id AND f.friend_id = u.user_id
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
