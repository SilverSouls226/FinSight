"""
app/services/threat.py

ThreatService — persistence and retrieval of ThreatResult records.
Keeps all DB logic out of the API route functions.
"""
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.core.errors import NotFoundError
from app.models.threat import Threat
from app.schemas.threat import ThreatResult


class ThreatService:

    def create(
        self,
        db: Session,
        result: ThreatResult,
        device_id: str,
        call_id: str | None = None,
    ) -> Threat:
        """Persist a ThreatResult to the database and return the ORM row."""
        row = Threat(
            id=result.id,
            device_id=device_id,
            source=result.source.value,
            risk_score=result.risk_score,
            risk_level=result.risk_level.value,
            threat_type=result.threat_type,
            recommendation=result.recommendation,
            analyzed_content=result.analyzed_content,
            timestamp=result.timestamp,
            call_id=call_id,
        )
        row.indicators = result.indicators
        db.add(row)
        db.commit()
        db.refresh(row)
        return row

    def get_history(
        self,
        db: Session,
        device_id: str,
        limit: int = 50,
    ) -> list[Threat]:
        """
        Return threats for a specific device, newest first.
        Scoped by device_id — one client cannot see another's history.
        """
        return (
            db.query(Threat)
            .filter(Threat.device_id == device_id)
            .order_by(Threat.timestamp.desc())
            .limit(limit)
            .all()
        )

    def get_by_id(self, db: Session, threat_id: str) -> Threat:
        """Return a single threat by id. Raises NotFoundError if absent."""
        row = db.query(Threat).filter(Threat.id == threat_id).first()
        if row is None:
            raise NotFoundError(f"Threat '{threat_id}' not found.")
        return row

    @staticmethod
    def to_schema(row: Threat) -> ThreatResult:
        """Convert an ORM Threat row to the ThreatResult Pydantic schema."""
        return ThreatResult(
            id=row.id,
            source=row.source,  # type: ignore[arg-type]
            risk_score=row.risk_score,
            risk_level=row.risk_level,  # type: ignore[arg-type]
            threat_type=row.threat_type,
            indicators=row.indicators,
            recommendation=row.recommendation,
            timestamp=row.timestamp,
            analyzed_content=row.analyzed_content,
        )


threat_service = ThreatService()
