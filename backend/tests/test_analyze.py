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


class TestAnalyzeContractCompliance:
    """
    Verify that POST /api/analyze returns objects that match all contract §1 fields.
    These tests exist to catch schema drift early.
    """

    _REQUIRED_FIELDS = [
        "id", "source", "risk_score", "risk_level",
        "threat_type", "indicators", "recommendation",
        "timestamp", "analyzed_content",
    ]

    def test_all_contract_fields_present_in_response(self, client: TestClient):
        """Response must include every field from contract §1.1."""
        resp = client.post(
            "/api/analyze",
            json={"source": "SMS", "content": "Urgent: your OTP required", "metadata": {}},
            headers=HEADERS_A,
        )
        assert resp.status_code == 200
        data = resp.json()
        for field in self._REQUIRED_FIELDS:
            assert field in data, f"Missing required contract field: {field}"

    def test_risk_score_is_integer_not_float(self, client: TestClient):
        """Contract §1.1: risk_score is integer 0–100, not a float."""
        resp = client.post(
            "/api/analyze",
            json={"source": "SMS", "content": "Your account is blocked. OTP required.", "metadata": {}},
            headers=HEADERS_A,
        )
        assert resp.status_code == 200
        score = resp.json()["risk_score"]
        assert isinstance(score, int)
        assert 0 <= score <= 100

    def test_risk_level_is_valid_enum(self, client: TestClient):
        """Backend must only emit LOW | MEDIUM | HIGH | CRITICAL — never UNKNOWN."""
        resp = client.post(
            "/api/analyze",
            json={"source": "LINK", "content": "http://phishing-site.xyz/login", "metadata": {}},
            headers=HEADERS_A,
        )
        assert resp.status_code == 200
        assert resp.json()["risk_level"] in ("LOW", "MEDIUM", "HIGH", "CRITICAL")

    def test_indicators_is_list_of_strings(self, client: TestClient):
        """Contract §1.1: indicators is string[] — not objects, not weighted."""
        resp = client.post(
            "/api/analyze",
            json={"source": "SMS", "content": "OTP bank verification urgent", "metadata": {}},
            headers=HEADERS_A,
        )
        assert resp.status_code == 200
        indicators = resp.json()["indicators"]
        assert isinstance(indicators, list)
        assert all(isinstance(i, str) for i in indicators)

    def test_analyzed_content_matches_submitted_content(self, client: TestClient):
        """Contract §1.2: for SMS, analyzed_content = the full message text as submitted."""
        content = "Your HDFC account will be blocked. Call now."
        resp = client.post(
            "/api/analyze",
            json={"source": "SMS", "content": content, "metadata": {}},
            headers=HEADERS_A,
        )
        assert resp.status_code == 200
        assert resp.json()["analyzed_content"] == content

    def test_threat_id_format(self, client: TestClient):
        """id must be stable and unique per contract §1.1."""
        resp = client.post(
            "/api/analyze",
            json={"source": "QR", "content": "http://pay.xyz/fake", "metadata": {}},
            headers=HEADERS_A,
        )
        assert resp.status_code == 200
        threat_id = resp.json()["id"]
        assert threat_id.startswith("thr_qr_")
        assert len(threat_id) > 8


class TestAnalyzeFailure:
    """
    Tests that verify contract §5.2: analysis failure = error, never fake LOW.
    """

    def test_analysis_failure_returns_502_error_envelope(self, client: TestClient):
        """
        When the analysis engine fails, the response must be a 502 with the
        standard error envelope — never a ThreatResult with risk_level=LOW.
        Per contract §5.2.
        """
        from unittest.mock import patch
        from app.core.errors import AnalysisFailedError

        with patch(
            "app.api.v1.analyze.analysis_service.analyze",
            side_effect=AnalysisFailedError("AI engine unavailable"),
        ):
            resp = client.post(
                "/api/analyze",
                json={"source": "SMS", "content": "Test message", "metadata": {}},
                headers=HEADERS_A,
            )

        assert resp.status_code == 502
        body = resp.json()
        assert "error" in body
        assert body["error"]["code"] == "ANALYSIS_FAILED"
        assert "message" in body["error"]

    def test_analysis_failure_does_not_persist_threat(self, client: TestClient):
        """On failure, no threat record should be written to the DB."""
        from unittest.mock import patch
        from app.core.errors import AnalysisFailedError

        with patch(
            "app.api.v1.analyze.analysis_service.analyze",
            side_effect=AnalysisFailedError("Engine down"),
        ):
            client.post(
                "/api/analyze",
                json={"source": "SMS", "content": "Test message", "metadata": {}},
                headers=HEADERS_A,
            )

        # History must be empty — failure must not have written a row
        history = client.get("/api/threats", headers=HEADERS_A)
        assert history.json()["threats"] == []

    def test_error_response_has_no_risk_level_field(self, client: TestClient):
        """Error body must NOT contain risk_level — that would be a fake result."""
        from unittest.mock import patch
        from app.core.errors import AnalysisFailedError

        with patch(
            "app.api.v1.analyze.analysis_service.analyze",
            side_effect=AnalysisFailedError("Unavailable"),
        ):
            resp = client.post(
                "/api/analyze",
                json={"source": "SMS", "content": "Test", "metadata": {}},
                headers=HEADERS_A,
            )

        body = resp.json()
        assert "risk_level" not in body
        assert "risk_score" not in body
