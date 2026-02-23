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
        ST_GeomFromText('POLYGON((-83.7370 42.2750, -83.7350 42.2750, -83.7350 42.2730, -83.7370 42.2730, -83.7370 42.2750))', 4326)
    ),
    (
        'The Fishbowl (Mason Hall)', 
        ST_GeomFromText('POLYGON((-83.7405 42.2765, -83.7390 42.2765, -83.7390 42.2750, -83.7405 42.2750, -83.7405 42.2765))', 4326)
    );