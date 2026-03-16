-- Clear the table before seeding
TRUNCATE public.study_spots, public.users CASCADE;

-- Insert into auth first
INSERT INTO auth.users (id, email)
VALUES ('6f8e7d2a-1b3c-4d5e-8f7a-9b0c1d2e3f4a', 'sgen@umich.edu');

-- Insert Test Users
INSERT INTO public.users (user_id, display_name, email, current_floor)
VALUES ('6f8e7d2a-1b3c-4d5e-8f7a-9b0c1d2e3f4a', 'Shota (Lead)', 'sgen@umich.edu', 1);

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
              ))', 4326);
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