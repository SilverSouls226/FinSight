"""
app/devtools/call_simulator.py

Development-only call simulator for the FinSentinel backend.
Enables simulating a realistic scam call session utilizing established CallService methods.
This file is decoupled from production flows and only executed when triggered explicitly.
"""
import asyncio
import logging
import uuid
from datetime import datetime, timezone
from typing import Callable

from sqlalchemy.orm import Session

from app.schemas.common import RiskLevel, Source
from app.schemas.threat import ThreatResult
from app.services.call import call_service

logger = logging.getLogger(__name__)

# Reusable scenario name
SCENARIO_BANK_OTP_SCAM = "bank_otp_scam"


async def simulate_bank_otp_scam(
    db_session_factory: Callable[[], Session],
    call_id: str,
    device_id: str,
    delay_seconds: float = 0.0,
) -> None:
    """
    Run the simulated bank OTP scam call sequence.
    Utilizes standard CallService methods to modify state and append events.

    Sequence:
      1. CALL CREATED (INITIATED status)
      2. STATUS: RINGING
      3. STATUS: IN_PROGRESS (and Call.status -> IN_PROGRESS)
      4. TRANSCRIPT: "Hello, I'm calling from your bank."
      5. TRANSCRIPT: "We've detected suspicious activity on your account."
      6. RISK_UPDATE: risk_score = 20, risk_level = LOW
      7. TRANSCRIPT: "We need to verify your identity to prevent account freeze."
      8. RISK_UPDATE: risk_score = 45, risk_level = MEDIUM
      9. TRANSCRIPT: "Please tell me the OTP you received."
      10. ALERT: risk_score = 97, risk_level = CRITICAL
      11. Call Finalization (Call.status -> COMPLETED & links final ThreatResult)
      12. STATUS: ENDED

    If delay_seconds > 0, sleeps between each event to simulate real-time call.
    Uses db_session_factory to ensure database sessions are cleanly managed in background tasks.
    """
    logger.info(f"Starting call simulation '{call_id}' for device '{device_id}' (delay={delay_seconds}s)")

    async def handle_delay():
        if delay_seconds > 0:
            await asyncio.sleep(delay_seconds)

    # 1. CALL CREATED
    db: Session = db_session_factory()
    try:
        call_service.create_call(
            db=db,
            call_id=call_id,
            scammer_number="+15559876543",
            victim_number="+15551234567",
        )
    except Exception as e:
        logger.error(f"Failed to create call session for simulation: {e}")
        db.close()
        return

    # 2. STATUS: RINGING
    call_service.append_event(db, call_id, "STATUS", status="RINGING")
    db.close()
    await handle_delay()

    # 3. STATUS: IN_PROGRESS
    db = db_session_factory()
    call_service.update_status(db, call_id, "IN_PROGRESS")
    call_service.append_event(db, call_id, "STATUS", status="IN_PROGRESS")
    db.close()
    await handle_delay()

    # 4. TRANSCRIPT 1
    db = db_session_factory()
    call_service.append_event(
        db,
        call_id,
        "TRANSCRIPT",
        speaker="CALLER",
        text="Hello, I'm calling from your bank.",
    )
    db.close()
    await handle_delay()

    # 5. TRANSCRIPT 2
    db = db_session_factory()
    call_service.append_event(
        db,
        call_id,
        "TRANSCRIPT",
        speaker="CALLER",
        text="We've detected suspicious activity on your account.",
    )
    db.close()
    await handle_delay()

    # 6. RISK_UPDATE 1
    db = db_session_factory()
    call_service.append_event(
        db,
        call_id,
        "RISK_UPDATE",
        risk_score=20,
        risk_level=RiskLevel.LOW.value,
    )
    db.close()
    await handle_delay()

    # 7. TRANSCRIPT 3
    db = db_session_factory()
    call_service.append_event(
        db,
        call_id,
        "TRANSCRIPT",
        speaker="CALLER",
        text="We need to verify your identity to prevent account freeze.",
    )
    db.close()
    await handle_delay()

    # 8. RISK_UPDATE 2
    db = db_session_factory()
    call_service.append_event(
        db,
        call_id,
        "RISK_UPDATE",
        risk_score=45,
        risk_level=RiskLevel.MEDIUM.value,
    )
    db.close()
    await handle_delay()

    # 9. TRANSCRIPT 4
    db = db_session_factory()
    call_service.append_event(
        db,
        call_id,
        "TRANSCRIPT",
        speaker="CALLER",
        text="Please tell me the OTP you received.",
    )
    db.close()
    await handle_delay()

    # 10. ALERT
    db = db_session_factory()
    call_service.append_event(
        db,
        call_id,
        "ALERT",
        risk_score=97,
        risk_level=RiskLevel.CRITICAL.value,
        text="ALERT: Caller requested One-Time Password (OTP) over the phone. Hang up immediately.",
    )
    db.close()
    await handle_delay()

    # 11. Call Finalization (persisting final ThreatResult + updates Call status to COMPLETED)
    db = db_session_factory()
    threat_result = ThreatResult(
        id=f"thr_call_{uuid.uuid4().hex[:8]}",
        source=Source.CALL,
        risk_score=97,
        risk_level=RiskLevel.CRITICAL,
        threat_type="Banking Scam",
        indicators=["Bank impersonation", "OTP request", "Urgency"],
        recommendation="Hang up immediately and call your bank's official number.",
        timestamp=datetime.now(timezone.utc),
        analyzed_content=call_id,  # contract §1.2: call_id only
    )
    call_service.finalize_call(db, call_id, threat_result, device_id)
    db.close()
    await handle_delay()

    # 12. STATUS: ENDED
    db = db_session_factory()
    call_service.append_event(db, call_id, "STATUS", status="ENDED")
    db.close()

    logger.info(f"Call simulation '{call_id}' finished successfully.")
