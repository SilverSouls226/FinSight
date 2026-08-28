# FinSentinel AI Brain Subsystem Integration Guide (Sameer)

This guide documents the Autonomous Decision / AI Brain subsystem implemented for Member 3 (Sameer).

## System Architecture

The subsystem processes data sequentially through a deterministic pipeline before invoking the Groq LLM:

```
Financial State Snapshot (Contract 2)
              ↓
      Risk Engine (Deterministic Rules)
              ↓
  Goal Arbitration (Prioritization Engine)
              ↓
 Intervention Gate (Severity Categorization)
              ↓
Groq Reasoner (Structured JSON Explanation) / Deterministic Fallback
              ↓
   Contextual Intervention (Contract 3)
```

## API Endpoint

* **URL:** `POST /api/evaluate/{user_id}`
* **Host Port:** `8000` (FastAPI backend default)
* **Headers:**
  - `Content-Type: application/json`

---

## JSON Contracts (Frozen)

### Input Schema (`FinancialStateSnapshot`)

Sent by Member 2 (Sanjani) or simulator:

```json
{
  "user_id": "usr_123",
  "last_updated": "2026-08-28T10:05:00Z",
  "current_balances": {
    "checking": 150.00,
    "savings": 5000.00
  },
  "projected_income_30_days": {
    "estimated_amount": 800.00,
    "variance": 100.00
  },
  "upcoming_obligations": [
    {
      "name": "Apartment Rent",
      "amount": 1100.00,
      "due_date": "2026-09-01T00:00:00Z",
      "category": "fixed_essential"
    }
  ],
  "active_goals": [
    {
      "name": "Emergency Fund",
      "target_amount": 10000.00,
      "current_amount": 5000.00,
      "priority": "high"
    }
  ],
  "safe_to_spend": 0.00,
  "confidence_score": 1.0,
  "user_profile": {
    "risk_tolerance": "moderate",
    "minimum_liquidity_threshold": 500.00
  }
}
```

### Output Schema (`ContextualIntervention`)

Consumed by Member 4 (Kalyan):

```json
{
  "intervention_id": "int_e990bfca",
  "user_id": "usr_123",
  "timestamp": "2026-08-28T08:46:29Z",
  "severity": "high",
  "title": "Insufficient Checking for Apartment Rent",
  "summary": "Your checking balance is $150.00, but Apartment Rent of $1100.00 is due in 5 days.",
  "explanation": "DECISION TRACE:\n- CONSTRAINT: Apartment Rent of $1100.00 due soon.\n- OBSERVATION: Checking balance ($150.00) is insufficient.\n- USER PREFERENCE: Liquidity and mandatory obligations have higher priority than preserving emergency fund targets.\n- DECISION: Recommend transfer of $950.00 from Emergency Fund to Checking.\n- EXPECTED EFFECT: Shortfall risk decreases; obligation is covered.",
  "suggested_actions": [
    {
      "action_type": "transfer",
      "description": "Transfer $950.00 from your Emergency Fund to Checking to cover the gap for Apartment Rent.",
      "requires_user_approval": true
    }
  ],
  "requires_user_approval": true
}
```

---

## Groq Prompt & Safety Constraints

To ensure Groq does not calculate balances or hallucinate transactions, we invoke it with:
1. Strict pre-computed facts payload.
2. The prompt forces Groq to match the response schema exactly.
3. System prompt strictly locks the model from inventing financial facts.
4. Local template fallback runs immediately if `GROQ_API_KEY` is empty, expired, rate-limited, or outputs malformed content.

---

## Local Verification / Run Tests

To run the Pytest suite verifying all behaviors:
```bash
cd backend
venv/bin/python -m pytest tests/test_brain.py
```
To run the uvicorn API server locally:
```bash
cd backend
venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```
