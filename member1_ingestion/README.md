# FinSentinel - Ingestion Subsystem (Member 1)

This module is responsible for taking messy raw text (SMS, OCR receipts) and converting them into strict `NormalizedFinancialEvent` JSON objects.

## For Member 2 (Sanjani)
You DO NOT need to run this code to build your module. 
Simply consume the API contract exactly as defined in `app/models/event.py`. 
You can use the mock outputs located in `mock_data/` for your testing.

## How to Run
1. `pip install -r requirements.txt`
2. Set your `GEMINI_API_KEY` in your environment (if testing receipt parsing).
3. `uvicorn app.main:app --reload`
4. Visit `http://127.0.0.1:8000/docs` to test the API.

## How to Test
Run `pytest` in the root of this directory.

## Architecture
- **Parsers:** Regex for SMS, Gemini for Receipts.
- **Deduplication:** In-memory sliding window cache.
- **Validation:** Pydantic (Strict contract enforcement).
