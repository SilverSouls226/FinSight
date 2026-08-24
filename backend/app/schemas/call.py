"""
app/schemas/call.py

Pydantic schemas for call events and results.
Matches the frozen contract call event shape exactly.
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
    """
    call_id: str
    seq: int = Field(..., description="Monotonically increasing per call — use for ?after_seq= polling")
    type: EventType
    timestamp: datetime

    # Optional fields — presence depends on event type
    status: Optional[str] = None
    # Present on STATUS events: INITIATED | IN_PROGRESS | COMPLETED | FAILED

    speaker: Optional[str] = None
    # Present on TRANSCRIPT events: SCAMMER | VICTIM

    text: Optional[str] = None
    # Present on TRANSCRIPT and ALERT events

    risk_score: Optional[int] = Field(None, ge=0, le=100)
    risk_level: Optional[RiskLevel] = None
    # Present on RISK_UPDATE events

    model_config = {
        "from_attributes": True,
        "json_schema_extra": {
            "example": {
                "call_id": "CA1234567890abcdef",
                "seq": 3,
                "type": "TRANSCRIPT",
                "timestamp": "2026-08-24T09:14:10Z",
                "speaker": "SCAMMER",
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
    """
    call_id: Optional[str] = None

    model_config = {"json_schema_extra": {
        "examples": [
            {"call_id": "CA1234567890abcdef"},
            {"call_id": None},
        ]
    }}
