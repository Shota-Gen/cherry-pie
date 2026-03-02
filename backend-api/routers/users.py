"""
Users router — handles user registration and profile creation.
"""

from datetime import datetime

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, EmailStr

from config import SupabaseDep

router = APIRouter(prefix="/users", tags=["users"])


# ---------------------------------------------------------------------------
# Request / Response Models
# ---------------------------------------------------------------------------


class UserCreate(BaseModel):
    display_name: str
    email: EmailStr
    password: str
    device_id: str | None = None


class UserResponse(BaseModel):
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


@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def create_user(payload: UserCreate, supabase: SupabaseDep):
    """
    Register a new user.

    1. Creates an auth user in Supabase Auth (admin API).
    2. Inserts a profile row into public.users.
    """

    # -- Step 1: Create Supabase Auth user --
    try:
        auth_response = supabase.auth.admin.create_user(
            {
                "email": payload.email,
                "password": payload.password,
                "email_confirm": True,  # auto-confirm for dev convenience
            }
        )
    except Exception as exc:
        error_msg = str(exc).lower()
        if "already" in error_msg or "duplicate" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A user with this email already exists.",
            )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create auth user: {exc}",
        )

    user_id = auth_response.user.id

    # -- Step 2: Insert profile into public.users --
    profile = {
        "user_id": str(user_id),
        "display_name": payload.display_name,
        "email": payload.email,
    }
    if payload.device_id is not None:
        profile["device_id"] = payload.device_id

    try:
        result = (
            supabase.table("users")
            .insert(profile)
            .execute()
        )
    except Exception as exc:
        # Roll back the auth user if the profile insert fails
        try:
            supabase.auth.admin.delete_user(str(user_id))
        except Exception:
            pass  # best-effort cleanup
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create user profile: {exc}",
        )

    created = result.data[0]
    return UserResponse(**created)
