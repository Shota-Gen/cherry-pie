"""
Gemini-powered Smart Scheduler service.

Uses Gemini 3.0 Flash via the Google GenAI SDK with function calling to
analyze participant availability and suggest optimal study session times.

Flow:
  1. Convert FreeBusy data into a structured prompt
  2. Define a `suggest_study_slots` function tool for the LLM
  3. Call Gemini with the availability context
  4. Parse the function call response into typed slot suggestions
"""

import json
import logging
import os
from datetime import datetime
from dataclasses import dataclass, field

from google import genai
from google.genai import types

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Data models
# ---------------------------------------------------------------------------


@dataclass
class SuggestedSlot:
    """A single suggested time slot from the LLM."""
    start: str  # ISO 8601
    end: str    # ISO 8601
    available_user_ids: list[str] = field(default_factory=list)
    busy_user_ids: list[str] = field(default_factory=list)
    score: float = 0.0  # 0–1, how good this slot is
    reason: str = ""    # LLM's explanation


# ---------------------------------------------------------------------------
# Tool definition for Gemini function calling
# ---------------------------------------------------------------------------

SUGGEST_SLOTS_TOOL = types.Tool(
    function_declarations=[
        types.FunctionDeclaration(
            name="suggest_study_slots",
            description=(
                "Analyze participant availability and suggest the best time slots "
                "for a group study session. Return slots ranked by how many "
                "participants are free, preferring times when ALL participants "
                "are available. Each slot must fit within the given search window "
                "and match the requested duration."
            ),
            parameters=types.Schema(
                type=types.Type.OBJECT,
                properties={
                    "slots": types.Schema(
                        type=types.Type.ARRAY,
                        description="List of suggested time slots, best first",
                        items=types.Schema(
                            type=types.Type.OBJECT,
                            properties={
                                "start": types.Schema(
                                    type=types.Type.STRING,
                                    description="Slot start time in ISO 8601 format (e.g. 2026-04-07T14:00:00Z)",
                                ),
                                "end": types.Schema(
                                    type=types.Type.STRING,
                                    description="Slot end time in ISO 8601 format",
                                ),
                                "available_user_ids": types.Schema(
                                    type=types.Type.ARRAY,
                                    description="User IDs of participants who are FREE during this slot",
                                    items=types.Schema(type=types.Type.STRING),
                                ),
                                "busy_user_ids": types.Schema(
                                    type=types.Type.ARRAY,
                                    description="User IDs of participants who are BUSY during this slot",
                                    items=types.Schema(type=types.Type.STRING),
                                ),
                                "score": types.Schema(
                                    type=types.Type.NUMBER,
                                    description="Quality score from 0.0 to 1.0 (1.0 = everyone free, well-timed)",
                                ),
                                "reason": types.Schema(
                                    type=types.Type.STRING,
                                    description="Brief human-readable explanation of why this slot is good",
                                ),
                            },
                            required=["start", "end", "available_user_ids", "busy_user_ids", "score", "reason"],
                        ),
                    ),
                },
                required=["slots"],
            ),
        )
    ]
)


# ---------------------------------------------------------------------------
# Prompt construction
# ---------------------------------------------------------------------------


def _build_availability_context(
    participant_data: list[dict],
    window_start: datetime,
    window_end: datetime,
    duration_minutes: int,
) -> str:
    """
    Build a context string describing each participant's busy blocks.

    participant_data format:
    [
        {
            "user_id": "abc-123",
            "display_name": "Alice",
            "email": "alice@umich.edu",
            "busy_blocks": [{"start": "...", "end": "..."}],
            "error": null | "reason"
        }
    ]
    """
    lines = [
        f"## Study Session Scheduling Request",
        f"",
        f"**Search Window:** {window_start.isoformat()} to {window_end.isoformat()}",
        f"**Required Duration:** {duration_minutes} minutes",
        f"**Number of Participants:** {len(participant_data)}",
        f"",
        f"## Participant Availability",
        f"",
    ]

    for p in participant_data:
        name = p.get("display_name", "Unknown")
        uid = p["user_id"]
        error = p.get("error")

        lines.append(f"### {name} (ID: {uid})")

        if error:
            lines.append(f"  ⚠️ Calendar data unavailable: {error}")
            lines.append(f"  → Treat as AVAILABLE (benefit of the doubt)")
        elif not p.get("busy_blocks"):
            lines.append(f"  ✅ Completely free during the entire window")
        else:
            lines.append(f"  Busy blocks:")
            for block in p["busy_blocks"]:
                lines.append(f"    - {block['start']} → {block['end']}")

        lines.append("")

    lines.extend([
        "## Instructions",
        "1. Find time slots of exactly {duration_minutes} minutes where the MOST participants are free.",
        "2. Prefer slots where ALL participants are free (score = 1.0).",
        "3. If no slot has everyone free, suggest slots with the most people available.",
        "4. Suggest up to 5 slots, ranked best-first.",
        "5. Prefer reasonable hours (9 AM – 10 PM local time) when possible.",
        "6. Avoid overlapping suggestions — each slot should be a distinct option.",
        "7. Call the suggest_study_slots function with your results.",
    ])

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main scheduling function
# ---------------------------------------------------------------------------


def suggest_times(
    participant_data: list[dict],
    window_start: datetime,
    window_end: datetime,
    duration_minutes: int,
    api_key: str | None = None,
) -> list[SuggestedSlot]:
    """
    Use Gemini to analyze availability and suggest optimal study times.

    Parameters
    ----------
    participant_data : list[dict]
        Each dict contains: user_id, display_name, email, busy_blocks, error
    window_start : datetime
        Start of the search window
    window_end : datetime
        End of the search window
    duration_minutes : int
        Desired session length in minutes
    api_key : str, optional
        Gemini API key. Falls back to GEMINI_API_KEY env var.

    Returns
    -------
    list[SuggestedSlot]
        Up to 5 suggested time slots, ranked best-first.
    """
    key = api_key or os.getenv("GEMINI_API_KEY")
    if not key:
        raise ValueError("GEMINI_API_KEY is required")

    client = genai.Client(api_key=key)

    context = _build_availability_context(
        participant_data, window_start, window_end, duration_minutes
    )

    logger.info("Sending scheduling request to Gemini (participants=%d, window=%s→%s)",
                len(participant_data), window_start, window_end)

    # Try Gemini 3.0 Flash first, fall back to 3.1 Flash Lite
    models_to_try = ["gemini-3.1-flash-lite-preview"]

    gen_config = types.GenerateContentConfig(
        tools=[SUGGEST_SLOTS_TOOL],
        temperature=0.2,  # Low temp for deterministic scheduling
        tool_config=types.ToolConfig(
            function_calling_config=types.FunctionCallingConfig(
                mode=types.FunctionCallingConfigMode.ANY,
            )
        ),
    )

    response = None
    for model_name in models_to_try:
        try:
            logger.info("Trying model: %s", model_name)
            response = client.models.generate_content(
                model=model_name,
                contents=context,
                config=gen_config,
            )
            logger.info("Success with model: %s", model_name)
            break
        except Exception as exc:
            logger.warning("Model %s failed: %s — trying next", model_name, exc)
            continue

    if response is None:
        raise RuntimeError("All Gemini models failed")

    # Extract the function call from the response
    slots = _parse_response(response)

    logger.info("Gemini suggested %d time slots", len(slots))
    return slots


def _parse_response(response) -> list[SuggestedSlot]:
    """Extract SuggestedSlot objects from Gemini's function call response."""
    slots = []

    for candidate in response.candidates:
        for part in candidate.content.parts:
            if part.function_call and part.function_call.name == "suggest_study_slots":
                args = part.function_call.args
                raw_slots = args.get("slots", [])

                for raw in raw_slots:
                    slots.append(SuggestedSlot(
                        start=raw.get("start", ""),
                        end=raw.get("end", ""),
                        available_user_ids=raw.get("available_user_ids", []),
                        busy_user_ids=raw.get("busy_user_ids", []),
                        score=float(raw.get("score", 0.0)),
                        reason=raw.get("reason", ""),
                    ))

    # Sort by score descending (best slots first)
    slots.sort(key=lambda s: s.score, reverse=True)
    return slots


# ---------------------------------------------------------------------------
# Fallback: deterministic scheduling without LLM
# ---------------------------------------------------------------------------


# def suggest_times_fallback(
#     participant_data: list[dict],
#     window_start: datetime,
#     window_end: datetime,
#     duration_minutes: int,
# ) -> list[SuggestedSlot]:
#     """
#     Deterministic fallback scheduler for when the LLM is unavailable.
    
#     Slides a window across the search range and scores each position
#     by how many participants are free.
#     """
#     from datetime import timedelta

#     duration = timedelta(minutes=duration_minutes)
#     step = timedelta(minutes=30)  # 30-min granularity

#     # Collect all busy blocks per user_id
#     busy_map: dict[str, list[tuple[datetime, datetime]]] = {}
#     all_user_ids = []
#     for p in participant_data:
#         uid = p["user_id"]
#         all_user_ids.append(uid)
#         blocks = []
#         for b in p.get("busy_blocks", []):
#             try:
#                 bs = datetime.fromisoformat(b["start"])
#                 be = datetime.fromisoformat(b["end"])
#                 # Strip tzinfo to avoid naive/aware comparison errors
#                 bs = bs.replace(tzinfo=None)
#                 be = be.replace(tzinfo=None)
#                 blocks.append((bs, be))
#             except (ValueError, KeyError):
#                 continue
#         busy_map[uid] = blocks

#     def is_free(user_id: str, slot_start: datetime, slot_end: datetime) -> bool:
#         for bs, be in busy_map.get(user_id, []):
#             if slot_start < be and slot_end > bs:  # overlap check
#                 return False
#         return True

#     # Normalize window datetimes to naive for comparison
#     ws = window_start.replace(tzinfo=None)
#     we = window_end.replace(tzinfo=None)

#     candidates: list[SuggestedSlot] = []
#     current = ws

#     while current + duration <= we:
#         slot_end = current + duration
#         available = [uid for uid in all_user_ids if is_free(uid, current, slot_end)]
#         busy = [uid for uid in all_user_ids if uid not in available]
#         score = len(available) / max(len(all_user_ids), 1)

#         if score > 0:  # At least one person available
#             candidates.append(SuggestedSlot(
#                 start=current.isoformat(),
#                 end=slot_end.isoformat(),
#                 available_user_ids=available,
#                 busy_user_ids=busy,
#                 score=score,
#                 reason=f"{len(available)}/{len(all_user_ids)} participants available",
#             ))

#         current += step

#     # Sort by score descending, take top 5
#     candidates.sort(key=lambda s: s.score, reverse=True)
#     return candidates[:5]
