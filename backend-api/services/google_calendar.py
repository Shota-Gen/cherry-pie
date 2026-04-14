"""
Google Calendar FreeBusy service.

Handles:
  - Refreshing Google OAuth access tokens from stored refresh tokens
  - Querying the Google Calendar FreeBusy API for multiple users
  - Returning structured busy-block data for the LLM scheduler
"""

import logging
from datetime import datetime
from dataclasses import dataclass, field

from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

logger = logging.getLogger(__name__)

# The scope required for FreeBusy queries
FREEBUSY_SCOPE = "https://www.googleapis.com/auth/calendar.freebusy"

# Google OAuth endpoints (used when refreshing tokens)
GOOGLE_TOKEN_URI = "https://oauth2.googleapis.com/token"


@dataclass
class BusyBlock:
    """A single busy interval on a user's calendar."""
    start: datetime
    end: datetime


@dataclass
class ParticipantAvailability:
    """FreeBusy result for one participant."""
    user_id: str
    email: str
    busy_blocks: list[BusyBlock] = field(default_factory=list)
    error: str | None = None  # Set if we couldn't fetch this user's calendar


def _build_credentials(
    refresh_token: str,
    client_id: str,
    client_secret: str,
    access_token: str = "",
) -> Credentials:
    """Build a Google Credentials object from a refresh token or access token."""
    return Credentials(
        token=access_token or None,  # Use access token directly if available
        refresh_token=refresh_token or None,
        token_uri=GOOGLE_TOKEN_URI,
        client_id=client_id,
        client_secret=client_secret,
        scopes=[FREEBUSY_SCOPE],
    )


def query_freebusy(
    emails: list[str],
    time_min: datetime,
    time_max: datetime,
    refresh_token: str,
    client_id: str,
    client_secret: str,
    access_token: str = "",
) -> dict[str, list[BusyBlock]]:
    """
    Query the Google Calendar FreeBusy API for a list of email addresses.

    We only need ONE valid credential to perform the FreeBusy query for
    everyone (the API checks each calendar's sharing settings).
    For calendar.freebusy scope, Google allows querying other users'
    free/busy if their calendar is set to share free/busy info.

    Returns a dict mapping email → list of BusyBlock.
    """
    credentials = _build_credentials(refresh_token, client_id, client_secret, access_token)

    service = build("calendar", "v3", credentials=credentials)

    body = {
        "timeMin": time_min.isoformat(),
        "timeMax": time_max.isoformat(),
        "timeZone": "UTC",
        "items": [{"id": email} for email in emails],
    }

    try:
        result = service.freebusy().query(body=body).execute()
    except HttpError as exc:
        logger.error("FreeBusy API error: %s", exc)
        raise

    calendars = result.get("calendars", {})
    output: dict[str, list[BusyBlock]] = {}

    for email in emails:
        cal_data = calendars.get(email, {})
        errors = cal_data.get("errors", [])
        if errors:
            logger.warning("FreeBusy errors for %s: %s", email, errors)
            output[email] = []
            continue

        busy_list = cal_data.get("busy", [])
        output[email] = [
            BusyBlock(
                start=datetime.fromisoformat(b["start"]),
                end=datetime.fromisoformat(b["end"]),
            )
            for b in busy_list
        ]

    return output


def fetch_participant_availability(
    participants: list[dict],
    time_min: datetime,
    time_max: datetime,
    host_token: dict,
    client_id: str,
    client_secret: str,
) -> list[ParticipantAvailability]:
    """
    High-level function: given a list of participant dicts (with user_id, email,
    and optionally their own token), query FreeBusy for all of them using the
    host's token.

    Parameters
    ----------
    participants : list[dict]
        Each dict has: user_id, email (Google email for calendar lookup)
    time_min : datetime
        Start of the search window
    time_max : datetime
        End of the search window
    host_token : dict
        The host user's stored token row (refresh_token_encrypted, etc.)
    client_id : str
        Google OAuth client ID
    client_secret : str
        Google OAuth client secret

    Returns
    -------
    list[ParticipantAvailability]
    """
    emails = [p["email"] for p in participants]
    email_to_user = {p["email"]: p["user_id"] for p in participants}

    try:
        busy_map = query_freebusy(
            emails=emails,
            time_min=time_min,
            time_max=time_max,
            refresh_token=host_token.get("refresh_token_encrypted", ""),
            client_id=client_id,
            client_secret=client_secret,
            access_token=host_token.get("access_token_encrypted", ""),
        )
    except Exception as exc:
        logger.error("Failed to query FreeBusy: %s", exc)
        # Return all participants with error status
        return [
            ParticipantAvailability(
                user_id=p["user_id"],
                email=p["email"],
                error=f"FreeBusy query failed: {exc}",
            )
            for p in participants
        ]

    results = []
    for email, blocks in busy_map.items():
        user_id = email_to_user.get(email, "unknown")
        results.append(
            ParticipantAvailability(
                user_id=user_id,
                email=email,
                busy_blocks=blocks,
            )
        )

    # Add any participants whose email wasn't in the response
    seen_emails = set(busy_map.keys())
    for p in participants:
        if p["email"] not in seen_emails:
            results.append(
                ParticipantAvailability(
                    user_id=p["user_id"],
                    email=p["email"],
                    error="No calendar data returned",
                )
            )

    return results
