from fastapi.testclient import TestClient
from app.main import app
from datetime import datetime, timedelta, timezone

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

def test_add_manual_income_entry_updates_balance():
    before = client.get("/financial-state/usr_manual_entry_test").json()
    payload = {
        "user_id": "usr_manual_entry_test",
        "type": "income",
        "amount": 250.0,
        "vendor": "Freelance - Client A",
    }
    response = client.post("/entries", json=payload)
    assert response.status_code == 201
    body = response.json()
    # Server generates the event_id / source / confidence_score -- client never does.
    assert body["event_id"].startswith("evt_manual_")
    assert body["source"] == "user_input"
    assert body["confidence_score"] == 1.0
    assert body["type"] == "income"

    after = client.get("/financial-state/usr_manual_entry_test").json()
    assert after["current_balances"]["checking"] == before["current_balances"]["checking"] + 250.0

def test_add_manual_expense_entry_updates_balance():
    before = client.get("/financial-state/usr_manual_entry_test").json()
    payload = {
        "user_id": "usr_manual_entry_test",
        "type": "expense",
        "amount": 40.0,
        "vendor": "Swiggy",
    }
    response = client.post("/entries", json=payload)
    assert response.status_code == 201

    after = client.get("/financial-state/usr_manual_entry_test").json()
    assert after["current_balances"]["checking"] == before["current_balances"]["checking"] - 40.0

def test_manual_entry_rejects_non_positive_amount():
    payload = {
        "user_id": "usr_manual_entry_test",
        "type": "income",
        "amount": 0,
        "vendor": "Bad Entry",
    }
    response = client.post("/entries", json=payload)
    assert response.status_code == 422  # Pydantic validation, not a 500

def test_add_obligation_with_recurrence_reflected_in_snapshot():
    payload = {
        "user_id": "usr_recurrence_test",
        "name": "Netflix",
        "amount": 199.0,
        "due_date": datetime.now(timezone.utc).isoformat(),
        "category": "subscription",
        "recurrence": "monthly",
    }
    response = client.post("/obligations", json=payload)
    assert response.status_code == 201

    snapshot = client.get("/financial-state/usr_recurrence_test").json()
    names = [o["name"] for o in snapshot["upcoming_obligations"]]
    assert "Netflix" in names
    # recurrence itself must never leak into the locked snapshot contract
    for o in snapshot["upcoming_obligations"]:
        assert "recurrence" not in o

def test_overdue_recurring_obligation_rolls_forward_in_snapshot():
    overdue_date = datetime.now(timezone.utc) - timedelta(days=45)
    payload = {
        "user_id": "usr_overdue_test",
        "name": "Gym Membership",
        "amount": 50.0,
        "due_date": overdue_date.isoformat(),
        "category": "subscription",
        "recurrence": "monthly",
    }
    response = client.post("/obligations", json=payload)
    assert response.status_code == 201

    snapshot = client.get("/financial-state/usr_overdue_test").json()
    gym = next(o for o in snapshot["upcoming_obligations"] if o["name"] == "Gym Membership")
    rolled_due = datetime.fromisoformat(gym["due_date"].replace("Z", "+00:00"))
    assert rolled_due >= datetime.now(timezone.utc)

def test_overdue_once_obligation_does_not_roll_forward():
    overdue_date = datetime.now(timezone.utc) - timedelta(days=45)
    payload = {
        "user_id": "usr_once_test",
        "name": "One-time Fine",
        "amount": 20.0,
        "due_date": overdue_date.isoformat(),
        "category": "discretionary",
        "recurrence": "once",
    }
    response = client.post("/obligations", json=payload)
    assert response.status_code == 201

    snapshot = client.get("/financial-state/usr_once_test").json()
    fine = next(o for o in snapshot["upcoming_obligations"] if o["name"] == "One-time Fine")
    due = datetime.fromisoformat(fine["due_date"].replace("Z", "+00:00"))
    assert due < datetime.now(timezone.utc)

def test_add_goal_with_deadline_reflected_in_snapshot_without_leaking_deadline():
    payload = {
        "user_id": "usr_goal_deadline_test",
        "name": "Emergency Fund",
        "target_amount": 10000.0,
        "current_amount": 500.0,
        "priority": "high",
        "deadline": (datetime.now(timezone.utc) + timedelta(days=180)).isoformat(),
    }
    response = client.post("/goals", json=payload)
    assert response.status_code == 201

    snapshot = client.get("/financial-state/usr_goal_deadline_test").json()
    names = [g["name"] for g in snapshot["active_goals"]]
    assert "Emergency Fund" in names
    for g in snapshot["active_goals"]:
        assert "deadline" not in g

def test_user_profile_upsert_and_get():
    payload = {
        "user_id": "usr_profile_test",
        "name": "Kalyan",
        "risk_tolerance": "conservative",
        "safety_buffer": 5000.0,
        "priorities": ["build_emergency_fund", "pay_down_debt"],
        "preferred_currency": "INR",
    }
    response = client.post("/users", json=payload)
    assert response.status_code == 200
    body = response.json()
    assert body["safety_buffer"] == 5000.0
    assert body["priorities"] == ["build_emergency_fund", "pay_down_debt"]

    fetched = client.get("/users/usr_profile_test")
    assert fetched.status_code == 200
    assert fetched.json()["name"] == "Kalyan"

def test_safety_buffer_from_profile_affects_safe_to_spend():
    # Give this user a big cash balance and a large explicit safety buffer;
    # safe_to_spend must shrink to respect it instead of the 100.0 default.
    client.post("/entries", json={
        "user_id": "usr_buffer_effect_test",
        "type": "income",
        "amount": 10000.0,
        "vendor": "Salary",
    })
    client.post("/users", json={
        "user_id": "usr_buffer_effect_test",
        "risk_tolerance": "conservative",
        "safety_buffer": 9000.0,
        "priorities": [],
    })

    snapshot = client.get("/financial-state/usr_buffer_effect_test").json()
    # 10000 checking - 0 obligations - 9000 buffer = 1000
    assert snapshot["safe_to_spend"] == 1000.0

def test_get_user_profile_404_for_unknown_user():
    response = client.get("/users/usr_never_set_up_profile")
    assert response.status_code == 404
