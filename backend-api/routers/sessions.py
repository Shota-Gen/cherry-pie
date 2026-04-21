"""
Sessions router — create and manage private study sessions.
"""

import logging
import os
from datetime import datetime, timezone
from enum import Enum
from typing import Optional

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field, field_validator

from config import SupabaseDep
from services.google_calendar_invite import send_session_calendar_invites

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/sessions", tags=["sessions"])


# ---------------------------------------------------------------------------
# Request / Response Models
# ---------------------------------------------------------------------------


class PrivateSessionCreate(BaseModel):
    """Payload for creating a new private study session."""

    title: str = Field(..., min_length=1, max_length=200, description="Session title")
    description: str | None = Field(
        None, max_length=2000, description="Optional session description"
    )
    study_spot_id: str | None = Field(
        None, description="UUID of the study spot (optional)"
    )
    location_name: str | None = Field(
        None, max_length=500, description="Free-form location name"
    )
    starts_at: datetime = Field(..., description="Session start time (ISO 8601)")
    ends_at: datetime = Field(..., description="Session end time (ISO 8601)")
    invitee_ids: list[str] = Field(
        ...,
        min_length=1,
        description="List of user_id UUIDs to invite",
    )
    add_google_meet: bool = Field(
        False, description="Whether to auto-create a Google Meet link"
    )

    @field_validator("ends_at")
    @classmethod
    def ends_after_starts(cls, v: datetime, info):
        starts = info.data.get("starts_at")
        if starts and v <= starts:
            raise ValueError("ends_at must be after starts_at")
        return v


class SessionMemberResponse(BaseModel):
    user_id: str
    display_name: str
    email: str
    status: str  # 'pending' | 'accepted' | 'declined'
    invited_at: datetime | None = None


class PrivateSessionResponse(BaseModel):
    session_id: str
    created_by: str
    session_type: str
    title: str
    description: str | None = None
    study_spot_id: str | None = None
    location_name: str | None = None
    starts_at: datetime
    ends_at: datetime
    created_at: datetime | None = None
    members: list[SessionMemberResponse] = []


class SessionListItem(BaseModel):
    session_id: str
    title: str
    session_type: str
    starts_at: datetime
    ends_at: datetime
    created_at: datetime | None = None
    member_count: int = 0


class InviteAction(str, Enum):
    accept = "accepted"
    decline = "declined"


class InviteRespond(BaseModel):
    """Payload for responding to a session invitation."""

    user_id: str = Field(..., description="UUID of the user responding")
    action: InviteAction = Field(..., description="'accepted' or 'declined'")


class InviteRespondResponse(BaseModel):
    session_id: str
    user_id: str
    status: str
    responded_at: datetime | None = None


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.post(
    "/private",
    response_model=PrivateSessionResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_private_session(
    payload: PrivateSessionCreate,
    creator_id: str,          # TODO: replace with auth dependency once JWT middleware is wired
    supabase: SupabaseDep,
):
    """
    Create a private study session and invite friends.

    Flow:
      1. Validate that the creator exists.
      2. Validate that all invitees exist.
      3. Insert the session row into public.sessions.
      4. Insert rows into public.session_members for each invitee.
      5. (Best-effort) send invitation emails to the invitees.
      6. Return the created session with its members.
    """

    # -- 1. Verify the creator exists ----------------------------------------
    try:
        creator_result = (
            supabase.table("users")
            .select("user_id, display_name, email")
            .eq("user_id", creator_id)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to look up creator: {exc}",
        )

    if not creator_result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Creator user not found.",
        )

    creator = creator_result.data[0]

    # -- 2. Verify all invitees exist ----------------------------------------
    try:
        invitees_result = (
            supabase.table("users")
            .select("user_id, display_name, email")
            .in_("user_id", payload.invitee_ids)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to look up invitees: {exc}",
        )

    found_ids = {u["user_id"] for u in invitees_result.data}
    missing = set(payload.invitee_ids) - found_ids
    if missing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"The following invitee IDs were not found: {sorted(missing)}",
        )

    # Prevent inviting yourself
    invitee_ids = [uid for uid in payload.invitee_ids if uid != creator_id]
    if not invitee_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You must invite at least one friend other than yourself.",
        )

    # -- 3. Insert session row -----------------------------------------------
    session_row = {
        "created_by": creator_id,
        "session_type": "private",
        "title": payload.title,
        "description": payload.description,
        "starts_at": payload.starts_at.isoformat(),
        "ends_at": payload.ends_at.isoformat(),
    }
    if payload.study_spot_id:
        session_row["study_spot_id"] = payload.study_spot_id
    if payload.location_name:
        session_row["location_name"] = payload.location_name

    try:
        session_result = (
            supabase.table("sessions")
            .insert(session_row)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create session: {exc}",
        )

    session = session_result.data[0]
    session_id = session["session_id"]

    # -- 4. Insert session_members for each invitee --------------------------
    member_rows = [
        {
            "session_id": session_id,
            "user_id": uid,
            "status": "pending",
        }
        for uid in invitee_ids
    ]

    # Also add the creator as an accepted member
    member_rows.append(
        {
            "session_id": session_id,
            "user_id": creator_id,
            "status": "accepted",
        }
    )

    try:
        members_result = (
            supabase.table("session_members")
            .insert(member_rows)
            .execute()
        )
    except Exception as exc:
        # Best-effort rollback: delete the session if member inserts fail
        try:
            supabase.table("sessions").delete().eq("session_id", session_id).execute()
        except Exception:
            pass
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to add session members: {exc}",
        )

    # -- 5. Send invite emails (best-effort, non-blocking) -------------------
    invitee_users = [u for u in invitees_result.data if u["user_id"] in set(invitee_ids)]

    # -- 5b. Send Google Calendar invites (best-effort) ----------------------
    google_client_id = os.getenv("GOOGLE_CLIENT_ID", "")
    google_client_secret = os.getenv("GOOGLE_CLIENT_SECRET", "")

    if google_client_id and google_client_secret:
        try:
            # Look up the host's stored Google OAuth token
            host_token_result = (
                supabase.table("external_auth_tokens")
                .select("refresh_token_encrypted, google_email, scopes_granted")
                .eq("user_id", creator_id)
                .eq("provider", "google")
                .execute()
            )

            if host_token_result.data:
                host_token = host_token_result.data[0]
                host_email = host_token.get("google_email", "")
                scopes = host_token.get("scopes_granted") or []

                # Only proceed if the host granted calendar.events scope
                has_events_scope = any(
                    "calendar.events" in s for s in scopes
                )

                if host_email and has_events_scope:
                    invitee_emails = [
                        u["email"] for u in invitee_users if u.get("email")
                    ]
                    if invitee_emails:
                        send_session_calendar_invites(
                            session_title=payload.title,
                            session_description=payload.description,
                            session_start=payload.starts_at,
                            session_end=payload.ends_at,
                            host_token=host_token,
                            host_email=host_email,
                            invitee_emails=invitee_emails,
                            client_id=google_client_id,
                            client_secret=google_client_secret,
                            location=payload.location_name,
                            add_google_meet=payload.add_google_meet,
                        )
                else:
                    logger.info(
                        "Skipping GCal invite — host %s missing events scope or email",
                        creator_id,
                    )
        except Exception as exc:
            # Calendar invite is best-effort — don't fail the request
            logger.warning("Failed to send GCal invites: %s", exc)

    # -- 6. Build and return the response ------------------------------------
    all_users = {u["user_id"]: u for u in invitees_result.data}
    all_users[creator_id] = creator

    member_responses = []
    for m in members_result.data:
        user_info = all_users.get(m["user_id"], {})
        member_responses.append(
            SessionMemberResponse(
                user_id=m["user_id"],
                display_name=user_info.get("display_name", ""),
                email=user_info.get("email", ""),
                status=m["status"],
                invited_at=m.get("invited_at"),
            )
        )

    return PrivateSessionResponse(
        session_id=session["session_id"],
        created_by=session["created_by"],
        session_type=session["session_type"],
        title=session["title"],
        description=session.get("description"),
        study_spot_id=session.get("study_spot_id"),
        location_name=session.get("location_name"),
        starts_at=session["starts_at"],
        ends_at=session["ends_at"],
        created_at=session.get("created_at"),
        members=member_responses,
    )


@router.get(
    "/{session_id}",
    response_model=PrivateSessionResponse,
)
def get_session(session_id: str, supabase: SupabaseDep):
    """Retrieve a session by ID, including its members."""

    # Fetch session
    try:
        session_result = (
            supabase.table("sessions")
            .select("*")
            .eq("session_id", session_id)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch session: {exc}",
        )

    if not session_result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found.",
        )

    session = session_result.data[0]

    # Fetch members
    try:
        members_result = (
            supabase.table("session_members")
            .select("*")
            .eq("session_id", session_id)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch session members: {exc}",
        )

    # Fetch user details for each member
    member_user_ids = [m["user_id"] for m in members_result.data]
    users_map: dict = {}
    if member_user_ids:
        try:
            users_result = (
                supabase.table("users")
                .select("user_id, display_name, email")
                .in_("user_id", member_user_ids)
                .execute()
            )
            users_map = {u["user_id"]: u for u in users_result.data}
        except Exception:
            pass  # Graceful degradation — return members without display info

    member_responses = []
    for m in members_result.data:
        user_info = users_map.get(m["user_id"], {})
        member_responses.append(
            SessionMemberResponse(
                user_id=m["user_id"],
                display_name=user_info.get("display_name", ""),
                email=user_info.get("email", ""),
                status=m["status"],
                invited_at=m.get("invited_at"),
            )
        )

    return PrivateSessionResponse(
        session_id=session["session_id"],
        created_by=session["created_by"],
        session_type=session["session_type"],
        title=session["title"],
        description=session.get("description"),
        study_spot_id=session.get("study_spot_id"),
        location_name=session.get("location_name"),
        starts_at=session["starts_at"],
        ends_at=session["ends_at"],
        created_at=session.get("created_at"),
        members=member_responses,
    )


@router.get(
    "/user/{user_id}",
    response_model=list[SessionListItem],
)
def get_user_sessions(user_id: str, supabase: SupabaseDep):
    """
    Get all sessions a user is part of (either as creator or invitee).
    Returns a lightweight list suitable for a session feed.
    """

    # Find all session_ids the user belongs to
    try:
        membership_result = (
            supabase.table("session_members")
            .select("session_id")
            .eq("user_id", user_id)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch memberships: {exc}",
        )

    session_ids = [m["session_id"] for m in membership_result.data]
    if not session_ids:
        return []

    # Fetch sessions
    try:
        sessions_result = (
            supabase.table("sessions")
            .select("*")
            .in_("session_id", session_ids)
            .order("starts_at", desc=False)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch sessions: {exc}",
        )

    # Count members per session
    try:
        all_members_result = (
            supabase.table("session_members")
            .select("session_id, user_id")
            .in_("session_id", session_ids)
            .execute()
        )
        member_counts: dict[str, int] = {}
        for m in all_members_result.data:
            sid = m["session_id"]
            member_counts[sid] = member_counts.get(sid, 0) + 1
    except Exception:
        member_counts = {}

    return [
        SessionListItem(
            session_id=s["session_id"],
            title=s.get("title", "Untitled Session"),
            session_type=s["session_type"],
            starts_at=s["starts_at"],
            ends_at=s["ends_at"],
            created_at=s.get("created_at"),
            member_count=member_counts.get(s["session_id"], 0),
        )
        for s in sessions_result.data
    ]


@router.patch(
    "/{session_id}/respond",
    response_model=InviteRespondResponse,
)
def respond_to_invite(
    session_id: str,
    payload: InviteRespond,
    supabase: SupabaseDep,
):
    """
    Accept or decline a session invitation.

    The user must be an existing member of the session with a 'pending' status.
    """

    user_id = payload.user_id

    # -- 1. Verify the membership row exists ---------------------------------
    try:
        member_result = (
            supabase.table("session_members")
            .select("*")
            .eq("session_id", session_id)
            .eq("user_id", user_id)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to look up invitation: {exc}",
        )

    if not member_result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No invitation found for this user in the given session.",
        )

    current_status = member_result.data[0]["status"]

    # -- 2. Prevent re-responding to an already resolved invite ---------------
    if current_status != "pending":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Invitation has already been {current_status}.",
        )

    # -- 3. Update the row ----------------------------------------------------
    now = datetime.now(timezone.utc).isoformat()
    try:
        update_result = (
            supabase.table("session_members")
            .update({"status": payload.action.value, "responded_at": now})
            .eq("session_id", session_id)
            .eq("user_id", user_id)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update invitation: {exc}",
        )

    updated = update_result.data[0]

    return InviteRespondResponse(
        session_id=updated["session_id"],
        user_id=updated["user_id"],
        status=updated["status"],
        responded_at=updated.get("responded_at"),
    )
