drop extension if exists "pg_net";

create schema if not exists "tiger";

create extension if not exists "fuzzystrmatch" with schema "tiger";

create extension if not exists "postgis_tiger_geocoder" with schema "tiger";

create type "public"."friend_status" as enum ('pending', 'rejected', 'accepted');

alter table "public"."external_auth_tokens" drop constraint "external_auth_tokens_pkey";

drop index if exists "public"."idx_external_auth_tokens_provider";

drop index if exists "public"."external_auth_tokens_pkey";

alter table "public"."external_auth_tokens" drop column "google_email";

alter table "public"."external_auth_tokens" drop column "provider";

alter table "public"."external_auth_tokens" drop column "scopes_granted";

alter table "public"."friends" add column "friend_status" text not null default 'pending'::text;

alter table "public"."friends" add column "user_status" text not null default 'accepted'::text;

alter table "public"."users" drop column "current_floor";

alter table "public"."users" add column "altitude" double precision default 0;

CREATE INDEX friends_pending_requests_idx ON public.friends USING btree (friend_id) WHERE (friend_status = 'pending'::text);

CREATE UNIQUE INDEX external_auth_tokens_pkey ON public.external_auth_tokens USING btree (user_id);

alter table "public"."external_auth_tokens" add constraint "external_auth_tokens_pkey" PRIMARY KEY using index "external_auth_tokens_pkey";

alter table "public"."friends" add constraint "friends_friend_status_check" CHECK ((friend_status = ANY (ARRAY['accepted'::text, 'pending'::text]))) not valid;

alter table "public"."friends" validate constraint "friends_friend_status_check";

alter table "public"."friends" add constraint "friends_user_status_check" CHECK ((user_status = ANY (ARRAY['accepted'::text, 'pending'::text]))) not valid;

alter table "public"."friends" validate constraint "friends_user_status_check";

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


