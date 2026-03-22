-- 1. Enable PostGIS to handle geographic polygons
CREATE EXTENSION IF NOT EXISTS postgis with schema "extensions";

-- 2. Create the Public Study Spots Table
CREATE TABLE public.study_spots (
    spot_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE, -- e.g., 'UGLI 1st Floor'
    
    -- Using GEOGRAPHY(Polygon, 4326) for high-accuracy Earth coordinates
    geofence extensions.geography(Polygon, 4326) NOT NULL,
    
    -- Metadata
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Spatial Index for performance
CREATE INDEX study_spots_geo_idx ON public.study_spots USING GIST (geofence);
