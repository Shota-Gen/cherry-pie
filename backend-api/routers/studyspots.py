"""
StudySpots router — handles study spot creation and management.
"""

from datetime import datetime

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, EmailStr

from config import SupabaseDep

studyspots_router = APIRouter(prefix="/studyspots", tags=["studyspots"])


# ---------------------------------------------------------------------------
# Request / Response Models
# ---------------------------------------------------------------------------

class StudySpotResponse(BaseModel):
    user_id: str
    display_name: str
    email: str
    device_id: str | None = None
    is_invisible: bool = False
    last_known_lat: float | None = None
    last_known_lng: float | None = None
    current_floor: int = 1
    created_at: datetime | None = None


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@studyspots_router.get("/v1/", status_code=status.HTTP_201_CREATED)
def get_public_study_spots_coords():
    """
    Get all available commands
    """
    return {
        "commands": [
            {"name": "/public/", "description": "Get all public study spots."},
        ]
    }
    

@studyspots_router.get("/public/", status_code=status.HTTP_201_CREATED)
def get_public_study_spots_coords(supabase: SupabaseDep):
    """
    Get all public study spots.

    """
    # -- Step 1: Fetch all users from public.users --
    try:
        data = supabase.table("study_spots").select("*").execute()
        #if data.error:
        #   raise HTTPException(status_code=500, detail="Failed to fetch study spots")
        return data.data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
