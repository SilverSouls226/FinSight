"""
app/schemas/threat.py

Pydantic schemas for threat analysis.
ThreatResult is the canonical response shape per the frozen contract.
AnalyzeRequest is the POST /api/analyze body.
"""
from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field, field_validator

from app.schemas.common import RiskLevel, Source


# ── Request ───────────────────────────────────────────────────────────────────

class AnalyzeRequest(BaseModel):
    source: Source
    content: str = Field(..., min_length=1, description="Content to analyze (SMS text, URL, QR payload, etc.)")
    metadata: dict[str, Any] = Field(default_factory=dict)

    model_config = {"json_schema_extra": {
        "example": {
            "source": "SMS",
            "content": "Your KYC has expired. Click here to verify: http://secure-bank-verify.xyz",
            "metadata": {},
        }
    }}

    @field_validator("content")
    @classmethod
    def content_must_not_be_blank(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("content field was empty")
        return v


# ── Response ──────────────────────────────────────────────────────────────────

class ThreatResult(BaseModel):
    """
    Canonical threat result shape.
    Matches the frozen contract ThreatResult exactly.
    Produced by AnalysisService and returned by POST /api/analyze.
    Also returned by GET /api/calls/{call_id}/result.
    """
    id: str = Field(..., description="Unique threat ID — format: thr_{source}_{uuid8}")
    source: Source
    risk_score: int = Field(..., ge=0, le=100)
    risk_level: RiskLevel
    threat_type: str
    indicators: list[str]
    recommendation: str
    timestamp: datetime
    analyzed_content: str

    model_config = {
        "from_attributes": True,
        "json_schema_extra": {
            "example": {
                "id": "thr_sms_9f2a41b8",
                "source": "SMS",
                "risk_score": 97,
                "risk_level": "CRITICAL",
                "threat_type": "Banking Scam",
                "indicators": ["Bank impersonation", "OTP request", "Urgency"],
                "recommendation": "Do not share your OTP.",
                "timestamp": "2026-08-24T09:14:22Z",
                "analyzed_content": "Your KYC has expired...",
            }
        },
    }


# ── History list wrapper ──────────────────────────────────────────────────────

class ThreatHistoryResponse(BaseModel):
    threats: list[ThreatResult]
    total: int
