from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

class TranscriptEvent(BaseModel):
    call_id: str
    speaker: str
    text: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    is_final: bool

class ThreatResult(BaseModel):
    source: str = "CALL"
    risk_score: int = Field(ge=0, le=100)
    risk_level: str
    threat_type: str
    indicators: List[str]
    recommendation: str
    call_id: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
