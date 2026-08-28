"""
app/api/v1/devtools.py

Devtools-only API endpoints for call simulation and testing.
Gated behind APP_ENV == "development" configuration.
"""
import uuid
from typing import Optional

from fastapi import APIRouter, BackgroundTasks, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.db.base import SessionLocal
from app.devtools.call_simulator import simulate_bank_otp_scam

router = APIRouter(prefix="/devtools", tags=["Devtools (Simulator)"])


class SimulationRequest(BaseModel):
    call_id: Optional[str] = Field(
        None,
        description=(
            "Optional Call ID. If omitted, a unique ID with the prefix 'call_sim_' will be generated. "
            "Twilio-like format (e.g. call_sim_9f2a41b8)."
        ),
    )
    device_id: str = Field(
        ...,
        description="The device identity (X-Device-Id) to scope the final ThreatResult to.",
    )
    delay_seconds: float = Field(
        0.0,
        ge=0.0,
        le=10.0,
        description=(
            "Delay in seconds between successive simulated events. "
            "If 0.0, the simulation runs synchronously in the request thread. "
            "If > 0.0, it runs asynchronously as a background task."
        ),
    )


class SimulationResponse(BaseModel):
    call_id: str
    status: str


@router.post(
    "/simulate",
    response_model=SimulationResponse,
    summary="Trigger a simulated scam call sequence",
    description=(
        "Simulates a full scam call session from start to finish. "
        "Can run synchronously (immediate database population) or asynchronously "
        "(real-time delayed progression for testing live UI polling)."
    ),
)
async def trigger_simulation(
    body: SimulationRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
) -> SimulationResponse:
    call_id = body.call_id or f"call_sim_{uuid.uuid4().hex[:8]}"

    # Run the simulation
    if body.delay_seconds > 0.0:
        background_tasks.add_task(
            simulate_bank_otp_scam,
            SessionLocal,
            call_id,
            body.device_id,
            body.delay_seconds,
        )
        return SimulationResponse(call_id=call_id, status="started")
    else:
        # Run synchronously immediately
        await simulate_bank_otp_scam(
            db_session_factory=SessionLocal,
            call_id=call_id,
            device_id=body.device_id,
            delay_seconds=0.0,
        )
        return SimulationResponse(call_id=call_id, status="completed")
