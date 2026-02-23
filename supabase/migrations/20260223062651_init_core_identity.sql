-- 1. Create the Users/Profiles table
CREATE TABLE public.users (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    device_id TEXT UNIQUE,
    is_invisible BOOLEAN DEFAULT FALSE,
    last_known_lat DOUBLE PRECISION,
    last_known_lng DOUBLE PRECISION,
    current_floor INTEGER DEFAULT 1, -- Added for Jeffrey's barometer data
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create the Tokens table for Anant
CREATE TABLE public.external_auth_tokens (
    user_id UUID REFERENCES public.users(user_id) PRIMARY KEY,
    access_token_encrypted TEXT NOT NULL,
    refresh_token_encrypted TEXT NOT NULL,
    token_expiry TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);