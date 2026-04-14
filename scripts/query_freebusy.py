#!/usr/bin/env python3
"""
Query Google Calendar FreeBusy API for a specific user.

Usage:
    python3 scripts/query_freebusy.py

On first run, this will open a browser for OAuth consent.
The token is cached in scripts/token_cache.json for subsequent runs.
"""

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

# pip install google-auth google-auth-oauthlib google-api-python-client
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build

# ---------- Configuration ----------

# Target user's email (Shota Gen)
TARGET_EMAIL = "sgen@umich.edu"

# Date to query: April 16, 2026
QUERY_DATE = "2026-04-16"

# Google OAuth credentials from environment variables
CLIENT_ID = os.environ.get("GOOGLE_CLIENT_ID", "")
CLIENT_SECRET = os.environ.get("GOOGLE_CLIENT_SECRET", "")

if not CLIENT_ID or not CLIENT_SECRET:
    sys.exit("Error: GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET environment variables must be set.")

SCOPES = ["https://www.googleapis.com/auth/calendar.freebusy"]
TOKEN_CACHE = Path(__file__).parent / "token_cache.json"


def get_credentials() -> Credentials:
    """Get valid credentials, using cached token or interactive OAuth flow."""
    creds = None

    # Load cached token
    if TOKEN_CACHE.exists():
        with open(TOKEN_CACHE) as f:
            token_data = json.load(f)
        creds = Credentials(
            token=token_data.get("token"),
            refresh_token=token_data.get("refresh_token"),
            token_uri="https://oauth2.googleapis.com/token",
            client_id=CLIENT_ID,
            client_secret=CLIENT_SECRET,
            scopes=SCOPES,
        )

    # Refresh or re-authenticate
    if creds and creds.expired and creds.refresh_token:
        print("Refreshing expired token...")
        creds.refresh(Request())
    elif not creds or not creds.valid:
        print("No valid token found. Opening browser for OAuth consent...")
        print("(Make sure to sign in with an account that can see Shota Gen's calendar)")
        flow = InstalledAppFlow.from_client_config(
            {
                "installed": {
                    "client_id": CLIENT_ID,
                    "client_secret": CLIENT_SECRET,
                    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                    "token_uri": "https://oauth2.googleapis.com/token",
                    "redirect_uris": ["http://localhost"],
                }
            },
            scopes=SCOPES,
        )
        creds = flow.run_local_server(port=0)

    # Save token for next time
    with open(TOKEN_CACHE, "w") as f:
        json.dump(
            {
                "token": creds.token,
                "refresh_token": creds.refresh_token,
            },
            f,
        )

    return creds


def query_freebusy(creds: Credentials, email: str, date_str: str):
    """Query FreeBusy API and display results."""
    service = build("calendar", "v3", credentials=creds)

    # Build time range for the full day (midnight to midnight ET)
    # Using America/New_York timezone
    time_min = f"{date_str}T00:00:00-04:00"
    time_max = f"{date_str}T23:59:59-04:00"

    body = {
        "timeMin": time_min,
        "timeMax": time_max,
        "timeZone": "America/New_York",
        "items": [{"id": email}],
    }

    print(f"\n{'='*60}")
    print(f"FreeBusy Query for: {email}")
    print(f"Date: {date_str}")
    print(f"Time Range: {time_min} → {time_max}")
    print(f"{'='*60}\n")

    result = service.freebusy().query(body=body).execute()

    calendars = result.get("calendars", {})
    cal_data = calendars.get(email, {})

    # Check for errors
    errors = cal_data.get("errors", [])
    if errors:
        print(f"⚠️  Errors returned for {email}:")
        for err in errors:
            print(f"   - Domain: {err.get('domain')}, Reason: {err.get('reason')}")
        return

    # Display busy blocks
    busy_blocks = cal_data.get("busy", [])

    if not busy_blocks:
        print(f"✅ {email} has NO busy times on {date_str}!")
        print("   They are free all day.")
    else:
        print(f"📅 {email} has {len(busy_blocks)} busy block(s) on {date_str}:\n")
        for i, block in enumerate(busy_blocks, 1):
            start = datetime.fromisoformat(block["start"])
            end = datetime.fromisoformat(block["end"])

            # Convert to ET for display
            start_et = start.strftime("%I:%M %p")
            end_et = end.strftime("%I:%M %p")
            duration = end - start
            hours, remainder = divmod(int(duration.total_seconds()), 3600)
            minutes = remainder // 60

            duration_str = ""
            if hours:
                duration_str += f"{hours}h "
            if minutes:
                duration_str += f"{minutes}m"

            print(f"   {i}. {start_et} – {end_et}  ({duration_str.strip()})")
            print(f"      Raw: {block['start']} → {block['end']}")

    print(f"\n{'='*60}")
    print("Raw API response:")
    print(json.dumps(result, indent=2))


def main():
    creds = get_credentials()
    query_freebusy(creds, TARGET_EMAIL, QUERY_DATE)


if __name__ == "__main__":
    main()
