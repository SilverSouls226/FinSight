# FinSentinel Backend

FastAPI + SQLite backend for the AI-Powered Real-Time Financial Scam Interceptor.

**Branch:** `feature/backend`  
**Owner:** Sameer (backend + integration)  
**Contract:** `docs/backend-contract.md` — Backend Contract v1.0 by Kalyan — READ-ONLY

---

## Quick Start

```bash
cd backend
python3.12 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env          # no real credentials needed for Day 1/2
uvicorn app.main:app --reload
```

- **Swagger UI:** http://localhost:8000/docs
- **ReDoc:** http://localhost:8000/redoc
- **Health:** http://localhost:8000/health → `{"status": "ok"}`

---

## Running Tests

```bash
cd backend
source venv/bin/activate
python -m pytest tests/ -v
```

Tests use an in-memory SQLite database and never touch the production `finsentinel.db`.

---

## API Reference

All endpoints match **Backend Contract v1.0** exactly.  
Do not modify endpoint names, field names, or enum values without a team contract update.

### POST /api/analyze

Analyze SMS text, a URL, a QR payload, or a link for scam threat.

```http
POST /api/analyze
Content-Type: application/json
X-Device-Id: <device-uuid>

{
  "source": "SMS",
  "content": "URGENT: Your HDFC account will be BLOCKED. Call 1800-xxx.",
  "metadata": {"sender": "VM-HDFCBK"}
}
```

Response `200`:
```json
{
  "id": "thr_sms_9f2a41b8",
  "source": "SMS",
  "risk_score": 97,
  "risk_level": "CRITICAL",
  "threat_type": "Banking Scam",
  "indicators": ["Bank impersonation", "OTP request", "Urgency"],
  "recommendation": "Do not share your OTP. No bank will ever ask for it.",
  "timestamp": "2026-08-24T09:14:22Z",
  "analyzed_content": "URGENT: Your HDFC account will be BLOCKED. Call 1800-xxx."
}
```

Error response (analysis failure):
```json
{
  "error": {
    "code": "ANALYSIS_FAILED",
    "message": "Analysis engine encountered an unexpected error: ..."
  }
}
```

**Rule:** If analysis fails, the backend returns an error — **never** a result with `risk_level: LOW`.

---

### GET /api/threats

Device-scoped threat history, newest first.

```http
GET /api/threats?limit=50
X-Device-Id: <device-uuid>
```

Response `200`:
```json
{
  "threats": [ { ...ThreatResult... }, ... ],
  "total": 3
}
```

---

### GET /api/threats/{id}

Single threat lookup by ID.

```http
GET /api/threats/thr_sms_9f2a41b8
```

Returns `ThreatResult` or `404`.

---

### GET /api/calls/active

Returns the currently active call, or null.

```http
GET /api/calls/active
```

Response `200`:
```json
{"call_id": "call_7f21aa"}
```
or:
```json
{"call_id": null}
```

---

### GET /api/calls/{call_id}/events

Poll for call events. Use `after_seq` as the polling cursor.

```http
GET /api/calls/call_7f21aa/events?after_seq=0
```

Response `200`:
```json
{
  "call_id": "call_7f21aa",
  "events": [
    {
      "call_id": "call_7f21aa",
      "seq": 1,
      "type": "STATUS",
      "timestamp": "2026-08-24T09:14:01Z",
      "status": "IN_PROGRESS"
    },
    {
      "call_id": "call_7f21aa",
      "seq": 2,
      "type": "TRANSCRIPT",
      "timestamp": "2026-08-24T09:14:05Z",
      "speaker": "CALLER",
      "text": "Hello, I am calling from your bank."
    },
    {
      "call_id": "call_7f21aa",
      "seq": 3,
      "type": "RISK_UPDATE",
      "timestamp": "2026-08-24T09:14:10Z",
      "risk_score": 72,
      "risk_level": "HIGH"
    }
  ]
}
```

**Polling pattern (for Kalyan's Flutter app):**
1. `GET /api/calls/active` → get `call_id`
2. `GET /api/calls/{call_id}/events?after_seq=0` → receive all events
3. Store highest `seq` received
4. Repeat step 2 with `after_seq=<last_seq>` every ~1 second
5. `GET /api/calls/{call_id}/result` → poll until 200 (final result available)

---

### GET /api/calls/{call_id}/result

Final threat result for a completed call.

```http
GET /api/calls/call_7f21aa/result
```

Returns `ThreatResult` with `source: "CALL"` and `analyzed_content: "<call_id>"`.  
Returns `404` if the call has no result yet.

---

## Integration Notes

### For Sanjani (Twilio)

When your Twilio webhook fires, call the `CallService` methods directly.  
**Do NOT import ORM models directly. Use the service boundary.**

```python
from app.services.call import call_service
from sqlalchemy.orm import Session

# When Twilio signals call started:
call_service.create_call(db, call_id="CA_twilio_sid", scammer_number="+1...", victim_number="+1...")

# When call is bridged / status changes:
call_service.update_status(db, call_id, "IN_PROGRESS")

# For each Twilio event (transcript chunk, risk update, alert):
call_service.append_event(db, call_id, "TRANSCRIPT", speaker="CALLER", text="chunk...")
call_service.append_event(db, call_id, "RISK_UPDATE", risk_score=72, risk_level="HIGH")
call_service.append_event(db, call_id, "STATUS", status="ENDED")

# When call finishes and Skandan's AI returns a ThreatResult:
call_service.finalize_call(db, call_id, threat_result, device_id)
```

**Event speaker values:** `CALLER` | `USER` (per contract §6.2 — not SCAMMER/VICTIM)  
**STATUS event status values:** `RINGING` | `IN_PROGRESS` | `ENDED`

---

### For Skandan (AI Pipeline)

Your AI produces a `ThreatResult`. Implement the `AnalysisProvider` Protocol.

```python
from app.services.analysis import AnalysisProvider, AnalysisService
from app.schemas.threat import ThreatResult
from app.schemas.common import Source, RiskLevel
from datetime import datetime, timezone
import uuid

class GroqAnalysisProvider:
    """Your real AI implementation."""

    def analyze(self, source: Source, content: str, metadata: dict) -> ThreatResult:
        # Call Groq / Whisper / your model here
        # On failure: raise AnalysisFailedError — NEVER return a fake LOW result
        ...
        return ThreatResult(
            id=f"thr_{source.value.lower()}_{uuid.uuid4().hex[:8]}",
            source=source,
            risk_score=97,
            risk_level=RiskLevel.CRITICAL,
            threat_type="Banking Scam",
            indicators=["Bank impersonation", "OTP request"],
            recommendation="Do not share your OTP.",
            timestamp=datetime.now(timezone.utc),
            analyzed_content=content,
        )

# Wire into backend — one line change in app/services/analysis.py:
# analysis_service = AnalysisService(provider=GroqAnalysisProvider())
```

**You do NOT need to import any DB or ORM code.**  
**You do NOT need to call `threat_service.create()` yourself.**  
The backend handles all persistence when it receives your `ThreatResult`.

For call audio: return the `ThreatResult` to Sanjani's Twilio handler, which calls `finalize_call()`.  
`analyzed_content` for CALL will automatically be set to `call_id` (not the transcript) by `finalize_call()`.

---

### For Kalyan (Flutter)

All endpoints are live at `http://localhost:8000` when the backend is running.  
Try them interactively at http://localhost:8000/docs.

**Device identity:** Generate a UUID on first app launch, store it, and send it as `X-Device-Id` on every request.

```dart
// Example: POST /api/analyze
final response = await http.post(
  Uri.parse('$baseUrl/api/analyze'),
  headers: {'X-Device-Id': deviceId, 'Content-Type': 'application/json'},
  body: jsonEncode({'source': 'SMS', 'content': smsText, 'metadata': {}}),
);
```

**Risk levels emitted by backend:** `LOW` | `MEDIUM` | `HIGH` | `CRITICAL`  
Handle `UNKNOWN` as a client-side forward-compatibility fallback (per contract §2.1).

---

## Development Call Simulator

The backend includes a **development-only call simulator** to test real-time scam-call event polling, active call discovery, and final threat results before the real Twilio/AI pipeline is completed by Sub-team A.

This simulator runs **only when `APP_ENV=development`**. It is completely gated and is not present in production routes.

### 1. Trigger the Simulator

Simulate a realistic bank OTP scam call sequence.

```http
POST /api/devtools/simulate
Content-Type: application/json

{
  "call_id": "call_sim_scam_001",
  "device_id": "device-uuid-12345",
  "delay_seconds": 2.0
}
```

- **`call_id`** (optional): Custom ID to simulate. A unique ID is generated if omitted.
- **`device_id`** (required): The client device UUID. Used to scope the final `ThreatResult` history.
- **`delay_seconds`**:
  - `0.0`: Runs synchronously and populates the database immediately (useful for tests).
  - `> 0.0` (e.g. `2.0`): Runs asynchronously in a background task, inserting each event with a delay so you can watch progress in real-time.

### 2. Observe Active Call

While the simulation is running (before step 10 ends), you can discover it:

```http
GET /api/calls/active
```

Response:
```json
{
  "call_id": "call_sim_scam_001"
}
```

Once the simulation completes and finalizes, this endpoint returns `{"call_id": null}`.

### 3. Poll Events

Watch the events stream progressively by polling with the cursor `after_seq`:

```http
GET /api/calls/call_sim_scam_001/events?after_seq=0
```

The simulator produces exactly 10 events:
1. `STATUS` -> RINGING (seq=1)
2. `STATUS` -> IN_PROGRESS (seq=2)
3. `TRANSCRIPT` -> "Hello, I'm calling from your bank." (seq=3)
4. `TRANSCRIPT` -> "We've detected suspicious activity on your account." (seq=4)
5. `RISK_UPDATE` -> score=20, level=LOW (seq=5)
6. `TRANSCRIPT` -> "We need to verify your identity to prevent account freeze." (seq=6)
7. `RISK_UPDATE` -> score=45, level=MEDIUM (seq=7)
8. `TRANSCRIPT` -> "Please tell me the OTP you received." (seq=8)
9. `ALERT` -> score=97, level=CRITICAL, text="ALERT: Caller requested OTP..." (seq=9)
10. `STATUS` -> ENDED (seq=10)

Keep track of the highest `seq` received and supply it as `after_seq` on the next poll to query only new events.

### 4. Retrieve Final Result

After the call finishes, retrieve the final verified ThreatResult:

```http
GET /api/calls/call_sim_scam_001/result
```

Response `200` matches the canonical contract §1.2 result shape:
- `source`: `"CALL"`
- `analyzed_content`: `"call_sim_scam_001"` (the call ID only, never the full transcript)
- `risk_score`: `97`
- `risk_level`: `"CRITICAL"`
- `threat_type`: `"Banking Scam"`
- `indicators`: `["Bank impersonation", "OTP request", "Urgency"]`

### 5. Swappability

This simulator uses the exact same contract endpoints, data structures, and database models that the future production pipeline will use:

```
Sanjani (Twilio Webhook) ──┐
                           ├─► CallService ─► database ─► Kalyan (Flutter App)
Skandan (STT + AI API) ────┘
```

When Sub-team A completes the real pipeline, they will make the exact same calls to `CallService` (e.g. `create_call()`, `append_event()`, `finalize_call()`) without requiring any change to Kalyan's Flutter UI, the API contract, or the databases.

---

## Architecture

```
POST /api/analyze
    ↓
AnalysisService.analyze()           ← call this, not Groq directly
    ↓
AnalysisProvider.analyze()          ← Skandan replaces this
    ↓
ThreatResult
    ↓
ThreatService.create()              ← backend persists
    ↓
SQLite (threats table)

Twilio webhook → CallService.create_call()
               → CallService.append_event()   ← streams events
               → CallService.finalize_call()  ← links final ThreatResult
                    ↓
              Flutter polls → GET /api/calls/{id}/events
```

---

## Environment

```env
# backend/.env (copy from .env.example, no real credentials for Day 1/2)
APP_ENV=development
DATABASE_URL=sqlite:///./finsentinel.db
```

---

## Out of Scope (Day 1/2)

- No Twilio implementation (service boundary only)
- No Groq/Whisper implementation (AnalysisProvider stub)
- No WebSockets (polling v1 per contract §6.1)
- No JWT/authentication (X-Device-Id only, per contract §4)
- No mobile/ code changes
- No web/ code changes
