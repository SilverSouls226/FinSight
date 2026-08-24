"""
tests/test_threats.py

Tests for GET /api/threats and GET /api/threats/{id}
"""
import pytest
from fastapi.testclient import TestClient

from app.models.threat import Threat
from tests.conftest import DEVICE_A, HEADERS_A, HEADERS_B


class TestThreatHistory:

    def test_empty_history(self, client: TestClient):
        """Fresh device should get empty history."""
        resp = client.get("/api/threats", headers=HEADERS_A)
        assert resp.status_code == 200
        body = resp.json()
        assert body["threats"] == []
        assert body["total"] == 0

    def test_history_returns_own_threats(self, client: TestClient, seed_threat: Threat):
        resp = client.get("/api/threats", headers=HEADERS_A)
        assert resp.status_code == 200
        body = resp.json()
        assert body["total"] == 1
        assert body["threats"][0]["id"] == seed_threat.id

    def test_history_device_isolation(self, client: TestClient, seed_threat: Threat):
        """Device B must not see Device A's threats."""
        resp = client.get("/api/threats", headers=HEADERS_B)
        assert resp.status_code == 200
        assert resp.json()["threats"] == []

    def test_history_limit_parameter(self, client: TestClient):
        """limit query param should cap results."""
        # Submit 5 threats for device A
        for i in range(5):
            client.post(
                "/api/analyze",
                json={"source": "SMS", "content": f"OTP bank urgent message {i}", "metadata": {}},
                headers=HEADERS_A,
            )
        resp = client.get("/api/threats?limit=3", headers=HEADERS_A)
        assert resp.status_code == 200
        body = resp.json()
        assert len(body["threats"]) == 3

    def test_history_newest_first(self, client: TestClient):
        """Results should be ordered newest first."""
        for i in range(3):
            client.post(
                "/api/analyze",
                json={"source": "SMS", "content": f"bank otp urgent {i}", "metadata": {}},
                headers=HEADERS_A,
            )
        resp = client.get("/api/threats", headers=HEADERS_A)
        threats = resp.json()["threats"]
        timestamps = [t["timestamp"] for t in threats]
        assert timestamps == sorted(timestamps, reverse=True)

    def test_history_missing_device_id_returns_422(self, client: TestClient):
        resp = client.get("/api/threats")
        assert resp.status_code == 422

    def test_history_invalid_limit_returns_422(self, client: TestClient):
        resp = client.get("/api/threats?limit=0", headers=HEADERS_A)
        assert resp.status_code == 422


class TestGetThreatById:

    def test_get_by_id_success(self, client: TestClient, seed_threat: Threat):
        resp = client.get(f"/api/threats/{seed_threat.id}")
        assert resp.status_code == 200
        body = resp.json()
        assert body["id"] == seed_threat.id
        assert body["source"] == "SMS"
        assert body["risk_score"] == 85

    def test_get_by_id_not_found(self, client: TestClient):
        resp = client.get("/api/threats/thr_sms_nonexistent")
        assert resp.status_code == 404
        body = resp.json()
        # Must follow the error envelope: {"error": {"code": ..., "message": ...}}
        assert "error" in body
        assert body["error"]["code"] == "NOT_FOUND"

    def test_threat_result_schema_completeness(self, client: TestClient, seed_threat: Threat):
        """All required ThreatResult fields must be present."""
        resp = client.get(f"/api/threats/{seed_threat.id}")
        body = resp.json()
        required_fields = [
            "id", "source", "risk_score", "risk_level",
            "threat_type", "indicators", "recommendation",
            "timestamp", "analyzed_content",
        ]
        for field in required_fields:
            assert field in body, f"Missing required field: {field}"

    def test_risk_score_is_integer_in_range(self, client: TestClient, seed_threat: Threat):
        resp = client.get(f"/api/threats/{seed_threat.id}")
        score = resp.json()["risk_score"]
        assert isinstance(score, int)
        assert 0 <= score <= 100

    def test_risk_level_is_valid_enum(self, client: TestClient, seed_threat: Threat):
        resp = client.get(f"/api/threats/{seed_threat.id}")
        level = resp.json()["risk_level"]
        assert level in ("LOW", "MEDIUM", "HIGH", "CRITICAL")
        # UNKNOWN must never be returned by the backend
        assert level != "UNKNOWN"
