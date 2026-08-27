"""
app/services/call.py

CallService — manages Call lifecycle and CallEvent storage/retrieval.

The real call lifecycle (Twilio webhooks, media streams, STT, AI scoring)
is owned by Sub-team A (Sanjani + Skandan). This service is the backend's
side of the integration. Sanjani's Twilio webhook handler ONLY needs to
call these methods — it should not import or touch ORM models directly.

Integration boundary for Sanjani:
    call_service.create_call(db, call_id, scammer_number, victim_number)
    call_service.update_status(db, call_id, new_status)
    call_service.append_event(db, call_id, event_type, ...)
    call_service.finalize_call(db, call_id, threat_result, device_id)

Read paths for Kalyan's Flutter app / web console:
    call_service.get_active(db)
    call_service.get_events(db, call_id, after_seq)
    call_service.get_result(db, call_id)

Day 1: No active call seeded in the DB. The real application starts with
no active call. Mock data lives exclusively in tests/conftest.py.
"""
from datetime import datetime, timezone

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.errors import CallNotFoundError, InvalidInputError
from app.models.call import Call, CallEvent
from app.schemas.call import ActiveCallResponse, CallEventOut, CallEventsResponse
from app.schemas.threat import ThreatResult
from app.services.threat import ThreatService

# Valid Call.status values
_VALID_STATUSES = {"INITIATED", "IN_PROGRESS", "COMPLETED", "FAILED"}


class CallService:

    # ── Lifecycle — write paths (for Sanjani's Twilio webhook handler) ────

    def create_call(
        self,
        db: Session,
        call_id: str,
        scammer_number: str | None = None,
        victim_number: str | None = None,
    ) -> Call:
        """
        Create a new Call session.

        call_id should be the Twilio CallSid or a generated unique ID.
        Raises InvalidInputError if a call with this ID already exists.

        Integration note for Sanjani:
            Call this from the Twilio 'call started' webhook.
        """
        existing = db.query(Call).filter(Call.id == call_id).first()
        if existing is not None:
            raise InvalidInputError(f"Call '{call_id}' already exists.")

        call = Call(
            id=call_id,
            status="INITIATED",
            scammer_number=scammer_number,
            victim_number=victim_number,
            started_at=datetime.now(timezone.utc),
        )
        db.add(call)
        db.commit()
        db.refresh(call)
        return call

    def update_status(self, db: Session, call_id: str, new_status: str) -> Call:
        """
        Update a Call's status field.

        Valid values: INITIATED | IN_PROGRESS | COMPLETED | FAILED
        Raises CallNotFoundError if call_id does not exist.
        Raises InvalidInputError if new_status is not a valid value.

        Integration note for Sanjani:
            Call this when Twilio signals the call state changes.
        """
        if new_status not in _VALID_STATUSES:
            raise InvalidInputError(
                f"Invalid call status '{new_status}'. "
                f"Must be one of: {sorted(_VALID_STATUSES)}"
            )
        call = db.query(Call).filter(Call.id == call_id).first()
        if call is None:
            raise CallNotFoundError(f"Call '{call_id}' not found.")

        call.status = new_status
        if new_status in ("COMPLETED", "FAILED"):
            call.ended_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(call)
        return call

    def finalize_call(
        self,
        db: Session,
        call_id: str,
        threat_result: ThreatResult,
        device_id: str,
    ) -> Call:
        """
        Persist the final AI ThreatResult and link it to the Call.

        Per contract §6.3 and §1.2:
          - source must be CALL
          - analyzed_content is set to call_id (never the full transcript)
          - Call.status transitions to COMPLETED
          - Call.threat_id is set to the persisted ThreatResult.id

        Raises CallNotFoundError if call_id does not exist.

        Integration note for Skandan:
            After your AI produces a ThreatResult from the call audio,
            pass it here. The backend handles all persistence.
        """
        call = db.query(Call).filter(Call.id == call_id).first()
        if call is None:
            raise CallNotFoundError(f"Call '{call_id}' not found.")

        # Enforce contract §1.2: analyzed_content for CALL = call_id only
        canonical_result = ThreatResult(
            id=threat_result.id,
            source=threat_result.source,
            risk_score=threat_result.risk_score,
            risk_level=threat_result.risk_level,
            threat_type=threat_result.threat_type,
            indicators=threat_result.indicators,
            recommendation=threat_result.recommendation,
            timestamp=threat_result.timestamp,
            analyzed_content=call_id,  # contract §1.2 — always call_id, not transcript
        )

        # Persist ThreatResult
        threat_row = ThreatService().create(
            db=db,
            result=canonical_result,
            device_id=device_id,
            call_id=call_id,
        )

        # Link threat to call and mark completed
        call.threat_id = threat_row.id
        call.status = "COMPLETED"
        call.ended_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(call)
        return call

    # ── Active call ───────────────────────────────────────────────────────

    def get_active(self, db: Session) -> ActiveCallResponse:
        """
        Returns the currently active call_id, or null if no call is active.
        A call is active when its status is INITIATED or IN_PROGRESS.
        Per contract §6.4.
        """
        row = (
            db.query(Call)
            .filter(Call.status.in_(["INITIATED", "IN_PROGRESS"]))
            .order_by(Call.started_at.desc())
            .first()
        )
        return ActiveCallResponse(call_id=row.id if row else None)

    # ── Event polling ─────────────────────────────────────────────────────

    def get_events(
        self,
        db: Session,
        call_id: str,
        after_seq: int = 0,
    ) -> CallEventsResponse:
        """
        Returns all events for call_id with seq > after_seq, ascending.
        Per contract §6.1 — polling cursor transport.
        Raises CallNotFoundError if the call does not exist.
        """
        call = db.query(Call).filter(Call.id == call_id).first()
        if call is None:
            raise CallNotFoundError(f"Call '{call_id}' not found.")

        rows = (
            db.query(CallEvent)
            .filter(CallEvent.call_id == call_id, CallEvent.seq > after_seq)
            .order_by(CallEvent.seq)
            .all()
        )

        events = [self._event_to_schema(r) for r in rows]
        return CallEventsResponse(call_id=call_id, events=events)

    # ── Final result ──────────────────────────────────────────────────────

    def get_result(self, db: Session, call_id: str) -> ThreatResult:
        """
        Returns the final ThreatResult for a completed call.
        Per contract §6.3: source=CALL, analyzed_content=call_id.
        Raises CallNotFoundError if the call does not exist or has no result yet.
        """
        call = db.query(Call).filter(Call.id == call_id).first()
        if call is None:
            raise CallNotFoundError(f"Call '{call_id}' not found.")
        if call.threat_id is None:
            raise CallNotFoundError(
                f"Call '{call_id}' has no final result yet (status: {call.status})."
            )

        from app.models.threat import Threat

        threat_row = db.query(Threat).filter(Threat.id == call.threat_id).first()
        if threat_row is None:
            raise CallNotFoundError(f"Threat record for call '{call_id}' not found.")

        return ThreatService.to_schema(threat_row)

    # ── Event ingestion (for Sanjani's Twilio webhook handler) ───────────

    def append_event(
        self,
        db: Session,
        call_id: str,
        event_type: str,
        *,
        status: str | None = None,
        speaker: str | None = None,
        text: str | None = None,
        risk_score: int | None = None,
        risk_level: str | None = None,
    ) -> CallEvent:
        """
        Append a new event to a call's event stream.

        seq is auto-assigned as max(existing seq) + 1 for this call.
        seq starts at 1 per contract §6.2.
        Raises CallNotFoundError if call_id does not exist.

        Per contract §6.2 field semantics:
          STATUS events:     status = RINGING | IN_PROGRESS | ENDED
          TRANSCRIPT events: speaker = CALLER | USER; text = chunk
          RISK_UPDATE events: risk_score (0-100), risk_level
          ALERT events:      text, risk_score, risk_level

        Integration note for Sanjani:
            Call this for every event from the Twilio / AI pipeline.
            Do not write to call_events table directly.
        """
        call = db.query(Call).filter(Call.id == call_id).first()
        if call is None:
            raise CallNotFoundError(f"Call '{call_id}' not found.")

        max_seq = (
            db.query(func.max(CallEvent.seq))
            .filter(CallEvent.call_id == call_id)
            .scalar()
        ) or 0  # starts at 0 so first seq = 1 per contract §6.2

        event = CallEvent(
            call_id=call_id,
            seq=max_seq + 1,
            type=event_type,
            timestamp=datetime.now(timezone.utc),
            status=status,
            speaker=speaker,
            text=text,
            risk_score=risk_score,
            risk_level=risk_level,
        )
        db.add(event)
        db.commit()
        db.refresh(event)
        return event

    # ── Internal converter ────────────────────────────────────────────────

    @staticmethod
    def _event_to_schema(row: CallEvent) -> CallEventOut:
        return CallEventOut(
            call_id=row.call_id,
            seq=row.seq,
            type=row.type,  # type: ignore[arg-type]
            timestamp=row.timestamp,
            status=row.status,
            speaker=row.speaker,
            text=row.text,
            risk_score=row.risk_score,
            risk_level=row.risk_level,  # type: ignore[arg-type]
        )


call_service = CallService()
