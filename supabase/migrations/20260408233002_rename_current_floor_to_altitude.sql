-- Rename current_floor to altitude and change type from INTEGER to DOUBLE PRECISION
ALTER TABLE public.users RENAME COLUMN current_floor TO altitude;
ALTER TABLE public.users ALTER COLUMN altitude SET DATA TYPE DOUBLE PRECISION USING altitude::DOUBLE PRECISION;
ALTER TABLE public.users ALTER COLUMN altitude SET DEFAULT 0;
