"""
app/models/call.py

SQLAlchemy ORM models for Call and CallEvent.

Call  — one row per bridged Twilio call session.
CallEvent — append-only log of events emitted during a call.
            seq is monotonically increasing per call_id, starting at 1.
            Clients poll GET /api/calls/{call_id}/events?after_seq=N.

Event field semantics per Backend Contract v1.0 §6.2:
    STATUS events:    status = RINGING | IN_PROGRESS | ENDED
    TRANSCRIPT events: speaker = CALLER | USER; text = transcript chunk
    RISK_UPDATE events: risk_score (0-100), risk_level
    ALERT events:     text = alert message; risk_score, risk_level

NOTE: No seed/mock data is inserted here.
      Mock data lives exclusively in tests/conftest.py.
"""
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Call(Base):
    __tablename__ = "calls"

    # ── Primary key — Twilio CallSid or a generated ID ───────────────────
    id: Mapped[str] = mapped_column(String(64), primary_key=True)

    # ── Status state machine ──────────────────────────────────────────────
    # Values: INITIATED | IN_PROGRESS | COMPLETED | FAILED
    status: Mapped[str] = mapped_column(String(16), nullable=False, default="INITIATED")

    # ── Participants ──────────────────────────────────────────────────────
    scammer_number: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    victim_number: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)

    # ── Timestamps ────────────────────────────────────────────────────────
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    ended_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # ── Final ThreatResult FK (set when call is completed / finalized) ────
    threat_id: Mapped[Optional[str]] = mapped_column(
        String(64), ForeignKey("threats.id"), nullable=True
    )

    # ── Relationships ─────────────────────────────────────────────────────
    events: Mapped[list["CallEvent"]] = relationship(
        back_populates="call", order_by="CallEvent.seq", cascade="all, delete-orphan"
    )
    threat: Mapped[Optional["Threat"]] = relationship(  # type: ignore[name-defined]
        "Threat",
        foreign_keys="[Call.threat_id]",
        primaryjoin="Call.threat_id == foreign(Threat.id)",
        uselist=False,
        viewonly=True,
    )

    @property
    def is_active(self) -> bool:
        return self.status in ("INITIATED", "IN_PROGRESS")

    def __repr__(self) -> str:
        return f"<Call id={self.id!r} status={self.status!r}>"


class CallEvent(Base):
    __tablename__ = "call_events"
    __table_args__ = (
        # (call_id, seq) must be unique — enforces monotonic ordering per call.
        UniqueConstraint("call_id", "seq", name="uq_call_event_seq"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    call_id: Mapped[str] = mapped_column(
        String(64), ForeignKey("calls.id"), nullable=False, index=True
    )

    # Monotonic counter per call — clients use this for ?after_seq= polling.
    # Starts at 1 per contract §6.2.
    seq: Mapped[int] = mapped_column(Integer, nullable=False)

    # Event type per contract §6.2: STATUS | TRANSCRIPT | RISK_UPDATE | ALERT
    type: Mapped[str] = mapped_column(String(16), nullable=False)

    timestamp: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )

    # ── Per-event-type payload fields (contract §6.2) ─────────────────────

    # STATUS events: RINGING | IN_PROGRESS | ENDED
    status: Mapped[Optional[str]] = mapped_column(String(16), nullable=True)

    # TRANSCRIPT events: CALLER | USER  (contract §6.2 — not SCAMMER/VICTIM)
    speaker: Mapped[Optional[str]] = mapped_column(String(8), nullable=True)

    # TRANSCRIPT and ALERT events: transcript chunk or alert message
    text: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # RISK_UPDATE and ALERT events
    risk_score: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    risk_level: Mapped[Optional[str]] = mapped_column(String(8), nullable=True)

    # ── Relationship ──────────────────────────────────────────────────────
    call: Mapped["Call"] = relationship(back_populates="events")

    def __repr__(self) -> str:
        return f"<CallEvent call_id={self.call_id!r} seq={self.seq!r} type={self.type!r}>"
