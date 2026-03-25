"""
Email service — send session invite emails.

NOTE: This module is intentionally stubbed for now.
When ready to send real emails, swap in your preferred provider
(e.g. SendGrid, AWS SES, Resend, or Supabase Edge Functions).
"""

import logging
from datetime import datetime

logger = logging.getLogger(__name__)


def send_session_invite_emails(
    session_title: str,
    session_start: datetime,
    session_end: datetime,
    creator_name: str,
    invitees: list[dict],
) -> None:
    """
    Send invitation emails to each invitee for a study session.

    Parameters
    ----------
    session_title : str
        Title of the study session.
    session_start : datetime
        When the session starts.
    session_end : datetime
        When the session ends.
    creator_name : str
        Display name of the user who created the session.
    invitees : list[dict]
        Each dict must have 'email' and 'display_name' keys.

    Raises
    ------
    Exception
        If email sending fails — callers should catch this and
        treat it as non-critical.
    """
    for invitee in invitees:
        email = invitee.get("email", "")
        name = invitee.get("display_name", "Friend")

        # Format times for readability
        start_str = session_start.strftime("%B %d, %Y at %I:%M %p")
        end_str = session_end.strftime("%I:%M %p")

        subject = f"📚 You're invited to study: {session_title}"
        body = (
            f"Hi {name},\n\n"
            f"{creator_name} has invited you to a study session!\n\n"
            f"  📝 Session:  {session_title}\n"
            f"  🕐 When:     {start_str} – {end_str}\n\n"
            f"Open StudyConnect to accept or decline the invite.\n\n"
            f"Happy studying! 🎓\n"
            f"— The StudyConnect Team"
        )

        # -----------------------------------------------------------------
        # TODO: Replace this stub with a real email provider.
        #
        # Example with SendGrid:
        #   from sendgrid import SendGridAPIClient
        #   from sendgrid.helpers.mail import Mail
        #   message = Mail(
        #       from_email="noreply@studyconnect.app",
        #       to_emails=email,
        #       subject=subject,
        #       plain_text_content=body,
        #   )
        #   sg = SendGridAPIClient(os.environ.get("SENDGRID_API_KEY"))
        #   sg.send(message)
        # -----------------------------------------------------------------

        print(
            f"📧 [STUB] Would send invite email to {name} <{email}> — Subject: {subject}",
            flush=True
        )
