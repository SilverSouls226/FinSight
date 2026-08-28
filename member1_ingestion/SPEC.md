# SPEC.md - Member 1 (Ingestion)

## 1. Goal
Build the Financial Data Ingestion subsystem for FinSentinel. Turn messy financial inputs (SMS, receipts, bank CSVs) into reliable `Normalized Financial Events`.

## 2. Strict API Contract
Output MUST strictly adhere to this JSON format. No new fields. No renamed fields.

```json
{
  "event_id": "...",
  "user_id": "...",
  "timestamp": "...",
  "source": "sms | receipt | bank_api | user_input",
  "type": "income | expense | bill_due",
  "amount": 0.0,
  "currency": "...",
  "vendor": "...",
  "confidence_score": 0.0,
  "is_recurring": false
}
```

## 3. Data Quality Rules
- Handle incomplete, duplicated, delayed, inconsistent, and noisy data.
- NEVER silently convert uncertain information into a confirmed fact. Use `confidence_score` (e.g., `< 1.0`) for OCR or inferred SMS data.
- Deduplication: Multiple sources (SMS + Bank + Receipt) representing the same transaction must be deduplicated into a single event.

## 4. Tech Stack & Integration Rules
- Python, FastAPI, Pydantic, pytest.
- Gemini API (ONLY for understanding messy visual/textual data, not for math/logic).
- SQLite (Only if strictly required for local testing, otherwise use in-memory).
- Integration: Provide a `POST /ingest` endpoint. Output JSON. Do NOT depend on Member 2's code. Mock-first development.
