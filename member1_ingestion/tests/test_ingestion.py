from fastapi.testclient import TestClient
from app.main import app
import pytest

client = TestClient(app)

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"

def test_ingest_valid_expense_sms():
    payload = {
        "user_id": "usr_test1",
        "source": "sms",
        "raw_text": "Rs 500 debited from a/c **1234 to Zomato."
    }
    response = client.post("/ingest", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["type"] == "expense"
    assert data["amount"] == 500.0
    assert data["vendor"] == "Zomato"
    assert data["currency"] == "INR"
    assert data["confidence_score"] == 0.9

def test_ingest_valid_income_sms():
    payload = {
        "user_id": "usr_test1",
        "source": "sms",
        "raw_text": "Credited INR 1,500.50 to a/c **1234 from Employer."
    }
    response = client.post("/ingest", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["type"] == "income"
    assert data["amount"] == 1500.50
    assert data["vendor"] == "Employer"

def test_ingest_invalid_sms():
    payload = {
        "user_id": "usr_test1",
        "source": "sms",
        "raw_text": "Happy birthday mom!"
    }
    response = client.post("/ingest", json=payload)
    assert response.status_code == 422 # Parsing fails

def test_deduplication():
    # Send same exact SMS twice
    payload = {
        "user_id": "usr_test2",
        "source": "sms",
        "raw_text": "Rs 100 debited to Steam."
    }
    response1 = client.post("/ingest", json=payload)
    assert response1.status_code == 200
    
    response2 = client.post("/ingest", json=payload)
    assert response2.status_code == 422 # Duplicate detected

def test_invalid_source():
    payload = {
        "user_id": "usr_test1",
        "source": "magic_crystal_ball",
        "raw_text": "Rs 500 debited"
    }
    response = client.post("/ingest", json=payload)
    assert response.status_code == 400
