"""
app/schemas/common.py

Shared enums and error envelope used across all API schemas.
These values match the frozen Backend Contract v1.0 exactly.
Do NOT add, remove, or rename values without a contract update.
"""
from enum import Enum

from pydantic import BaseModel


# ── Source ────────────────────────────────────────────────────────────────────

class Source(str, Enum):
    CALL = "CALL"
    SMS = "SMS"
    QR = "QR"
    LINK = "LINK"


# ── Risk level ────────────────────────────────────────────────────────────────

class RiskLevel(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"
    # NOTE: UNKNOWN is NOT emitted by the backend.
    # It is a client-side forward-compatibility concept only.


# ── Call event type ───────────────────────────────────────────────────────────

class EventType(str, Enum):
    STATUS = "STATUS"
    TRANSCRIPT = "TRANSCRIPT"
    RISK_UPDATE = "RISK_UPDATE"
    ALERT = "ALERT"


# ── Error envelope ────────────────────────────────────────────────────────────

class ErrorDetail(BaseModel):
    code: str
    message: str


class ErrorResponse(BaseModel):
    error: ErrorDetail

    model_config = {"json_schema_extra": {
        "example": {
            "error": {
                "code": "INVALID_INPUT",
                "message": "content field was empty",
            }
        }
    }}
