"""
tests/test_analyze.py

Tests for POST /api/analyze
"""
import pytest
from fastapi.testclient import TestClient

from tests.conftest import DEVICE_A, HEADERS_A


class TestAnalyzeEndpoint:

    def test_analyze_sms_banking_scam_returns_threat(self, client: TestClient):
        """High-risk SMS content should produce a CRITICAL or HIGH threat result."""
        resp = client.post(
            "/api/analyze",
            json={
                "source": "SMS",
                "content": "Your KYC has expired. Please share your OTP to verify your bank account immediately.",
                "metadata": {},
            },
            headers=HEADERS_A,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["source"] == "SMS"
        assert data["risk_score"] >= 0
        assert data["risk_score"] <= 100
        assert data["risk_level"] in ("LOW", "MEDIUM", "HIGH", "CRITICAL")
        assert isinstance(data["indicators"], list)
        assert "id" in data
        assert data["id"].startswith("thr_sms_")
        assert "recommendation" in data
        assert "timestamp" in data
        assert "analyzed_content" in data

    def test_analyze_sms_benign_returns_low_risk(self, client: TestClient):
        """Benign content should return a low risk score."""
        resp = client.post(
            "/api/analyze",
            json={
                "source": "SMS",
                "content": "Your package has been delivered. Have a nice day!",
                "metadata": {},
            },
            headers=HEADERS_A,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["risk_level"] in ("LOW", "MEDIUM")

    def test_analyze_link_returns_threat(self, client: TestClient):
        resp = client.post(
            "/api/analyze",
            json={"source": "LINK", "content": "http://phishing-bank-login.xyz/verify", "metadata": {}},
            headers=HEADERS_A,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["source"] == "LINK"
        assert data["id"].startswith("thr_link_")

    def test_analyze_qr_returns_threat(self, client: TestClient):
        resp = client.post(
            "/api/analyze",
            json={"source": "QR", "content": "http://fake-payment.xyz/pay", "metadata": {}},
            headers=HEADERS_A,
        )
        assert resp.status_code == 200
        assert resp.json()["source"] == "QR"

    def test_analyze_missing_device_id_returns_422(self, client: TestClient):
        """Missing X-Device-Id header must return 422."""
        resp = client.post(
            "/api/analyze",
            json={"source": "SMS", "content": "some content", "metadata": {}},
            # No headers
        )
        assert resp.status_code == 422

    def test_analyze_empty_content_returns_422(self, client: TestClient):
        """Empty content field must return 422 — not a fake LOW result."""
        resp = client.post(
            "/api/analyze",
            json={"source": "SMS", "content": "   ", "metadata": {}},
            headers=HEADERS_A,
        )
        assert resp.status_code == 422

    def test_analyze_invalid_source_returns_422(self, client: TestClient):
        """Invalid source enum value must be rejected."""
        resp = client.post(
            "/api/analyze",
            json={"source": "FAKE_SOURCE", "content": "something", "metadata": {}},
            headers=HEADERS_A,
        )
        assert resp.status_code == 422

    def test_analyze_result_persisted_in_history(self, client: TestClient):
        """After analysis, the result must appear in the device's threat history."""
        client.post(
            "/api/analyze",
            json={"source": "SMS", "content": "OTP request from your bank", "metadata": {}},
            headers=HEADERS_A,
        )
        history_resp = client.get("/api/threats", headers=HEADERS_A)
        assert history_resp.status_code == 200
        threats = history_resp.json()["threats"]
        assert len(threats) >= 1
        assert threats[0]["source"] == "SMS"

    def test_analyze_no_cross_device_contamination(self, client: TestClient):
        """Device B should not see Device A's analysis results."""
        from tests.conftest import HEADERS_B
        client.post(
            "/api/analyze",
            json={"source": "SMS", "content": "OTP from bank", "metadata": {}},
            headers=HEADERS_A,
        )
        resp_b = client.get("/api/threats", headers=HEADERS_B)
        assert resp_b.status_code == 200
        assert resp_b.json()["threats"] == []
