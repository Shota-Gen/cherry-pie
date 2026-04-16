-- =============================================================
-- remote_schema.sql — made fully idempotent so it can run on
-- a fresh DB (after earlier migrations) OR be re-applied safely.
-- =============================================================

drop extension if exists "pg_net";

create schema if not exists "tiger";

create extension if not exists "fuzzystrmatch" with schema "tiger";

create extension if not exists "postgis_tiger_geocoder" with schema "tiger";

-- Idempotent enum creation
DO $$
BEGIN
  CREATE TYPE public.friend_status AS ENUM ('pending', 'rejected', 'accepted');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Drop external_auth_tokens PK only if the composite (user_id, provider) form exists
-- (added by migration 20260405230000). If it's already the simple (user_id) PK, skip.
DO $$
BEGIN
  -- Check if 'provider' column exists — if so the composite PK is in place
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'external_auth_tokens'
      AND column_name = 'provider'
  ) THEN
    ALTER TABLE public.external_auth_tokens DROP CONSTRAINT IF EXISTS external_auth_tokens_pkey;
  END IF;
END $$;

DROP INDEX IF EXISTS public.idx_external_auth_tokens_provider;
DROP INDEX IF EXISTS public.external_auth_tokens_pkey;

-- Drop columns only if they exist
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='external_auth_tokens' AND column_name='google_email') THEN
    ALTER TABLE public.external_auth_tokens DROP COLUMN google_email;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='external_auth_tokens' AND column_name='provider') THEN
    ALTER TABLE public.external_auth_tokens DROP COLUMN provider;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='external_auth_tokens' AND column_name='scopes_granted') THEN
    ALTER TABLE public.external_auth_tokens DROP COLUMN scopes_granted;
  END IF;
END $$;

-- Add columns to friends only if they don't already exist
ALTER TABLE public.friends ADD COLUMN IF NOT EXISTS friend_status TEXT NOT NULL DEFAULT 'pending';
ALTER TABLE public.friends ADD COLUMN IF NOT EXISTS user_status TEXT NOT NULL DEFAULT 'accepted';

-- Add altitude to users only if it doesn't already exist
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS altitude DOUBLE PRECISION DEFAULT 0;

-- Create indexes idempotently
CREATE INDEX IF NOT EXISTS friends_pending_requests_idx
    ON public.friends USING btree (friend_id)
    WHERE (friend_status = 'pending'::text);

-- Recreate the simple (user_id) PK on external_auth_tokens
DO $$
BEGIN
  -- Only create if the PK doesn't already exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'external_auth_tokens_pkey'
      AND conrelid = 'public.external_auth_tokens'::regclass
  ) THEN
    CREATE UNIQUE INDEX external_auth_tokens_pkey ON public.external_auth_tokens USING btree (user_id);
    ALTER TABLE public.external_auth_tokens ADD CONSTRAINT external_auth_tokens_pkey PRIMARY KEY USING INDEX external_auth_tokens_pkey;
  END IF;
END $$;

-- Add check constraints idempotently
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'friends_friend_status_check') THEN
    ALTER TABLE public.friends ADD CONSTRAINT friends_friend_status_check
      CHECK (friend_status = ANY (ARRAY['accepted'::text, 'pending'::text])) NOT VALID;
    ALTER TABLE public.friends VALIDATE CONSTRAINT friends_friend_status_check;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'friends_user_status_check') THEN
    ALTER TABLE public.friends ADD CONSTRAINT friends_user_status_check
      CHECK (user_status = ANY (ARRAY['accepted'::text, 'pending'::text])) NOT VALID;
    ALTER TABLE public.friends VALIDATE CONSTRAINT friends_user_status_check;
  END IF;
END $$;

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.get_current_study_spots(user_lat double precision, user_lon double precision)
 RETURNS TABLE(id uuid, name text)
 LANGUAGE sql
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.get_friends_in_same_study_spot(current_user_id uuid)
 RETURNS TABLE(user_id uuid, display_name text, last_known_lat double precision, last_known_lng double precision, altitude double precision, spot_name text)
 LANGUAGE sql
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.get_study_spots_with_coordinates()
 RETURNS TABLE(spot_id uuid, name text, is_active boolean, coordinates jsonb)
 LANGUAGE sql
AS $function$ SELECT s.spot_id, s.name, s.is_active, (SELECT jsonb_agg(jsonb_build_array(ST_X(geom), ST_Y(geom)) ORDER BY path) FROM ST_DumpPoints(s.geofence::geometry) AS dp(path, geom)) AS coordinates FROM study_spots s; $function$
;

CREATE OR REPLACE FUNCTION public.get_surrounding_study_spots(user_lat double precision, user_lon double precision)
 RETURNS TABLE(id uuid, name text)
 LANGUAGE sql
AS $function$ SELECT spot_id, name FROM study_spots WHERE ST_Contains(geofence::geometry, ST_SetSRID(ST_MakePoint(user_lon, user_lat), 4326)); $function$
;

CREATE OR REPLACE FUNCTION public.get_user_study_spot(target_user_id uuid)
 RETURNS TABLE(spot_id uuid, name text)
 LANGUAGE sql
AS $function$ SELECT s.spot_id, s.name FROM public.users u JOIN public.study_spots s ON ST_Contains(s.geofence::geometry, ST_SetSRID(ST_MakePoint(u.last_known_lng, u.last_known_lat), 4326)) WHERE u.user_id = target_user_id AND u.is_invisible = false AND u.last_known_lat IS NOT NULL AND u.last_known_lng IS NOT NULL LIMIT 1; $function$
;

CREATE OR REPLACE FUNCTION public.get_users_in_study_spots()
 RETURNS TABLE(user_id uuid, display_name text, last_known_lat double precision, last_known_lng double precision, spot_name text)
 LANGUAGE sql
AS $function$ SELECT u.user_id, u.display_name, u.last_known_lat, u.last_known_lng, s.name AS spot_name FROM public.users u JOIN public.study_spots s ON ST_Contains(s.geofence::geometry, ST_SetSRID(ST_MakePoint(u.last_known_lng, u.last_known_lat), 4326)) WHERE u.is_invisible = false AND u.last_known_lat IS NOT NULL AND u.last_known_lng IS NOT NULL; $function$
;


