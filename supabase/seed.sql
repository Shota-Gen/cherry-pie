-- Clear the table before seeding
TRUNCATE public.study_spots, public.users CASCADE;

-- Insert auth users (GoTrue requires many non-null string columns)
INSERT INTO auth.users (
    id, email, aud, role, email_confirmed_at,
    encrypted_password, confirmation_token, recovery_token,
    email_change_token_new, email_change, raw_app_meta_data, raw_user_meta_data,
    instance_id, created_at, updated_at
)
VALUES
    ('6f8e7d2a-1b3c-4d5e-8f7a-9b0c1d2e3f4a', 'sgen@umich.edu',    'authenticated', 'authenticated', now(), '', '', '', '', '', '{"provider":"google","providers":["google"]}'::jsonb, '{}'::jsonb, '00000000-0000-0000-0000-000000000000', now(), now()),
    ('a1111111-1111-1111-1111-111111111111', 'alice@umich.edu',    'authenticated', 'authenticated', now(), '', '', '', '', '', '{}'::jsonb, '{}'::jsonb, '00000000-0000-0000-0000-000000000000', now(), now()),
    ('b2222222-2222-2222-2222-222222222222', 'bob@umich.edu',      'authenticated', 'authenticated', now(), '', '', '', '', '', '{}'::jsonb, '{}'::jsonb, '00000000-0000-0000-0000-000000000000', now(), now()),
    ('c3333333-3333-3333-3333-333333333333', 'carol@umich.edu',    'authenticated', 'authenticated', now(), '', '', '', '', '', '{}'::jsonb, '{}'::jsonb, '00000000-0000-0000-0000-000000000000', now(), now()),
    ('d4444444-4444-4444-4444-444444444444', 'dave@umich.edu',     'authenticated', 'authenticated', now(), '', '', '', '', '', '{}'::jsonb, '{}'::jsonb, '00000000-0000-0000-0000-000000000000', now(), now()),
    ('e5555555-5555-5555-5555-555555555555', 'eve@umich.edu',      'authenticated', 'authenticated', now(), '', '', '', '', '', '{}'::jsonb, '{}'::jsonb, '00000000-0000-0000-0000-000000000000', now(), now());

-- Insert public.users profiles
-- Shota: no location (will be set by the app)
-- Alice: inside UGLI
-- Bob:   inside Fishbowl
-- Carol: inside Law Library but INVISIBLE (should not appear on map)
INSERT INTO public.users (user_id, display_name, email, current_floor, last_known_lat, last_known_lng, is_invisible)
VALUES
    ('6f8e7d2a-1b3c-4d5e-8f7a-9b0c1d2e3f4a', 'Shota (Lead)',  'sgen@umich.edu',   1, NULL, NULL, false),
    ('a1111111-1111-1111-1111-111111111111',   'Alice Johnson', 'alice@umich.edu',  1, 42.2756, -83.7371, false),
    ('b2222222-2222-2222-2222-222222222222',   'Bob Smith',     'bob@umich.edu',    1, 42.2769, -83.7396, false),
    ('c3333333-3333-3333-3333-333333333333',   'Carol Davis',   'carol@umich.edu',  1, 42.2738, -83.7394, true),
    ('d4444444-4444-4444-4444-444444444444',   'Dave Wilson',   'dave@umich.edu',   1, 42.2780, -83.7380, false),
    ('e5555555-5555-5555-5555-555555555555',   'Eve Martinez',  'eve@umich.edu',    1, 40.7128, -74.0060, false);

-- Insert the two primary U-M test zones
INSERT INTO public.study_spots (name, geofence)
VALUES 
    (
        'UGLI (Shapiro Library)', 
        ST_GeomFromText('POLYGON((
                        -83.73691041801023 42.275258265114246,
                         -83.73691041801023 42.275970173108874,
                         -83.73742276774232 42.275970173108874,
                         -83.73742276774232 42.275258265114246,
                          -83.73691041801023 42.275258265114246))', 4326)
    ),
    (
        'The Fishbowl (Mason Hall)', 
        ST_GeomFromText('POLYGON((
              -83.73996141647496  42.27716887162862,
              -83.73996141647496  42.27669108616621,
              -83.73925720228932  42.27669108616621,
              -83.73925720228932  42.27716887162862,
               -83.73996141647496  42.27716887162862
              ))', 4326)

              
    ),
    (
        'Law Library', 
        ST_GeomFromText('POLYGON((
              -83.73985170698981 42.27396167845754,
              -83.73984658123484 42.27382134711448,
              -83.73953903596332 42.27380238339589,
              -83.73952878445405 42.27359378211071,
              -83.73921098767325 42.27359378211071,
              -83.73921098767325 42.27375307769964,
              -83.73887781362887 42.27375307769964,
              -83.73889319089245 42.27398064212872,
              -83.73985170698981 42.27396167845754
              ))', 4326)
    ),
    (
        'Duderstadt Center', 
        ST_GeomFromText('POLYGON((
              -83.71622874756683 42.291559776846185,
              -83.71622874756683 42.29075847164938,
              -83.71513291896353 42.29075847164938,
              -83.71513291896353 42.291559776846185,
              -83.71622874756683 42.291559776846185
              ))', 4326)
    ),
    (
        'Hatcher Graduate Library', 
        ST_GeomFromText('POLYGON((
              -83.73860492289374 42.276582016597274,
              -83.73860492289374 42.276100271204626,
              -83.7377662340269 42.276100271204626,
              -83.7377662340269 42.276582016597274,
              -83.73860492289374 42.276582016597274
              ))', 4326)
    );
    

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