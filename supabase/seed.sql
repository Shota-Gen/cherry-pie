-- Clear the tables before seeding
TRUNCATE auth.users CASCADE;
TRUNCATE public.study_spots, public.users CASCADE;

-- Insert into auth first (GoTrue scans ALL varchar/text columns into Go strings;
-- NULL→string causes a crash, so every string column must be explicitly non-NULL.
-- Exception: phone has a UNIQUE constraint and must stay NULL for users without phones.)
INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token,
    email_change_token_new, email_change, email_change_token_current,
    phone_change, phone_change_token,
    reauthentication_token,
    is_sso_user, is_anonymous
)
VALUES 
    ('6f8e7d2a-1b3c-4d5e-8f7a-9b0c1d2e3f4a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sgen@umich.edu', '',
     NOW(), NOW(), NOW(), '{"provider":"email","providers":["email"]}', '{"email":"sgen@umich.edu"}',
     '', '', '', '', '', '', '', '', false, false),
    ('a1111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'alice@umich.edu', '',
     NOW(), NOW(), NOW(), '{"provider":"email","providers":["email"]}', '{"email":"alice@umich.edu"}',
     '', '', '', '', '', '', '', '', false, false),
    ('b2222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'bob@umich.edu', '',
     NOW(), NOW(), NOW(), '{"provider":"email","providers":["email"]}', '{"email":"bob@umich.edu"}',
     '', '', '', '', '', '', '', '', false, false),
    ('c3333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'carol@umich.edu', '',
     NOW(), NOW(), NOW(), '{"provider":"email","providers":["email"]}', '{"email":"carol@umich.edu"}',
     '', '', '', '', '', '', '', '', false, false),
    ('d4444444-4444-4444-4444-444444444444', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'dave@umich.edu', '',
     NOW(), NOW(), NOW(), '{"provider":"email","providers":["email"]}', '{"email":"dave@umich.edu"}',
     '', '', '', '', '', '', '', '', false, false),
    ('e5555555-5555-5555-5555-555555555555', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'eve@umich.edu', '',
     NOW(), NOW(), NOW(), '{"provider":"email","providers":["email"]}', '{"email":"eve@umich.edu"}',
     '', '', '', '', '', '', '', '', false, false),
    ('52f91d58-3fbb-40ad-b1a7-9e2b8b8e2db3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'anantgar@umich.edu', '',
     NOW(), NOW(), NOW(), '{"provider":"email","providers":["email"]}', '{"email":"anantgar@umich.edu"}',
     '', '', '', '', '', '', '', '', false, false);

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
    
