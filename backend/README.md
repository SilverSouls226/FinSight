# FinSentinel Backend

FastAPI backend for the FinSentinel AI-Powered Financial Scam Interceptor.

## Setup

```bash
cd backend

# Create and activate virtualenv
python3.12 -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Copy env file (edit with your actual values)
cp .env.example .env
```

## Run (development)

```bash
source venv/bin/activate
uvicorn app.main:app --reload
```

- API: http://localhost:8000
- Swagger: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- Health: http://localhost:8000/health

## Run tests

```bash
source venv/bin/activate
python -m pytest tests/ -v
```

## Project structure

```
backend/
├── app/
│   ├── main.py          # FastAPI app factory + lifespan
│   ├── core/
│   │   ├── config.py    # Settings (pydantic-settings, reads .env)
│   │   └── errors.py    # Exception hierarchy + FastAPI handlers
│   ├── db/
│   │   ├── base.py      # SQLAlchemy engine, session, Base
│   │   └── init_db.py   # create_all on startup
│   ├── models/
│   │   ├── threat.py    # Threat ORM model
│   │   └── call.py      # Call + CallEvent ORM models
│   ├── schemas/
│   │   ├── common.py    # Source, RiskLevel, EventType enums + ErrorResponse
│   │   ├── threat.py    # ThreatResult, AnalyzeRequest
│   │   └── call.py      # CallEventOut, CallEventsResponse, ActiveCallResponse
│   ├── services/
│   │   ├── analysis.py  # AnalysisService stub (Skandan plugs in AI here)
│   │   ├── threat.py    # ThreatService (CRUD, device-scoped history)
│   │   └── call.py      # CallService (events, active call, result)
│   └── api/
│       ├── deps.py      # FastAPI dependencies (DB session, device_id)
│       └── v1/
│           ├── router.py
│           ├── analyze.py   # POST /api/analyze
│           ├── threats.py   # GET /api/threats, GET /api/threats/{id}
│           └── calls.py     # GET /api/calls/*
└── tests/
    ├── conftest.py      # In-memory DB fixtures + seed helpers (tests only)
    ├── test_analyze.py
    ├── test_threats.py
    └── test_calls.py
```

## Integration notes

**For Skandan (AI):** Replace `AnalysisService._stub_analyze()` in
`app/services/analysis.py` with your Groq/LLM call.
The method signature and return type (`ThreatResult`) must not change.

**For Sanjani (Twilio):** Use `CallService.append_event()` in
`app/services/call.py` to push events from Twilio Media Streams.
Call records can be created directly via the ORM `Call` model.

**For Kalyan (Flutter):** See `docs/backend-contract.md` for the
full frozen API contract. All endpoints are live at `/api/...`.
