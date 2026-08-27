"""
tests/test_services.py

Direct unit tests for the service layer — no HTTP, no TestClient.
Tests call service methods directly via a real in-memory SQLite session.

Covers Day 2 additions:
  - CallService.create_call
  - CallService.update_status
  - CallService.finalize_call
  - CallService.append_event (seq, status field, unknown call)
  - ThreatService round-trip
  - AnalysisProvider Protocol compliance
"""
import uuid
from datetime import datetime, timezone

import pytest
from sqlalchemy.orm import Session

from app.core.errors import CallNotFoundError, InvalidInputError
from app.models.call import Call, CallEvent
from app.models.threat import Threat
from app.schemas.common import RiskLevel, Source
from app.schemas.threat import ThreatResult
from app.services.analysis import (
    AnalysisProvider,
    AnalysisService,
    StubAnalysisProvider,
)
from app.services.call import call_service, CallService
from app.services.threat import ThreatService, threat_service
from tests.conftest import DEVICE_A


# ── Helpers ───────────────────────────────────────────────────────────────────

def _make_call_id() -> str:
    return f"call_{uuid.uuid4().hex[:8]}"


def _make_threat_result(source: Source = Source.SMS, call_id: str | None = None) -> ThreatResult:
    return ThreatResult(
        id=f"thr_{source.value.lower()}_{uuid.uuid4().hex[:8]}",
        source=source,
        risk_score=85,
        risk_level=RiskLevel.HIGH,
        threat_type="Banking Scam",
        indicators=["Bank impersonation", "Urgency"],
        recommendation="Do not share your OTP.",
        timestamp=datetime.now(timezone.utc),
        analyzed_content=call_id if call_id else "test content",
    )


# ── ThreatService ─────────────────────────────────────────────────────────────

class TestThreatService:

    def test_create_and_retrieve_round_trip(self, db: Session):
        """Created threat can be retrieved with all fields intact."""
        result = _make_threat_result()
        row = threat_service.create(db=db, result=result, device_id=DEVICE_A)

        assert row.id == result.id
        assert row.source == result.source.value
        assert row.risk_score == result.risk_score
        assert row.risk_level == result.risk_level.value
        assert row.threat_type == result.threat_type
        assert row.indicators == result.indicators
        assert row.recommendation == result.recommendation
        assert row.analyzed_content == result.analyzed_content

    def test_to_schema_preserves_all_contract_fields(self, db: Session):
        """to_schema() output matches all nine contract §1 fields."""
        result = _make_threat_result()
        row = threat_service.create(db=db, result=result, device_id=DEVICE_A)
        schema = ThreatService.to_schema(row)

        assert schema.id == result.id
        assert schema.source == result.source
        assert schema.risk_score == result.risk_score
        assert schema.risk_level == result.risk_level
        assert schema.threat_type == result.threat_type
        assert schema.indicators == result.indicators
        assert schema.recommendation == result.recommendation
        assert schema.analyzed_content == result.analyzed_content

    def test_indicators_round_trip(self, db: Session):
        """indicators JSON serialisation round-trip preserves list."""
        result = _make_threat_result()
        result = result.model_copy(update={"indicators": ["Ind A", "Ind B", "Ind C"]})
        row = threat_service.create(db=db, result=result, device_id=DEVICE_A)
        assert row.indicators == ["Ind A", "Ind B", "Ind C"]

    def test_risk_score_integer_not_float(self, db: Session):
        """risk_score stored and returned as integer per contract §1.1."""
        result = _make_threat_result()
        row = threat_service.create(db=db, result=result, device_id=DEVICE_A)
        assert isinstance(row.risk_score, int)


# ── CallService.create_call ───────────────────────────────────────────────────

class TestCallServiceCreate:

    def test_create_call_returns_call_with_initiated_status(self, db: Session):
        cid = _make_call_id()
        call = call_service.create_call(db, cid, "+15550001111", "+15550002222")
        assert call.id == cid
        assert call.status == "INITIATED"
        assert call.scammer_number == "+15550001111"
        assert call.victim_number == "+15550002222"
        assert call.started_at is not None

    def test_create_call_persisted_to_db(self, db: Session):
        cid = _make_call_id()
        call_service.create_call(db, cid)
        row = db.query(Call).filter(Call.id == cid).first()
        assert row is not None
        assert row.status == "INITIATED"

    def test_create_call_duplicate_raises_invalid_input(self, db: Session):
        cid = _make_call_id()
        call_service.create_call(db, cid)
        with pytest.raises(InvalidInputError):
            call_service.create_call(db, cid)

    def test_create_call_without_numbers_allowed(self, db: Session):
        cid = _make_call_id()
        call = call_service.create_call(db, cid)
        assert call.scammer_number is None
        assert call.victim_number is None


# ── CallService.update_status ─────────────────────────────────────────────────

class TestCallServiceUpdateStatus:

    def test_update_status_to_in_progress(self, db: Session):
        cid = _make_call_id()
        call_service.create_call(db, cid)
        updated = call_service.update_status(db, cid, "IN_PROGRESS")
        assert updated.status == "IN_PROGRESS"
        assert updated.ended_at is None

    def test_update_status_to_completed_sets_ended_at(self, db: Session):
        cid = _make_call_id()
        call_service.create_call(db, cid)
        updated = call_service.update_status(db, cid, "COMPLETED")
        assert updated.status == "COMPLETED"
        assert updated.ended_at is not None

    def test_update_status_to_failed_sets_ended_at(self, db: Session):
        cid = _make_call_id()
        call_service.create_call(db, cid)
        updated = call_service.update_status(db, cid, "FAILED")
        assert updated.status == "FAILED"
        assert updated.ended_at is not None

    def test_update_status_invalid_value_raises_error(self, db: Session):
        cid = _make_call_id()
        call_service.create_call(db, cid)
        with pytest.raises(InvalidInputError):
            call_service.update_status(db, cid, "NONSENSE")

    def test_update_status_unknown_call_raises_not_found(self, db: Session):
        with pytest.raises(CallNotFoundError):
            call_service.update_status(db, "call_nonexistent", "IN_PROGRESS")


# ── CallService.finalize_call ─────────────────────────────────────────────────

class TestCallServiceFinalize:

    def test_finalize_sets_completed_and_links_threat(self, db: Session):
        cid = _make_call_id()
        call_service.create_call(db, cid)
        result = _make_threat_result(Source.CALL, call_id=cid)
        call = call_service.finalize_call(db, cid, result, DEVICE_A)

        assert call.status == "COMPLETED"
        assert call.threat_id is not None
        assert call.ended_at is not None

    def test_finalize_enforces_analyzed_content_equals_call_id(self, db: Session):
        """
        Contract §1.2: analyzed_content for CALL = call_id, never transcript.
        finalize_call() must enforce this regardless of what the AI sends.
        """
        cid = _make_call_id()
        call_service.create_call(db, cid)

        # Simulate AI sending analyzed_content with a transcript fragment
        result = _make_threat_result(Source.CALL, call_id=cid)
        result = result.model_copy(update={"analyzed_content": "Full transcript here..."})

        call = call_service.finalize_call(db, cid, result, DEVICE_A)

        # Backend must overwrite analyzed_content with call_id
        threat_row = db.query(Threat).filter(Threat.id == call.threat_id).first()
        assert threat_row.analyzed_content == cid

    def test_finalize_persists_threat_to_db(self, db: Session):
        cid = _make_call_id()
        call_service.create_call(db, cid)
        result = _make_threat_result(Source.CALL, call_id=cid)
        call = call_service.finalize_call(db, cid, result, DEVICE_A)

        threat_row = db.query(Threat).filter(Threat.id == call.threat_id).first()
        assert threat_row is not None
        assert threat_row.source == "CALL"
        assert threat_row.device_id == DEVICE_A

    def test_finalize_unknown_call_raises_not_found(self, db: Session):
        result = _make_threat_result(Source.CALL, call_id="call_ghost")
        with pytest.raises(CallNotFoundError):
            call_service.finalize_call(db, "call_ghost", result, DEVICE_A)

    def test_finalize_result_retrievable_via_get_result(self, db: Session):
        """get_result() must return the exact ThreatResult after finalize_call()."""
        cid = _make_call_id()
        call_service.create_call(db, cid)
        result = _make_threat_result(Source.CALL, call_id=cid)
        call_service.finalize_call(db, cid, result, DEVICE_A)

        retrieved = call_service.get_result(db, cid)
        assert retrieved.id == result.id
        assert retrieved.source == Source.CALL
        assert retrieved.analyzed_content == cid  # enforced by finalize_call


# ── CallService.append_event ──────────────────────────────────────────────────

class TestCallServiceAppendEvent:

    def test_append_event_seq_starts_at_one(self, db: Session):
        cid = _make_call_id()
        call_service.create_call(db, cid)
        ev = call_service.append_event(db, cid, "STATUS", status="RINGING")
        assert ev.seq == 1

    def test_append_event_seq_increments(self, db: Session):
        cid = _make_call_id()
        call_service.create_call(db, cid)
        e1 = call_service.append_event(db, cid, "STATUS", status="IN_PROGRESS")
        e2 = call_service.append_event(db, cid, "TRANSCRIPT", speaker="CALLER", text="Hello")
        e3 = call_service.append_event(db, cid, "RISK_UPDATE", risk_score=60, risk_level="HIGH")
        assert e1.seq == 1
        assert e2.seq == 2
        assert e3.seq == 3

    def test_status_event_stores_status_field(self, db: Session):
        """STATUS events must persist the status string per contract §6.2."""
        cid = _make_call_id()
        call_service.create_call(db, cid)
        ev = call_service.append_event(db, cid, "STATUS", status="IN_PROGRESS")
        assert ev.status == "IN_PROGRESS"
        assert ev.type == "STATUS"

    def test_transcript_event_stores_speaker_and_text(self, db: Session):
        """Contract §6.2: TRANSCRIPT events carry speaker=CALLER|USER and text."""
        cid = _make_call_id()
        call_service.create_call(db, cid)
        ev = call_service.append_event(
            db, cid, "TRANSCRIPT", speaker="CALLER", text="Your OTP is 123456."
        )
        assert ev.speaker == "CALLER"
        assert ev.text == "Your OTP is 123456."
        assert ev.status is None  # STATUS field not set on TRANSCRIPT

    def test_risk_update_event_stores_score_and_level(self, db: Session):
        cid = _make_call_id()
        call_service.create_call(db, cid)
        ev = call_service.append_event(
            db, cid, "RISK_UPDATE", risk_score=72, risk_level="HIGH"
        )
        assert ev.risk_score == 72
        assert ev.risk_level == "HIGH"

    def test_append_event_unknown_call_raises_not_found(self, db: Session):
        with pytest.raises(CallNotFoundError):
            call_service.append_event(db, "call_ghost", "STATUS", status="RINGING")

    def test_append_event_visible_via_get_events(self, db: Session):
        """Events appended via service must be retrievable via polling endpoint."""
        cid = _make_call_id()
        call_service.create_call(db, cid)
        call_service.append_event(db, cid, "TRANSCRIPT", speaker="CALLER", text="Hello bank.")
        call_service.append_event(db, cid, "RISK_UPDATE", risk_score=50, risk_level="MEDIUM")

        response = call_service.get_events(db, cid, after_seq=0)
        assert len(response.events) == 2
        assert response.events[0].type.value == "TRANSCRIPT"
        assert response.events[1].type.value == "RISK_UPDATE"

    def test_after_seq_filters_correctly(self, db: Session):
        """after_seq=1 must return only events with seq > 1."""
        cid = _make_call_id()
        call_service.create_call(db, cid)
        call_service.append_event(db, cid, "STATUS", status="IN_PROGRESS")
        call_service.append_event(db, cid, "TRANSCRIPT", speaker="CALLER", text="Hi")
        call_service.append_event(db, cid, "TRANSCRIPT", speaker="USER", text="Who are you?")

        response = call_service.get_events(db, cid, after_seq=1)
        assert len(response.events) == 2
        assert all(e.seq > 1 for e in response.events)


# ── AnalysisProvider Protocol ─────────────────────────────────────────────────

class TestAnalysisProviderProtocol:

    def test_stub_provider_satisfies_protocol(self):
        """StubAnalysisProvider must structurally satisfy AnalysisProvider Protocol."""
        assert isinstance(StubAnalysisProvider(), AnalysisProvider)

    def test_stub_provider_sms_returns_threat_result(self):
        provider = StubAnalysisProvider()
        result = provider.analyze(
            source=Source.SMS,
            content="Your KYC has expired. Share OTP immediately.",
            metadata={},
        )
        assert isinstance(result, ThreatResult)
        assert result.source == Source.SMS
        assert 0 <= result.risk_score <= 100
        assert result.risk_level in (RiskLevel.LOW, RiskLevel.MEDIUM, RiskLevel.HIGH, RiskLevel.CRITICAL)
        assert isinstance(result.indicators, list)

    def test_stub_provider_call_source_raises_analysis_failed(self):
        """StubAnalysisProvider must not fake a LOW for CALL — per contract §5.2."""
        from app.core.errors import AnalysisFailedError
        provider = StubAnalysisProvider()
        with pytest.raises(AnalysisFailedError):
            provider.analyze(Source.CALL, "CA_some_id", {})

    def test_custom_provider_can_be_injected(self):
        """AnalysisService accepts any AnalysisProvider implementation."""
        class MockProvider:
            def analyze(self, source, content, metadata) -> ThreatResult:
                return ThreatResult(
                    id="thr_sms_mockabcd",
                    source=Source.SMS,
                    risk_score=99,
                    risk_level=RiskLevel.CRITICAL,
                    threat_type="Mock Scam",
                    indicators=["mock"],
                    recommendation="Mock rec.",
                    timestamp=datetime.now(timezone.utc),
                    analyzed_content=content,
                )

        service = AnalysisService(provider=MockProvider())
        result = service.analyze(Source.SMS, "test", {})
        assert result.risk_score == 99
        assert result.threat_type == "Mock Scam"

    def test_analysis_service_wraps_provider_exceptions_as_analysis_failed(self):
        """Unexpected provider errors become AnalysisFailedError, not 500 crashes."""
        from app.core.errors import AnalysisFailedError

        class BrokenProvider:
            def analyze(self, source, content, metadata) -> ThreatResult:
                raise RuntimeError("AI is down")

        service = AnalysisService(provider=BrokenProvider())
        with pytest.raises(AnalysisFailedError, match="AI is down"):
            service.analyze(Source.SMS, "test", {})
