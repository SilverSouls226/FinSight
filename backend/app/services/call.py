"""
app/services/call.py

CallService — manages Call lifecycle and CallEvent storage/retrieval.

The real call lifecycle (Twilio webhooks, media streams, STT, AI scoring)
is owned by Sub-team A (Sanjani + Skandan). This service is the backend's
side of the integration: it receives events, stores them, and serves them
to polling clients (Flutter app / web console).

Day 1: No active call seeded in the DB. The real application starts with
no active call. Mock data lives exclusively in tests/conftest.py.
"""
from datetime import datetime, timezone

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.errors import CallNotFoundError
from app.models.call import Call, CallEvent
from app.schemas.call import ActiveCallResponse, CallEventOut, CallEventsResponse
from app.schemas.threat import ThreatResult
from app.services.threat import ThreatService


class CallService:

    # ── Active call ───────────────────────────────────────────────────────

    def get_active(self, db: Session) -> ActiveCallResponse:
        """
        Returns the currently active call_id, or null if no call is active.
        A call is active when its status is INITIATED or IN_PROGRESS.
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
        Returns all events for call_id with seq > after_seq.
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

    # ── Ingest (used by Sub-team A's webhook handler — Day 2+) ───────────

    def append_event(
        self,
        db: Session,
        call_id: str,
        event_type: str,
        *,
        speaker: str | None = None,
        text: str | None = None,
        risk_score: int | None = None,
        risk_level: str | None = None,
        status: str | None = None,
    ) -> CallEvent:
        """
        Append a new event to a call's event stream.
        seq is auto-assigned as max(existing seq) + 1 for this call.
        Raises CallNotFoundError if call_id does not exist.
        """
        call = db.query(Call).filter(Call.id == call_id).first()
        if call is None:
            raise CallNotFoundError(f"Call '{call_id}' not found.")

        max_seq = (
            db.query(func.max(CallEvent.seq))
            .filter(CallEvent.call_id == call_id)
            .scalar()
        ) or 0

        event = CallEvent(
            call_id=call_id,
            seq=max_seq + 1,
            type=event_type,
            timestamp=datetime.now(timezone.utc),
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
            speaker=row.speaker,
            text=row.text,
            risk_score=row.risk_score,
            risk_level=row.risk_level,  # type: ignore[arg-type]
        )


call_service = CallService()
