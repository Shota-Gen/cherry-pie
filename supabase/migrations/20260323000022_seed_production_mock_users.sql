-- Insert auth users (mock users)
-- We avoid inserting Shota's Google user here to prevent conflicts with his actual account.
INSERT INTO auth.users (
    id, email, aud, role, email_confirmed_at,
    encrypted_password, confirmation_token, recovery_token,
    email_change_token_new, email_change, raw_app_meta_data, raw_user_meta_data,
    instance_id, created_at, updated_at
)
VALUES
    ('a1111111-1111-1111-1111-111111111111', 'alice@umich.edu',    'authenticated', 'authenticated', now(), '', '', '', '', '', '{}'::jsonb, '{}'::jsonb, '00000000-0000-0000-0000-000000000000', now(), now()),
    ('b2222222-2222-2222-2222-222222222222', 'bob@umich.edu',      'authenticated', 'authenticated', now(), '', '', '', '', '', '{}'::jsonb, '{}'::jsonb, '00000000-0000-0000-0000-000000000000', now(), now()),
    ('c3333333-3333-3333-3333-333333333333', 'carol@umich.edu',    'authenticated', 'authenticated', now(), '', '', '', '', '', '{}'::jsonb, '{}'::jsonb, '00000000-0000-0000-0000-000000000000', now(), now()),
    ('d4444444-4444-4444-4444-444444444444', 'dave@umich.edu',     'authenticated', 'authenticated', now(), '', '', '', '', '', '{}'::jsonb, '{}'::jsonb, '00000000-0000-0000-0000-000000000000', now(), now()),
    ('e5555555-5555-5555-5555-555555555555', 'eve@umich.edu',      'authenticated', 'authenticated', now(), '', '', '', '', '', '{}'::jsonb, '{}'::jsonb, '00000000-0000-0000-0000-000000000000', now(), now())
ON CONFLICT (id) DO NOTHING;

-- Insert public.users profiles for mock users
INSERT INTO public.users (user_id, display_name, email, current_floor, last_known_lat, last_known_lng, is_invisible)
VALUES
    ('a1111111-1111-1111-1111-111111111111',   'Alice Johnson', 'alice@umich.edu',  1, 42.2756, -83.7371, false),
    ('b2222222-2222-2222-2222-222222222222',   'Bob Smith',     'bob@umich.edu',    1, 42.2769, -83.7396, false),
    ('c3333333-3333-3333-3333-333333333333',   'Carol Davis',   'carol@umich.edu',  1, 42.2738, -83.7394, true),
    ('d4444444-4444-4444-4444-444444444444',   'Dave Wilson',   'dave@umich.edu',   1, 42.2780, -83.7380, false),
    ('e5555555-5555-5555-5555-555555555555',   'Eve Martinez',  'eve@umich.edu',    1, 40.7128, -74.0060, false)
ON CONFLICT (user_id) DO NOTHING;
