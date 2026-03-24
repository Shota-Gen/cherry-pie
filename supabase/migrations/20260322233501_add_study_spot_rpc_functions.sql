CREATE OR REPLACE FUNCTION get_surrounding_study_spots(user_lat float, user_lon float)
RETURNS TABLE (
    id uuid,            
    name text            
) 
LANGUAGE sql
AS $$
  SELECT 
      spot_id, 
      name
  FROM 
      study_spots
  WHERE 
      -- ST_Contains checks if the polygon (location) fully encloses the point
      ST_Contains(
          geofence::geometry, 
          -- Note: ST_MakePoint requires Longitude (X) first, then Latitude (Y)!
          ST_SetSRID(ST_MakePoint(user_lon, user_lat), 4326)
      );
$$;

-- Returns every study spot with its full polygon coordinates as a JSON array
-- Each coordinate is [longitude, latitude] to match GeoJSON convention
CREATE OR REPLACE FUNCTION get_study_spots_with_coordinates()
RETURNS TABLE (
    spot_id uuid,
    name text,
    is_active boolean,
    coordinates jsonb
)
LANGUAGE sql
AS $$
  SELECT
      s.spot_id,
      s.name,
      s.is_active,
      (
        SELECT jsonb_agg(
          jsonb_build_array(ST_X(geom), ST_Y(geom))
          ORDER BY path
        )
        FROM ST_DumpPoints(s.geofence::geometry) AS dp(path, geom)
      ) AS coordinates
  FROM study_spots s;
$$;

-- Returns all visible users whose last known location is inside a study spot
CREATE OR REPLACE FUNCTION get_users_in_study_spots()
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
  JOIN public.study_spots s
    ON ST_Contains(
         s.geofence::geometry,
         ST_SetSRID(ST_MakePoint(u.last_known_lng, u.last_known_lat), 4326)
       )
  WHERE u.is_invisible = false
    AND u.last_known_lat IS NOT NULL
    AND u.last_known_lng IS NOT NULL;
$$;

-- Returns the study spot a specific user is currently inside (if any and if they are visible)
CREATE OR REPLACE FUNCTION get_user_study_spot(target_user_id uuid)
RETURNS TABLE (
    spot_id uuid,
    name text
)
LANGUAGE sql
AS $$
  SELECT
      s.spot_id,
      s.name
  FROM public.users u
  JOIN public.study_spots s
    ON ST_Contains(
         s.geofence::geometry,
         ST_SetSRID(ST_MakePoint(u.last_known_lng, u.last_known_lat), 4326)
       )
  WHERE u.user_id = target_user_id
    AND u.is_invisible = false
    AND u.last_known_lat IS NOT NULL
    AND u.last_known_lng IS NOT NULL
  LIMIT 1;
$$;
