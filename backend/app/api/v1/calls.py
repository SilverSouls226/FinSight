"""
app/api/v1/calls.py

GET /api/calls/active                          — active call_id or null
GET /api/calls/{call_id}/events?after_seq=N    — event polling
GET /api/calls/{call_id}/result                — final ThreatResult

NOTE: Route order matters in FastAPI.
/calls/active MUST be registered before /calls/{call_id} so that "active"
is not captured as a call_id path parameter.
"""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.schemas.call import ActiveCallResponse, CallEventsResponse
from app.schemas.common import ErrorResponse
from app.schemas.threat import ThreatResult
from app.services.call import call_service

router = APIRouter()


@router.get(
    "/calls/active",
    response_model=ActiveCallResponse,
    summary="Get the currently active call",
    description=(
        "Returns the call_id of the call that is currently INITIATED or IN_PROGRESS. "
        "Returns {call_id: null} when no call is active."
    ),
)
def get_active_call(db: Session = Depends(get_db)) -> ActiveCallResponse:
    return call_service.get_active(db=db)


@router.get(
    "/calls/{call_id}/events",
    response_model=CallEventsResponse,
    responses={404: {"model": ErrorResponse, "description": "Call not found"}},
    summary="Poll call events",
    description=(
        "Returns all events for the given call with seq > after_seq. "
        "Client should start with after_seq=0 and use the highest seq received "
        "as the next after_seq value."
    ),
)
def get_call_events(
    call_id: str,
    after_seq: int = Query(default=0, ge=0, description="Return events with seq greater than this value"),
    db: Session = Depends(get_db),
) -> CallEventsResponse:
    return call_service.get_events(db=db, call_id=call_id, after_seq=after_seq)


@router.get(
    "/calls/{call_id}/result",
    response_model=ThreatResult,
    responses={404: {"model": ErrorResponse, "description": "Call not found or result not yet available"}},
    summary="Get the final threat result for a completed call",
)
def get_call_result(
    call_id: str,
    db: Session = Depends(get_db),
) -> ThreatResult:
    return call_service.get_result(db=db, call_id=call_id)
