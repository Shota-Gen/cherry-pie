-- Auto-update the study_spot column whenever a user's location changes.
-- Uses a trigger so the study_spot text is always consistent with PostGIS geofences.

CREATE OR REPLACE FUNCTION update_user_study_spot()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    spot_name_val TEXT;
BEGIN
    -- Only run when location actually changed
    IF NEW.last_known_lat IS NOT NULL AND NEW.last_known_lng IS NOT NULL THEN
        SELECT s.name INTO spot_name_val
        FROM public.study_spots s
        WHERE ST_Contains(
            s.geofence::geometry,
            ST_SetSRID(ST_MakePoint(NEW.last_known_lng, NEW.last_known_lat), 4326)
        )
        LIMIT 1;

        NEW.study_spot := spot_name_val;  -- NULL if not inside any spot
    END IF;

    RETURN NEW;
END;
$$;

-- Drop existing trigger if any, then create
DROP TRIGGER IF EXISTS trg_update_user_study_spot ON public.users;
CREATE TRIGGER trg_update_user_study_spot
    BEFORE UPDATE OF last_known_lat, last_known_lng ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION update_user_study_spot();
