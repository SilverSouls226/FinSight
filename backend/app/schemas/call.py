"""
app/schemas/call.py

Pydantic schemas for call events and results.
Matches Backend Contract v1.0 §6.2 exactly.
"""
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field

from app.schemas.common import EventType, RiskLevel


# ── Single event (returned in the polling list) ───────────────────────────────

class CallEventOut(BaseModel):
    """
    Represents one event in the call event stream.
    Clients poll GET /api/calls/{call_id}/events?after_seq=N
    and receive a list of these objects with seq > N.

    Per contract §6.2, optional fields are type-specific:
      STATUS events:     status populated (RINGING | IN_PROGRESS | ENDED)
      TRANSCRIPT events: speaker (CALLER | USER) and text populated
      RISK_UPDATE events: risk_score and risk_level populated
      ALERT events:      text, risk_score, risk_level populated
    """
    call_id: str
    seq: int = Field(..., description="Monotonically increasing per call, starts at 1. Use as ?after_seq= cursor.")
    type: EventType
    timestamp: datetime

    # STATUS events — RINGING | IN_PROGRESS | ENDED
    status: Optional[str] = None

    # TRANSCRIPT events — CALLER | USER  (contract §6.2)
    speaker: Optional[str] = None

    # TRANSCRIPT and ALERT events
    text: Optional[str] = None

    # RISK_UPDATE and ALERT events
    risk_score: Optional[int] = Field(None, ge=0, le=100)
    risk_level: Optional[RiskLevel] = None

    model_config = {
        "from_attributes": True,
        "json_schema_extra": {
            "example": {
                "call_id": "call_7f21aa",
                "seq": 3,
                "type": "TRANSCRIPT",
                "timestamp": "2026-08-24T09:14:10Z",
                "speaker": "CALLER",
                "text": "Please tell me the OTP you received.",
            }
        },
    }


# ── Polling response wrapper ──────────────────────────────────────────────────

class CallEventsResponse(BaseModel):
    call_id: str
    events: list[CallEventOut]


# ── Active call ───────────────────────────────────────────────────────────────

class ActiveCallResponse(BaseModel):
    """
    Returned by GET /api/calls/active.
    call_id is null when there is no active call.
    Per contract §6.4.
    """
    call_id: Optional[str] = None

    model_config = {"json_schema_extra": {
        "examples": [
            {"call_id": "call_7f21aa"},
            {"call_id": None},
        ]
    }}
