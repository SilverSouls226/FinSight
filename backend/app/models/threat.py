"""
app/models/threat.py

SQLAlchemy ORM model for the Threat entity.

Column layout matches the frozen contract ThreatResult shape exactly:
    id, source, risk_score, risk_level, threat_type, indicators,
    recommendation, timestamp, analyzed_content

Additional persistence columns (not in the API response):
    device_id  — used for device-scoped history queries (GET /api/threats)
    call_id    — nullable FK to Call, set when source == "CALL"
"""
import json
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Threat(Base):
    __tablename__ = "threats"

    # ── Primary key — format: thr_{source_lower}_{uuid8} ─────────────────
    id: Mapped[str] = mapped_column(String(64), primary_key=True)

    # ── Device identity (from X-Device-Id header) ─────────────────────────
    device_id: Mapped[str] = mapped_column(String(256), nullable=False, index=True)

    # ── Threat classification ─────────────────────────────────────────────
    source: Mapped[str] = mapped_column(String(8), nullable=False)
    # Values: CALL | SMS | QR | LINK

    risk_score: Mapped[int] = mapped_column(Integer, nullable=False)
    # Range: 0–100. Backend NEVER stores or emits UNKNOWN.

    risk_level: Mapped[str] = mapped_column(String(8), nullable=False)
    # Values: LOW | MEDIUM | HIGH | CRITICAL

    threat_type: Mapped[str] = mapped_column(String(128), nullable=False)
    # e.g. "Banking Scam", "Phishing", "Malicious QR"

    # ── Stored as JSON array string e.g. '["OTP request","Urgency"]' ──────
    _indicators: Mapped[str] = mapped_column("indicators", Text, nullable=False, default="[]")

    recommendation: Mapped[str] = mapped_column(Text, nullable=False, default="")

    # ── Original scanned/analyzed content ────────────────────────────────
    analyzed_content: Mapped[str] = mapped_column(Text, nullable=False, default="")

    # ── Timestamps ────────────────────────────────────────────────────────
    timestamp: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        index=True,
        default=lambda: datetime.now(timezone.utc),
    )

    # ── Optional FK to Call (set only when source == "CALL") ─────────────
    # Only the FK column is stored here. Navigate via Call.threat if needed.
    call_id: Mapped[Optional[str]] = mapped_column(
        String(64), ForeignKey("calls.id", use_alter=True, name="fk_threat_call_id"),
        nullable=True, index=True
    )

    # ── indicators property: transparent JSON serialization ───────────────

    @property
    def indicators(self) -> list[str]:
        try:
            return json.loads(self._indicators)
        except (ValueError, TypeError):
            return []

    @indicators.setter
    def indicators(self, value: list[str]) -> None:
        self._indicators = json.dumps(value)

    def __repr__(self) -> str:
        return f"<Threat id={self.id!r} source={self.source!r} risk_level={self.risk_level!r}>"
