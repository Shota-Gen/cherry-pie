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
    ('711b7d5a-2c3c-4f5e-8e7a-1b2c3d4e5f6a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'alice@umich.edu', '',
     NOW(), NOW(), NOW(), '{"provider":"email","providers":["email"]}', '{"email":"alice@umich.edu"}',
     '', '', '', '', '', '', '', '', false, false),
    ('812c8e6b-3d4d-5f6e-9f8b-2c3d4e5f6c7b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'bob@umich.edu', '',
     NOW(), NOW(), NOW(), '{"provider":"email","providers":["email"]}', '{"email":"bob@umich.edu"}',
     '', '', '', '', '', '', '', '', false, false),
    ('52f91d58-3fbb-40ad-b1a7-9e2b8b8e2db3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'anantgar@umich.edu', '',
     NOW(), NOW(), NOW(), '{"provider":"email","providers":["email"]}', '{"email":"anantgar@umich.edu"}',
     '', '', '', '', '', '', '', '', false, false);

-- Insert Test Users
INSERT INTO public.users (user_id, display_name, email, current_floor)
VALUES 
    ('6f8e7d2a-1b3c-4d5e-8f7a-9b0c1d2e3f4a', 'Shota', 'sgen@umich.edu', 1),
    ('711b7d5a-2c3c-4f5e-8e7a-1b2c3d4e5f6a', 'Alice', 'alice@umich.edu', 1),
    ('812c8e6b-3d4d-5f6e-9f8b-2c3d4e5f6c7b', 'Bob', 'bob@umich.edu', 1),
    ('52f91d58-3fbb-40ad-b1a7-9e2b8b8e2db3', 'Anant (Test)', 'anantgar@umich.edu', 1)
ON CONFLICT (user_id) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    email = EXCLUDED.email,
    current_floor = EXCLUDED.current_floor;

-- Insert Friends
INSERT INTO public.friends (user_id, friend_id)
VALUES 
    ('6f8e7d2a-1b3c-4d5e-8f7a-9b0c1d2e3f4a', '711b7d5a-2c3c-4f5e-8e7a-1b2c3d4e5f6a'),
    ('6f8e7d2a-1b3c-4d5e-8f7a-9b0c1d2e3f4a', '812c8e6b-3d4d-5f6e-9f8b-2c3d4e5f6c7b'),
    ('52f91d58-3fbb-40ad-b1a7-9e2b8b8e2db3', '6f8e7d2a-1b3c-4d5e-8f7a-9b0c1d2e3f4a'),
    ('52f91d58-3fbb-40ad-b1a7-9e2b8b8e2db3', '711b7d5a-2c3c-4f5e-8e7a-1b2c3d4e5f6a'),
    ('52f91d58-3fbb-40ad-b1a7-9e2b8b8e2db3', '812c8e6b-3d4d-5f6e-9f8b-2c3d4e5f6c7b');

-- Insert the two primary U-M test zones
INSERT INTO public.study_spots (name, geofence)
VALUES 
    (
        'UGLI (Shapiro Library)', 
        ST_GeomFromText('POLYGON((-83.7370 42.2750, -83.7350 42.2750, -83.7350 42.2730, -83.7370 42.2730, -83.7370 42.2750))', 4326)
    ),
    (
        'The Fishbowl (Mason Hall)', 
        ST_GeomFromText('POLYGON((-83.7405 42.2765, -83.7390 42.2765, -83.7390 42.2750, -83.7405 42.2750, -83.7405 42.2765))', 4326)
    );