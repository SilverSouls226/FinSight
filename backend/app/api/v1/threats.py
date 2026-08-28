"""
app/api/v1/threats.py

GET /api/threats          — device-scoped threat history (newest first)
GET /api/threats/{id}     — single threat by id
"""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_device_id
from app.schemas.common import ErrorResponse
from app.schemas.threat import ThreatHistoryResponse, ThreatResult
from app.services.threat import threat_service

router = APIRouter()


@router.get(
    "/threats",
    response_model=ThreatHistoryResponse,
    summary="Get threat history for this device",
    description=(
        "Returns the most recent threat results for the device identified by X-Device-Id. "
        "Results are ordered newest-first. Default limit is 50."
    ),
)
def get_threats(
    limit: int = Query(default=50, ge=1, le=200, description="Maximum results to return"),
    db: Session = Depends(get_db),
    device_id: str = Depends(get_device_id),
) -> ThreatHistoryResponse:
    rows = threat_service.get_history(db=db, device_id=device_id, limit=limit)
    threats = [threat_service.to_schema(r) for r in rows]
    return ThreatHistoryResponse(threats=threats, total=len(threats))


@router.get(
    "/threats/{threat_id}",
    response_model=ThreatResult,
    responses={404: {"model": ErrorResponse, "description": "Threat not found"}},
    summary="Get a single threat result by ID",
)
def get_threat(
    threat_id: str,
    db: Session = Depends(get_db),
    # Note: no device_id scoping here — ID lookup is global (needed for call results)
) -> ThreatResult:
    row = threat_service.get_by_id(db=db, threat_id=threat_id)
    return threat_service.to_schema(row)
