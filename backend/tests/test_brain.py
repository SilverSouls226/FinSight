import json
from unittest.mock import patch, MagicMock
import httpx
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.schemas.financial import FinancialStateSnapshot, ContextualIntervention
from app.services.brain.risk_engine import RiskEngine
from app.services.brain.goal_arbitration import GoalArbitration
from app.services.brain.intervention_gate import InterventionGate
from app.services.brain.groq_reasoner import GroqReasoner
from tests.fixtures_financial import (
    low_risk_state,
    high_shortfall_risk,
    income_drop,
    rent_collision,
    competing_goals,
    low_confidence_state,
    low_impact_state,
    critical_case
)

client = TestClient(app)


# ── Test Suite for Engine Components ──────────────────────────────────────────

def test_risk_engine_low_risk():
    snapshot = FinancialStateSnapshot(**low_risk_state)
    engine = RiskEngine()
    issues = engine.detect_issues(snapshot)
    
    # Low risk state should have no critical conflicts or shortfalls
    assert len(issues) == 0 or all(i.issue_type not in ("cash_shortfall", "obligation_conflict") for i in issues)


def test_risk_engine_rent_collision():
    snapshot = FinancialStateSnapshot(**rent_collision)
    engine = RiskEngine()
    issues = engine.detect_issues(snapshot)
    
    # Should detect checking account collision with fixed essential rent bill
    conflict_issues = [i for i in issues if i.issue_type == "obligation_conflict"]
    assert len(conflict_issues) > 0
    assert conflict_issues[0].metadata["obligation_name"] == "Apartment Rent"
    assert conflict_issues[0].financial_impact == 1100.00 - 150.00


def test_goal_arbitration_competing_goals():
    snapshot = FinancialStateSnapshot(**competing_goals)
    engine = RiskEngine()
    issues = engine.detect_issues(snapshot)
    
    arbitration = GoalArbitration()
    result = arbitration.arbitrate(snapshot, issues)
    
    # Should suggest transfer from emergency fund (liquidity priority)
    transfer_action = next((a for a in result.actions if a.action_type == "transfer"), None)
    assert transfer_action is not None
    assert "Emergency Fund" in transfer_action.description
    
    # Should suggest budget cut to discretionary spend
    cut_action = next((a for a in result.actions if a.action_type == "budget_cut"), None)
    assert cut_action is not None
    
    # Should suggest pausing low priority goals (Vacation Trip)
    pause_action = next((a for a in result.actions if a.action_type == "pause_goal"), None)
    assert pause_action is not None
    assert "Vacation Trip" in pause_action.description


def test_intervention_gate_low_confidence():
    snapshot = FinancialStateSnapshot(**low_confidence_state)
    engine = RiskEngine()
    issues = engine.detect_issues(snapshot)
    
    gate = InterventionGate()
    decision = gate.evaluate(snapshot, issues)
    
    # Low confidence score (<0.7) should degrade the alert severity to prevent fatigue (MONITOR/IGNORE)
    assert decision in ("MONITOR", "IGNORE")


def test_intervention_gate_fatigue_prevention():
    snapshot = FinancialStateSnapshot(**low_impact_state)
    engine = RiskEngine()
    issues = engine.detect_issues(snapshot)
    
    gate = InterventionGate()
    decision = gate.evaluate(snapshot, issues)
    
    # Negligible shortfall under $20 should be ignored
    assert decision == "IGNORE"


def test_intervention_gate_critical():
    snapshot = FinancialStateSnapshot(**critical_case)
    engine = RiskEngine()
    issues = engine.detect_issues(snapshot)
    
    gate = InterventionGate()
    decision = gate.evaluate(snapshot, issues)
    
    # Highly urgent and probable cash shortfall should trigger CRITICAL
    assert decision == "CRITICAL"


def test_risk_tolerance_gate_differences():
    # Setup a state where Rent is due in 7 days, checking is short by $400, probability is 0.40
    snapshot_data = dict(rent_collision)
    # 7 days to due
    from datetime import datetime, timezone, timedelta
    snapshot_data["upcoming_obligations"][0]["due_date"] = (datetime.now(timezone.utc) + timedelta(days=7)).isoformat()
    
    # Test conservative user
    snapshot_data["user_profile"] = {"risk_tolerance": "conservative", "minimum_liquidity_threshold": 500.00}
    snapshot_con = FinancialStateSnapshot(**snapshot_data)
    engine = RiskEngine()
    issues_con = engine.detect_issues(snapshot_con)
    # Inject deterministic probability to bypass variance calculations
    for i in issues_con:
        i.probability = 0.40
        i.urgency_days = 7
    gate = InterventionGate()
    decision_con = gate.evaluate(snapshot_con, issues_con)
    
    # Test aggressive user
    snapshot_data["user_profile"] = {"risk_tolerance": "aggressive", "minimum_liquidity_threshold": 500.00}
    snapshot_agg = FinancialStateSnapshot(**snapshot_data)
    issues_agg = engine.detect_issues(snapshot_agg)
    for i in issues_agg:
        i.probability = 0.40
        i.urgency_days = 7
    decision_agg = gate.evaluate(snapshot_agg, issues_agg)
    
    # Conservative user triggers NOTIFY/CRITICAL because threshold is wider, Aggressive maps to MONITOR/IGNORE
    assert decision_con in ("NOTIFY", "CRITICAL")
    assert decision_agg in ("MONITOR", "IGNORE")


# ── Test Suite for Reasoner & API Endpoints ─────────────────────────────────

def test_fallback_generator():
    snapshot = FinancialStateSnapshot(**rent_collision)
    engine = RiskEngine()
    issues = engine.detect_issues(snapshot)
    arbitration = GoalArbitration().arbitrate(snapshot, issues)
    
    reasoner = GroqReasoner()
    intervention = reasoner._generate_fallback(snapshot, issues, arbitration, "CRITICAL")
    
    # Verify the fallback output strictly matches the ContextualIntervention contract
    assert isinstance(intervention, ContextualIntervention)
    assert intervention.user_id == "usr_123"
    assert intervention.severity == "high"
    assert "DECISION TRACE:" in intervention.explanation
    assert len(intervention.suggested_actions) > 0
    assert intervention.requires_user_approval is True


@patch("httpx.Client.post")
def test_groq_reasoner_success(mock_post):
    # Mock successful Groq API response returning strict JSON content
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {
        "choices": [
            {
                "message": {
                    "content": json.dumps({
                        "intervention_id": "int_groq_1",
                        "title": "Groq Rent Alert",
                        "summary": "Transfer funds from Emergency Fund.",
                        "explanation": "Groq-generated explanation here.",
                        "requires_user_approval": True
                    })
                }
            }
        ]
    }
    mock_post.return_value = mock_response
    
    snapshot = FinancialStateSnapshot(**rent_collision)
    engine = RiskEngine()
    issues = engine.detect_issues(snapshot)
    arbitration = GoalArbitration().arbitrate(snapshot, issues)
    
    reasoner = GroqReasoner(api_key="mock_key")
    intervention = reasoner.generate_intervention(snapshot, issues, arbitration, "CRITICAL")
    
    assert intervention.title == "Groq Rent Alert"
    assert intervention.explanation == "Groq-generated explanation here."
    assert intervention.severity == "high"
    # Ensure backend forces the deterministic actions even if LLM tried to alter them
    assert len(intervention.suggested_actions) == len(arbitration.actions)


@patch("httpx.Client.post")
def test_groq_reasoner_unavailable(mock_post):
    # Mock Groq API failure (e.g. Service Unavailable)
    mock_post.side_effect = httpx.HTTPStatusError("503 Service Unavailable", request=MagicMock(), response=MagicMock())
    
    snapshot = FinancialStateSnapshot(**rent_collision)
    engine = RiskEngine()
    issues = engine.detect_issues(snapshot)
    arbitration = GoalArbitration().arbitrate(snapshot, issues)
    
    reasoner = GroqReasoner(api_key="mock_key")
    intervention = reasoner.generate_intervention(snapshot, issues, arbitration, "CRITICAL")
    
    # Should fall back to the deterministic local engine instead of crashing
    assert isinstance(intervention, ContextualIntervention)
    assert intervention.severity == "high"
    assert "DECISION TRACE:" in intervention.explanation


@patch("httpx.Client.post")
def test_groq_reasoner_malformed_json(mock_post):
    # Mock Groq API returning plain text instead of valid JSON
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {
        "choices": [
            {
                "message": {
                    "content": "This is not a JSON object!"
                }
            }
        ]
    }
    mock_post.return_value = mock_response
    
    snapshot = FinancialStateSnapshot(**rent_collision)
    engine = RiskEngine()
    issues = engine.detect_issues(snapshot)
    arbitration = GoalArbitration().arbitrate(snapshot, issues)
    
    reasoner = GroqReasoner(api_key="mock_key")
    intervention = reasoner.generate_intervention(snapshot, issues, arbitration, "CRITICAL")
    
    # Should fall back to the deterministic local engine instead of crashing
    assert isinstance(intervention, ContextualIntervention)
    assert "DECISION TRACE:" in intervention.explanation


# ── Test Suite for FastAPI Endpoint ──────────────────────────────────────────

def test_api_evaluate_success():
    # Evaluate endpoint handles low-risk (ignores/returns safe fallback)
    response = client.post("/api/evaluate/usr_123", json=low_risk_state)
    assert response.status_code == 200
    data = response.json()
    assert data["user_id"] == "usr_123"
    assert data["severity"] == "info"
    assert len(data["suggested_actions"]) == 0

    # Evaluate endpoint handles high risk (critical case)
    response = client.post("/api/evaluate/usr_123", json=rent_collision)
    assert response.status_code == 200
    data = response.json()
    assert data["user_id"] == "usr_123"
    assert data["severity"] == "high"
    assert len(data["suggested_actions"]) > 0


def test_api_evaluate_user_id_mismatch():
    response = client.post("/api/evaluate/usr_different", json=low_risk_state)
    assert response.status_code == 400
    assert "User ID mismatch" in response.json()["detail"]


def test_api_evaluate_invalid_fields():
    invalid_state = dict(low_risk_state)
    # Remove a required field
    del invalid_state["current_balances"]
    
    response = client.post("/api/evaluate/usr_123", json=invalid_state)
    assert response.status_code == 422  # Pydantic validation error


def test_inr_currency_formatting():
    # Construct a snapshot with INR currency
    inr_state = dict(rent_collision)
    inr_state["currency"] = "INR"
    
    snapshot = FinancialStateSnapshot(**inr_state)
    issues = RiskEngine().detect_issues(snapshot)
    
    # Risk engine descriptions must contain ₹ symbol
    conflict_issues = [i for i in issues if i.issue_type == "obligation_conflict"]
    assert len(conflict_issues) > 0
    assert "₹" in conflict_issues[0].description
    assert "$" not in conflict_issues[0].description
    
    # Arbitration descriptions must contain ₹ symbol
    arbitration = GoalArbitration().arbitrate(snapshot, issues)
    transfer_action = next((a for a in arbitration.actions if a.action_type == "transfer"), None)
    assert transfer_action is not None
    assert "₹" in transfer_action.description
    assert "$" not in transfer_action.description

