# ROADMAP.md - Member 1 (Ingestion)

## Phase 1: Foundation & Contract Enforcement
- [x] Create Python project structure (`app/`, `tests/`, `mock_data/`).
- [x] Setup `requirements.txt`.
- [x] Define `NormalizedFinancialEvent` Pydantic model to strictly lock the API contract.

## Phase 2: The Parsing Engines (Perception)
- [x] Implement `sms_parser.py`: Regex extraction for bank SMS formats.
- [x] Implement `gemini_parser.py`: Gemini prompt integration for receipt OCR/text extraction.

## Phase 3: Business Logic (Deduplication & Confidence)
- [x] Implement `normalizer.py`: Orchestrates parsing and assigns base `confidence_score`.
- [x] Implement `deduplication.py`: Sliding window/cache to merge duplicate events across sources.

## Phase 4: REST API Integration
- [x] Implement `main.py` (FastAPI): Expose `POST /ingest` endpoint.
- [x] Validate that endpoint output strictly matches the Pydantic schema.

## Phase 5: Testing & Documentation (Definition of Done)
- [x] Create comprehensive `mock_data/` (clean, noisy, duplicates).
- [x] Write `pytest` suite for all parsers, deduplication, and API endpoints.
- [x] Write `README.md` containing run instructions for Sanjani.
