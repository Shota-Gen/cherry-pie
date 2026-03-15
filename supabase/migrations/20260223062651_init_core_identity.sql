-- 1. Create the Users/Profiles table
CREATE TABLE public.users (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    profile_image TEXT,
    study_spot TEXT,
    major TEXT,
    university_year INTEGER,
    device_id TEXT UNIQUE,
    is_invisible BOOLEAN DEFAULT FALSE,
    last_known_lat DOUBLE PRECISION,
    last_known_lng DOUBLE PRECISION,
    current_floor INTEGER DEFAULT 1, -- Added for Jeffrey's barometer data
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Enable PostGIS (needed by study_spots)
CREATE EXTENSION IF NOT EXISTS postgis with schema "extensions";

-- 3. Create the Study Spots table (must exist before sessions references it)
CREATE TABLE public.study_spots (
    spot_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE, -- e.g., 'UGLI 1st Floor'

    -- Using GEOGRAPHY(Polygon, 4326) for high-accuracy Earth coordinates
    geofence extensions.geography(Polygon, 4326) NOT NULL,

    -- Metadata
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Spatial Index for performance
CREATE INDEX study_spots_geo_idx ON public.study_spots USING GIST (geofence);

-- 4. Create the Sessions table
CREATE TABLE public.sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_by UUID NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    study_spot_id UUID REFERENCES public.study_spots(spot_id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    starts_at TIMESTAMP WITH TIME ZONE NOT NULL,
    ends_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT valid_session_window CHECK (ends_at > starts_at)
);

-- 3. Create the Session Members table (owner + all invited users)
CREATE TYPE public.session_invite_status AS ENUM ('pending', 'accepted', 'declined');

CREATE TABLE public.session_members (
    session_id UUID NOT NULL REFERENCES public.sessions(session_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    status public.session_invite_status NOT NULL DEFAULT 'pending',
    invited_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    responded_at TIMESTAMP WITH TIME ZONE,
    PRIMARY KEY (session_id, user_id)
);

-- 4. Create the Tokens table for Anant
CREATE TABLE public.external_auth_tokens (
    user_id UUID REFERENCES public.users(user_id) PRIMARY KEY,
    access_token_encrypted TEXT NOT NULL,
    refresh_token_encrypted TEXT NOT NULL,
    token_expiry TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);