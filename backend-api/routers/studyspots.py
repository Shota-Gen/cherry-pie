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
"""
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
"""
class UserLocation(BaseModel):
    lat: float
    lng: float
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
    
@studyspots_router.post("/v1/containing_user/", status_code=status.HTTP_201_CREATED)
def get_study_spots_containing_user(location: UserLocation, supabase: SupabaseDep):
    """
    Gets study spots that the user is in
    """
    try:
        # Call the Supabase RPC
        response = supabase.rpc(
            "get_surrounding_study_spots", 
            {
                "user_lat": location.lat, 
                "user_lon": location.lng
            }
        ).execute()
        
        # response.data will contain a list of spots the user is currently inside
        return {"matching_spots": response.data}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

