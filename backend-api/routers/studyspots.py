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
# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------
    

@studyspots_router.get("/v1/public/", status_code=status.HTTP_200_OK)
def get_public_study_spots_coords(supabase: SupabaseDep):
    """
    Get all public study spots with their polygon coordinates.
    """
    try:
        data = supabase.rpc("get_study_spots_with_coordinates").execute()
        return data.data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
@studyspots_router.get("/v1/user-spot/{user_id}", status_code=status.HTTP_200_OK)
def get_user_study_spot(user_id: str, supabase: SupabaseDep):
    """
    Get the study spot a specific user is currently inside.
    Returns empty list if the user is not in a spot, is invisible, or has no location.
    """
    try:
        data = supabase.rpc("get_user_study_spot", {"target_user_id": user_id}).execute()
        return data.data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@studyspots_router.get("/v1/active-users/", status_code=status.HTTP_200_OK)
def get_active_users_in_study_spots(supabase: SupabaseDep):
    """
    Get all visible users whose last known location is inside a study spot.
    Invisible (ghost mode) users are excluded.
    """
    try:
        data = supabase.rpc("get_users_in_study_spots").execute()
        return data.data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
