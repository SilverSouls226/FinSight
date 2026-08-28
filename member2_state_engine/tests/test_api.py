from fastapi.testclient import TestClient
from app.main import app
from datetime import datetime, timezone

client = TestClient(app)

def test_read_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Financial State Engine is running!"}

def test_add_obligation():
    payload = {
        "user_id": "usr_123",
        "name": "Test Rent",
        "amount": 1000.0,
        "due_date": datetime.now(timezone.utc).isoformat(),
        "category": "fixed"
    }
    response = client.post("/obligations", json=payload)
    assert response.status_code == 201

def test_add_goal():
    payload = {
        "user_id": "usr_123",
        "name": "Savings",
        "target_amount": 5000.0,
        "current_amount": 1000.0,
        "priority": "high"
    }
    response = client.post("/goals", json=payload)
    assert response.status_code == 201

def test_ingest_event():
    payload = {
        "event_id": "evt_test_001",
        "user_id": "usr_123",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "source": "sms",
        "type": "income",
        "amount": 2500.0,
        "currency": "INR",
        "vendor": "Client",
        "confidence_score": 1.0,
        "is_recurring": False
    }
    response = client.post("/events", json=payload)
    assert response.status_code == 201

def test_get_financial_state():
    response = client.get("/financial-state/usr_123")
    assert response.status_code == 200
    data = response.json()
    assert data["user_id"] == "usr_123"
    assert "safe_to_spend" in data
    assert "projected_income_30_days" in data
    assert "upcoming_obligations" in data

def test_simulate():
    response = client.post("/simulate/usr_123?proposed_expense=500.0")
    assert response.status_code == 200
    data = response.json()
    assert "base_shortfall_risk_percent" in data
    assert "new_shortfall_risk_percent" in data
    assert data["new_shortfall_risk_percent"] >= data["base_shortfall_risk_percent"]
