"""
tests/test_calls.py

Tests for:
  GET /api/calls/active
  GET /api/calls/{call_id}/events
  GET /api/calls/{call_id}/result
"""
import pytest
from fastapi.testclient import TestClient

from app.models.call import Call, CallEvent
from app.models.threat import Threat


class TestActiveCall:

    def test_no_active_call_returns_null(self, client: TestClient):
        """Fresh DB: active call must return {call_id: null}."""
        resp = client.get("/api/calls/active")
        assert resp.status_code == 200
        assert resp.json() == {"call_id": None}

    def test_active_call_returns_call_id(self, client: TestClient, seed_active_call: Call):
        resp = client.get("/api/calls/active")
        assert resp.status_code == 200
        assert resp.json()["call_id"] == seed_active_call.id

    def test_completed_call_is_not_active(self, client: TestClient, seed_completed_call):
        call, _ = seed_completed_call
        resp = client.get("/api/calls/active")
        assert resp.status_code == 200
        assert resp.json()["call_id"] is None


class TestCallEvents:

    def test_events_for_unknown_call_returns_404(self, client: TestClient):
        resp = client.get("/api/calls/call_nonexistent/events")
        assert resp.status_code == 404
        body = resp.json()
        assert "error" in body
        assert body["error"]["code"] == "CALL_NOT_FOUND"

    def test_events_returns_all_events_from_seq_zero(
        self, client: TestClient, seed_active_call: Call
    ):
        resp = client.get(f"/api/calls/{seed_active_call.id}/events?after_seq=0")
        assert resp.status_code == 200
        body = resp.json()
        assert body["call_id"] == seed_active_call.id
        assert len(body["events"]) == 2  # seed fixture inserts 2 events

    def test_events_respects_after_seq(self, client: TestClient, seed_active_call: Call):
        """after_seq=1 should only return events with seq > 1."""
        resp = client.get(f"/api/calls/{seed_active_call.id}/events?after_seq=1")
        assert resp.status_code == 200
        events = resp.json()["events"]
        assert all(e["seq"] > 1 for e in events)
        assert len(events) == 1  # only seq=2 remains

    def test_events_after_last_seq_returns_empty(
        self, client: TestClient, seed_active_call: Call
    ):
        resp = client.get(f"/api/calls/{seed_active_call.id}/events?after_seq=999")
        assert resp.status_code == 200
        assert resp.json()["events"] == []

    def test_event_schema_completeness(self, client: TestClient, seed_active_call: Call):
        """Each event must have the required fields from the frozen contract."""
        resp = client.get(f"/api/calls/{seed_active_call.id}/events?after_seq=0")
        events = resp.json()["events"]
        for event in events:
            assert "call_id" in event
            assert "seq" in event
            assert "type" in event
            assert "timestamp" in event

    def test_events_ordered_by_seq(self, client: TestClient, seed_active_call: Call):
        resp = client.get(f"/api/calls/{seed_active_call.id}/events?after_seq=0")
        seqs = [e["seq"] for e in resp.json()["events"]]
        assert seqs == sorted(seqs)

    def test_event_type_is_valid_enum(self, client: TestClient, seed_active_call: Call):
        resp = client.get(f"/api/calls/{seed_active_call.id}/events?after_seq=0")
        valid_types = {"STATUS", "TRANSCRIPT", "RISK_UPDATE", "ALERT"}
        for event in resp.json()["events"]:
            assert event["type"] in valid_types


class TestCallResult:

    def test_result_for_unknown_call_returns_404(self, client: TestClient):
        resp = client.get("/api/calls/call_nonexistent/result")
        assert resp.status_code == 404

    def test_result_for_active_call_without_result_returns_404(
        self, client: TestClient, seed_active_call: Call
    ):
        """Active call with no threat_id yet should return 404."""
        resp = client.get(f"/api/calls/{seed_active_call.id}/result")
        assert resp.status_code == 404

    def test_result_for_completed_call(self, client: TestClient, seed_completed_call):
        call, threat_row = seed_completed_call
        resp = client.get(f"/api/calls/{call.id}/result")
        assert resp.status_code == 200
        body = resp.json()
        assert body["id"] == threat_row.id
        assert body["source"] == "CALL"
        assert body["risk_score"] == 97
        assert body["risk_level"] == "CRITICAL"
        assert "Bank impersonation" in body["indicators"]

    def test_result_matches_threat_result_schema(self, client: TestClient, seed_completed_call):
        call, _ = seed_completed_call
        resp = client.get(f"/api/calls/{call.id}/result")
        body = resp.json()
        required = [
            "id", "source", "risk_score", "risk_level",
            "threat_type", "indicators", "recommendation",
            "timestamp", "analyzed_content",
        ]
        for field in required:
            assert field in body, f"Missing field in call result: {field}"

    def test_result_analyzed_content_is_call_id(self, client: TestClient, seed_completed_call):
        """
        Contract §1.2: for CALL source, analyzed_content must be the call_id.
        Never the full transcript.
        """
        call, _ = seed_completed_call
        resp = client.get(f"/api/calls/{call.id}/result")
        assert resp.status_code == 200
        body = resp.json()
        assert body["source"] == "CALL"
        assert body["analyzed_content"] == call.id


class TestCallEventContractCompliance:
    """
    Verify call event shape matches Backend Contract v1.0 §6.2 exactly.
    """

    def test_status_event_has_status_field_populated(
        self, client: TestClient, seed_active_call: Call
    ):
        """STATUS events must carry the status field per contract §6.2."""
        resp = client.get(f"/api/calls/{seed_active_call.id}/events?after_seq=0")
        events = resp.json()["events"]
        status_events = [e for e in events if e["type"] == "STATUS"]
        assert len(status_events) > 0
        for ev in status_events:
            assert ev["status"] is not None
            assert ev["status"] in ("RINGING", "IN_PROGRESS", "ENDED")

    def test_transcript_event_has_speaker_and_text(
        self, client: TestClient, seed_active_call: Call
    ):
        """TRANSCRIPT events must carry speaker and text per contract §6.2."""
        resp = client.get(f"/api/calls/{seed_active_call.id}/events?after_seq=0")
        events = resp.json()["events"]
        transcript_events = [e for e in events if e["type"] == "TRANSCRIPT"]
        assert len(transcript_events) > 0
        for ev in transcript_events:
            assert ev["speaker"] in ("CALLER", "USER")
            assert ev["text"] is not None

    def test_seq_starts_at_one(self, client: TestClient, seed_active_call: Call):
        """Contract §6.2: seq is monotonic per call, starts at 1."""
        resp = client.get(f"/api/calls/{seed_active_call.id}/events?after_seq=0")
        seqs = [e["seq"] for e in resp.json()["events"]]
        assert min(seqs) == 1

    def test_events_have_all_required_contract_fields(
        self, client: TestClient, seed_active_call: Call
    ):
        """Contract §6.2: every event must have call_id, seq, type, timestamp."""
        resp = client.get(f"/api/calls/{seed_active_call.id}/events?after_seq=0")
        for event in resp.json()["events"]:
            assert "call_id" in event
            assert "seq" in event
            assert "type" in event
            assert "timestamp" in event

