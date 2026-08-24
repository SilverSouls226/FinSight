"""
app/api/v1/analyze.py

POST /api/analyze — Submit content for scam analysis.
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_device_id
from app.schemas.common import ErrorResponse
from app.schemas.threat import AnalyzeRequest, ThreatResult
from app.services.analysis import analysis_service
from app.services.threat import threat_service

router = APIRouter()


@router.post(
    "/analyze",
    response_model=ThreatResult,
    responses={
        422: {"model": ErrorResponse, "description": "Invalid or empty input"},
        502: {"model": ErrorResponse, "description": "Analysis engine failed"},
    },
    summary="Analyze content for scam threats",
    description=(
        "Submit SMS text, a URL, a QR payload, or a link for AI-powered scam analysis. "
        "Returns a ThreatResult with risk score, risk level, indicators, and recommendation. "
        "Analysis failure returns an error — never a fake LOW result."
    ),
)
def analyze(
    body: AnalyzeRequest,
    db: Session = Depends(get_db),
    device_id: str = Depends(get_device_id),
) -> ThreatResult:
    # 1. Run analysis (stub on Day 1 — Skandan's AI replaces this service)
    result = analysis_service.analyze(
        source=body.source,
        content=body.content,
        metadata=body.metadata,
    )

    # 2. Persist to DB under this device's identity
    threat_service.create(db=db, result=result, device_id=device_id)

    return result
