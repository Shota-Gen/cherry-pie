"""
Smart Scheduler router — suggest optimal study session times using
Google Calendar FreeBusy + Gemini LLM analysis.
"""

import logging
import os
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from config import SupabaseDep, settings
from services.google_calendar import (
    fetch_participant_availability,
    ParticipantAvailability,
)
from services.gemini_scheduler import (
    suggest_times,
    suggest_times_fallback,
    SuggestedSlot,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/scheduler", tags=["scheduler"])


# ---------------------------------------------------------------------------
# Request / Response Models
# ---------------------------------------------------------------------------


class StoreTokenRequest(BaseModel):
    """Payload for storing a Google OAuth refresh token."""
    user_id: str = Field(..., description="UUID of the user")
    refresh_token: str = Field(..., description="Google OAuth refresh token")
    access_token: str = Field("", description="Current Google access token (optional)")
    google_email: str = Field(..., description="User's Google email address")
    scopes: list[str] = Field(
        default_factory=lambda: ["https://www.googleapis.com/auth/calendar.freebusy"],
        description="Scopes granted by the user",
    )


class StoreTokenResponse(BaseModel):
    user_id: str
    google_email: str
    scopes_granted: list[str]
    stored: bool


class SuggestTimesRequest(BaseModel):
    """Payload for the suggest-times endpoint."""
    host_id: str = Field(..., description="UUID of the session host")
    participant_ids: list[str] = Field(
        ..., min_length=1, description="UUIDs of all participants (including host)"
    )
    window_start: datetime = Field(..., description="Start of the search window (ISO 8601)")
    window_end: datetime = Field(..., description="End of the search window (ISO 8601)")
    duration_minutes: int = Field(
        60, ge=15, le=480, description="Desired session length in minutes"
    )


class SlotResponse(BaseModel):
    """A single suggested time slot."""
    start: str
    end: str
    available_user_ids: list[str]
    busy_user_ids: list[str]
    score: float
    reason: str


class SuggestTimesResponse(BaseModel):
    """Response from the suggest-times endpoint."""
    slots: list[SlotResponse]
    participants_queried: int
    participants_with_calendar: int
    used_llm: bool  # True if Gemini was used, False if fallback


class ParticipantCalendarStatus(BaseModel):
    user_id: str
    has_calendar_linked: bool
    google_email: str | None = None


class CalendarStatusResponse(BaseModel):
    participants: list[ParticipantCalendarStatus]


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.post(
    "/store-token",
    response_model=StoreTokenResponse,
    status_code=status.HTTP_200_OK,
)
def store_google_token(payload: StoreTokenRequest, supabase: SupabaseDep):
    """
    Store (or update) a user's Google OAuth refresh token.

    Called by the iOS app after the user grants calendar permissions.
    The token is stored in `external_auth_tokens` for later FreeBusy queries.
    """

    # Verify user exists
    try:
        user_result = (
            supabase.table("users")
            .select("user_id")
            .eq("user_id", payload.user_id)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to verify user: {exc}",
        )

    if not user_result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )

    # Upsert the token row
    token_row = {
        "user_id": payload.user_id,
        "provider": "google",
        "refresh_token_encrypted": payload.refresh_token,
        "access_token_encrypted": payload.access_token or "",
        "google_email": payload.google_email,
        "scopes_granted": payload.scopes,
        "token_expiry": None,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }

    try:
        supabase.table("external_auth_tokens").upsert(
            token_row,
            on_conflict="user_id,provider",
        ).execute()
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to store token: {exc}",
        )

    return StoreTokenResponse(
        user_id=payload.user_id,
        google_email=payload.google_email,
        scopes_granted=payload.scopes,
        stored=True,
    )


@router.post(
    "/calendar-status",
    response_model=CalendarStatusResponse,
)
def check_calendar_status(
    participant_ids: list[str],
    supabase: SupabaseDep,
):
    """
    Check which participants have linked their Google Calendar.
    
    Useful for the iOS app to show which friends need to grant
    calendar permissions before scheduling.
    """
    try:
        tokens_result = (
            supabase.table("external_auth_tokens")
            .select("user_id, google_email, scopes_granted")
            .eq("provider", "google")
            .in_("user_id", participant_ids)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to check calendar status: {exc}",
        )

    token_map = {t["user_id"]: t for t in tokens_result.data}

    participants = []
    for uid in participant_ids:
        token = token_map.get(uid)
        has_calendar = (
            token is not None
            and "https://www.googleapis.com/auth/calendar.freebusy"
            in (token.get("scopes_granted") or [])
        )
        participants.append(
            ParticipantCalendarStatus(
                user_id=uid,
                has_calendar_linked=has_calendar,
                google_email=token.get("google_email") if token else None,
            )
        )

    return CalendarStatusResponse(participants=participants)


@router.post(
    "/suggest-times",
    response_model=SuggestTimesResponse,
)
def suggest_session_times(
    payload: SuggestTimesRequest,
    supabase: SupabaseDep,
):
    """
    Main Smart Scheduler endpoint.

    Flow:
      1. Fetch OAuth tokens for all participants from the DB
      2. Query Google Calendar FreeBusy for busy blocks
      3. Send availability data to Gemini for analysis
      4. Return ranked time slot suggestions

    Graceful degradation:
      - If a participant hasn't linked their calendar, they're treated as "available"
      - If Gemini fails, falls back to deterministic scheduling
      - If no tokens exist at all, uses deterministic scheduling with empty busy blocks
    """

    # -- 1. Fetch user details + tokens ----------------------------------------
    try:
        users_result = (
            supabase.table("users")
            .select("user_id, display_name, email")
            .in_("user_id", payload.participant_ids)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch participants: {exc}",
        )

    users_map = {u["user_id"]: u for u in users_result.data}

    # Verify all participants exist
    missing = set(payload.participant_ids) - set(users_map.keys())
    if missing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Participants not found: {sorted(missing)}",
        )

    # Fetch Google OAuth tokens
    try:
        tokens_result = (
            supabase.table("external_auth_tokens")
            .select("user_id, refresh_token_encrypted, google_email, scopes_granted")
            .eq("provider", "google")
            .in_("user_id", payload.participant_ids)
            .execute()
        )
    except Exception as exc:
        logger.warning("Failed to fetch tokens: %s", exc)
        tokens_result = type("R", (), {"data": []})()

    token_map = {t["user_id"]: t for t in tokens_result.data}
    participants_with_calendar = len(token_map)

    # -- 2. Query FreeBusy (if we have at least the host's token) ---------------
    host_token = token_map.get(payload.host_id)
    google_client_id = os.getenv("GOOGLE_CLIENT_ID", "")
    google_client_secret = os.getenv("GOOGLE_CLIENT_SECRET", "")

    participant_data: list[dict] = []

    if host_token and google_client_id and google_client_secret:
        # Build participant list with Google emails where available
        participant_list = []
        for uid in payload.participant_ids:
            user = users_map[uid]
            token = token_map.get(uid)
            google_email = (
                token.get("google_email") if token else user.get("email", "")
            )
            participant_list.append({
                "user_id": uid,
                "email": google_email or user.get("email", ""),
            })

        # Query FreeBusy
        try:
            availability = fetch_participant_availability(
                participants=participant_list,
                time_min=payload.window_start,
                time_max=payload.window_end,
                host_token=host_token,
                client_id=google_client_id,
                client_secret=google_client_secret,
            )

            for avail in availability:
                user = users_map.get(avail.user_id, {})
                participant_data.append({
                    "user_id": avail.user_id,
                    "display_name": user.get("display_name", "Unknown"),
                    "email": avail.email,
                    "busy_blocks": [
                        {"start": b.start.isoformat(), "end": b.end.isoformat()}
                        for b in avail.busy_blocks
                    ],
                    "error": avail.error,
                })
        except Exception as exc:
            logger.error("FreeBusy query failed: %s", exc)
            # Fall through to build participant_data without busy blocks
            participant_data = []

    # If FreeBusy failed or no tokens, build data with empty busy blocks
    if not participant_data:
        for uid in payload.participant_ids:
            user = users_map[uid]
            has_token = uid in token_map
            participant_data.append({
                "user_id": uid,
                "display_name": user.get("display_name", "Unknown"),
                "email": user.get("email", ""),
                "busy_blocks": [],
                "error": None if has_token else "Calendar not linked",
            })

    # -- 3. LLM analysis (with fallback) ----------------------------------------
    gemini_key = os.getenv("GEMINI_API_KEY")
    used_llm = False
    slots: list[SuggestedSlot] = []

    if gemini_key:
        try:
            slots = suggest_times(
                participant_data=participant_data,
                window_start=payload.window_start,
                window_end=payload.window_end,
                duration_minutes=payload.duration_minutes,
                api_key=gemini_key,
            )
            used_llm = True
        except Exception as exc:
            logger.error("Gemini scheduling failed, using fallback: %s", exc)

    if not slots:
        slots = suggest_times_fallback(
            participant_data=participant_data,
            window_start=payload.window_start,
            window_end=payload.window_end,
            duration_minutes=payload.duration_minutes,
        )

    # -- 4. Build response -------------------------------------------------------
    return SuggestTimesResponse(
        slots=[
            SlotResponse(
                start=s.start,
                end=s.end,
                available_user_ids=s.available_user_ids,
                busy_user_ids=s.busy_user_ids,
                score=s.score,
                reason=s.reason,
            )
            for s in slots
        ],
        participants_queried=len(payload.participant_ids),
        participants_with_calendar=participants_with_calendar,
        used_llm=used_llm,
    )
