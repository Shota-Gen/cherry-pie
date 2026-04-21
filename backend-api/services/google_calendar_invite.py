"""
Google Calendar Event / Invite service.

Creates a Google Calendar event on the host's calendar with attendees,
which causes Google to automatically send calendar invitations to all
attendees from the host's account.

Requires the host to have granted the `calendar.events` scope.
"""

import logging
import uuid
from datetime import datetime

from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

logger = logging.getLogger(__name__)

GOOGLE_TOKEN_URI = "https://oauth2.googleapis.com/token"
EVENTS_SCOPE = "https://www.googleapis.com/auth/calendar.events"


def create_calendar_event(
    summary: str,
    description: str | None,
    start: datetime,
    end: datetime,
    host_email: str,
    attendee_emails: list[str],
    refresh_token: str,
    client_id: str,
    client_secret: str,
    location: str | None = None,
    add_google_meet: bool = False,
) -> dict | None:
    """
    Create a Google Calendar event on the host's primary calendar and
    send invites to all attendees.

    Parameters
    ----------
    summary : str
        Event title.
    description : str | None
        Event description.
    start / end : datetime
        Event start and end times (timezone-aware).
    host_email : str
        The host's Google email (used as organizer).
    attendee_emails : list[str]
        Google/email addresses of invitees.
    refresh_token : str
        Host's Google OAuth refresh token.
    client_id / client_secret : str
        Google OAuth web-client credentials.
    location : str | None
        Optional location / study spot name.

    Returns
    -------
    dict | None
        The created event resource from Google, or None on failure.
    """
    credentials = Credentials(
        token=None,
        refresh_token=refresh_token,
        token_uri=GOOGLE_TOKEN_URI,
        client_id=client_id,
        client_secret=client_secret,
        scopes=[EVENTS_SCOPE],
    )

    service = build("calendar", "v3", credentials=credentials)

    event_body: dict = {
        "summary": summary,
        "start": {
            "dateTime": start.isoformat(),
            "timeZone": "UTC",
        },
        "end": {
            "dateTime": end.isoformat(),
            "timeZone": "UTC",
        },
        "attendees": [{"email": email} for email in attendee_emails],
        "reminders": {
            "useDefault": True,
        },
    }

    if description:
        event_body["description"] = description
    if location:
        event_body["location"] = location
    if add_google_meet:
        event_body["conferenceData"] = {
            "createRequest": {
                "requestId": uuid.uuid4().hex,
                "conferenceSolutionKey": {"type": "hangoutsMeet"},
            }
        }

    try:
        event = (
            service.events()
            .insert(
                calendarId="primary",
                body=event_body,
                sendUpdates="all",  # This triggers GCal invite emails
                conferenceDataVersion=1 if add_google_meet else 0,
            )
            .execute()
        )
        logger.info(
            "Created Google Calendar event '%s' (id=%s) with %d attendees",
            summary,
            event.get("id"),
            len(attendee_emails),
        )
        return event
    except HttpError as exc:
        logger.error("Failed to create Google Calendar event: %s", exc)
        return None
    except Exception as exc:
        logger.error("Unexpected error creating calendar event: %s", exc)
        return None


def send_session_calendar_invites(
    session_title: str,
    session_description: str | None,
    session_start: datetime,
    session_end: datetime,
    host_token: dict,
    host_email: str,
    invitee_emails: list[str],
    client_id: str,
    client_secret: str,
    location: str | None = None,
    add_google_meet: bool = False,
) -> dict | None:
    """
    High-level helper: create a study session event on the host's calendar
    and send Google Calendar invites to all invitees.

    Parameters
    ----------
    host_token : dict
        Row from external_auth_tokens with at least 'refresh_token_encrypted'.
    host_email : str
        The host's Google email.
    invitee_emails : list[str]
        Email addresses of the invited users.

    Returns
    -------
    dict | None
        Created event resource, or None if creation failed.
    """
    refresh_token = host_token.get("refresh_token_encrypted", "")
    if not refresh_token:
        logger.warning("No refresh token for host — skipping calendar invite")
        return None

    return create_calendar_event(
        summary=f"📚 {session_title}",
        description=session_description or "Study session created via StudyConnect",
        start=session_start,
        end=session_end,
        host_email=host_email,
        attendee_emails=invitee_emails,
        refresh_token=refresh_token,
        client_id=client_id,
        client_secret=client_secret,
        location=location,
        add_google_meet=add_google_meet,
    )
