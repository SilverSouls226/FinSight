# FinSentinel — Backend Contract v1.0

**Status: FROZEN, pending Sameer's confirmation.**
Frozen 2026-08-24 by Kalyan (mobile). Implementer: Sameer (backend).

Once Sameer confirms, this document is the source of truth. The backend
implements exactly this; the mobile client parses exactly this. Changes after
confirmation require agreement from both sides.

One item is still open and marked **NEEDS CONFIRMATION** — see §2.2.

---

## 1. The threat result

Every analysis, from every source, returns this object.

```jsonc
{
  "id": "thr_sms_9f2a41",           // required, unique, stable
  "source": "SMS",                   // CALL | SMS | QR | LINK
  "risk_score": 97,                  // integer 0-100
  "risk_level": "CRITICAL",          // LOW | MEDIUM | HIGH | CRITICAL
  "threat_type": "Banking Scam",     // human-readable classification
  "indicators": [                    // list of plain strings
    "Bank impersonation",
    "OTP request",
    "Urgency"
  ],
  "recommendation": "Do not share your OTP. No bank will ever ask for it.",
  "timestamp": "2026-08-24T09:14:22Z",   // ISO-8601, UTC
  "analyzed_content": "URGENT: Your HDFC account will be BLOCKED…"
}
```

### 1.1 Field rules

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | yes | Every threat must have one. History and detail depend on it. |
| `source` | enum | yes | `CALL` \| `SMS` \| `QR` \| `LINK` |
| `risk_score` | integer | yes¹ | 0–100. Not a float, not a 0–1 ratio. |
| `risk_level` | enum | yes | See §2 |
| `threat_type` | string | yes | Shown as the result headline |
| `indicators` | string[] | yes | Plain strings. Not objects, not weighted. May be empty. |
| `recommendation` | string | yes | Plain-English action for the user |
| `timestamp` | string | yes | ISO-8601 |
| `analyzed_content` | string | yes | See §1.2 |

¹ See §2.2 for the one open case.

### 1.2 `analyzed_content`

Persisted server-side and returned on every result, so history is meaningful on
a fresh install or a second device.

| source | contents |
|---|---|
| `SMS` | the full message text as submitted |
| `LINK` | the URL as submitted |
| `QR` | the decoded payload string (`upi://…`, a URL, or raw text) |
| `CALL` | the `call_id` **only** — never the full transcript |

CALL is a reference by design. Inlining transcripts would make every history
response grow without bound.

---

## 2. Risk levels

```
LOW · MEDIUM · HIGH · CRITICAL · UNKNOWN
```

**`UNKNOWN` must never render as safe.** This is a hard rule, not a preference.

### 2.1 Who emits `UNKNOWN`

`UNKNOWN` exists primarily as a **client-side forward-compatibility fallback**.
If the backend ever introduces a new level (say `SEVERE`), an older app must
degrade it to `UNKNOWN` — visibly uncertain — rather than to `LOW`, which would
tell a user they are safe when the app simply did not understand the answer.

Whether the **backend** also emits `UNKNOWN` on the wire is Sameer's call:

- If analysis failure always returns an HTTP error (§5), the backend never needs
  to emit `UNKNOWN`, and it remains client-only. This is the expected case.
- If the backend does emit it for genuinely inconclusive analysis, §2.2 applies.

Either way the client supports it. No harm if it never appears.

### 2.2 `risk_score` when the level is `UNKNOWN` — **NEEDS CONFIRMATION**

An `UNKNOWN` result carrying `risk_score: 0` would render as a large green
**0%** — precisely the fake-safe outcome this contract exists to prevent.

**Proposed rule:** when `risk_level` is `UNKNOWN`, `risk_score` is `null`, and
the app renders a dash rather than a number, with cautionary (never green)
styling.

This is the only unresolved item in the document. It only matters if the backend
ever emits `UNKNOWN` (§2.1); if it never does, confirm that instead and
`risk_score` stays a required integer in all cases.

### 2.3 Presentation

Severity is never conveyed by colour alone — colour is always paired with an icon
and a text label. `UNKNOWN` uses cautionary neutral styling and is excluded from
the "protected / safe" visual language.

---

## 3. Analysis endpoint (SMS / QR / LINK)

A single endpoint for all three submitted-content sources.

```jsonc
POST /api/analyze
Content-Type: application/json
X-Device-Id: <uuid>

{
  "source": "SMS",                          // SMS | QR | LINK
  "content": "URGENT: Your HDFC account…",   // text / URL / decoded QR payload
  "metadata": {                              // optional, open, per-source
    "sender": "VM-HDFCBK"
  }
}
```

**Response:** `200` with a threat result (§1).

`metadata` is an open object so per-source extras (SMS sender ID, QR hints) can
be added later without a contract change.

Call analysis is **not** part of this endpoint — it is a separate real-time
event pipeline (§6).

---

## 4. History

```
GET /api/threats?limit=50
X-Device-Id: <uuid>
```

- **Response:** a JSON array of threat results (§1), **newest first**, sorted by
  `timestamp`. Same object shape as §1 — not a trimmed summary.
- **Scoping:** the backend filters history by `X-Device-Id`.
- **Identity:** the client generates a UUID on first launch and sends it on every
  request. No accounts, no login, no auth for the hackathon.

---

## 5. Errors

Any `4xx` or `5xx` returns:

```jsonc
{
  "error": {
    "code": "INVALID_INPUT",                  // stable, machine-readable
    "message": "content field was empty"      // developer-facing
  }
}
```

`code` is what the client switches on. `message` is for logs and developers and
is **never shown to the user** — the app maps `code` to its own user-facing
wording, so backend phrasing can change freely.

### 5.1 Status semantics

| Status | Meaning | Client behaviour |
|---|---|---|
| `400` / `422` | bad input | show message, no retry offered |
| `429` | rate limited | retry, honouring `Retry-After` |
| `5xx` | server fault | retry offered |
| `503` | analysis engine unavailable | retry offered |

### 5.2 Analysis failure — hard rule

**If AI or analysis fails, return an error. Never return a valid result with
`risk_level: LOW`.**

A fake-safe verdict tells a user a message is fine when nothing was actually
checked. That is the worst failure this product can produce. Fail loudly — the
app has an error state ready for it.

---

## 6. Live call events

The call itself runs through Twilio outside the app. The app never places,
answers or intercepts a call; it only renders backend events.

### 6.1 Transport — polling

```
GET /api/calls/{call_id}/events?after_seq=<n>
X-Device-Id: <uuid>
```

Returns all events for that call with `seq > after_seq`, in ascending `seq`
order. The client polls approximately once per second.

Polling was chosen over WebSockets deliberately: for the backend it is a plain
query, it cannot half-open, it is trivially debuggable, and it is the option
least likely to fail on venue wifi during a demo. One second of latency is
invisible during a 60-second call.

The client consumes these as a `Stream<CallEvent>` and cannot tell how they were
fetched, so **moving to WebSockets later changes only the service
implementation — no UI changes.** That abstraction stays as-is.

### 6.2 Event shape

```jsonc
{
  "call_id": "call_7f21aa",
  "seq": 7,                          // monotonic per call, starts at 1
  "type": "TRANSCRIPT",              // STATUS | TRANSCRIPT | RISK_UPDATE | ALERT
  "timestamp": "2026-08-24T11:58:13Z",

  "status": "IN_PROGRESS",           // STATUS only: RINGING | IN_PROGRESS | ENDED
  "speaker": "CALLER",               // TRANSCRIPT only: CALLER | USER
  "text": "…",                       // TRANSCRIPT and ALERT
  "risk_score": 48,                  // RISK_UPDATE and ALERT
  "risk_level": "MEDIUM"             // RISK_UPDATE and ALERT
}
```

`seq` is the polling cursor and makes duplicate or out-of-order delivery
detectable. Timestamps alone are insufficient — two events can share a second.

### 6.3 Final call result

```
GET /api/calls/{call_id}/result
```

Returns a threat result (§1) with `source: "CALL"` and `analyzed_content` set to
the `call_id`.

### 6.4 Active call discovery

```
GET /api/calls/active
X-Device-Id: <uuid>
```

Returns `{"call_id": "call_7f21aa"}` or `null`.

Needed because the **website** initiates the Twilio call, so the phone otherwise
has no way to know a call exists. Without this, a call ID has to be typed into
the app manually during the demo.

### 6.5 Latency

Sameer to provide an expected p95 for an analysis call. The client currently
allows 10s to connect and 20s to receive; if the AI step routinely exceeds that,
every request fails on a timeout that looks like a network bug.

---

## 7. Out of scope (mobile)

Deliberate decisions, not omissions:

- **No device SMS inbox access.** The app analyses pasted or simulated messages.
  Reading the real inbox needs restricted Android permissions and is Play-Store
  limited — no demo value for the cost.
- **No native call interception or calling engine.** Twilio owns the call. The
  app consumes analysis and events only.

---

## 8. Client implementation status

The mobile app is complete on mock data and matches §1, §3, §4, §5 and §6
already, with every assumption isolated to a single line so the switch is
mechanical.

**Divergences to resolve after Sameer confirms** (not yet implemented — the app
is deliberately unchanged until this document is agreed):

| Item | Current client | Contract v1.0 |
|---|---|---|
| Risk levels | 4 values; unknown → `LOW` + log | 5 values; unknown → `UNKNOWN`, never safe |
| Analyse endpoint | three paths | one `POST /api/analyze` |
| Device identity | none | `X-Device-Id` on every request |
| Call events | mock stream, no cursor | polling with `seq` |
| Active call | hard-coded `call_id` | `GET /api/calls/active` |

The `risk_level` change is the one with user-visible safety impact and should be
implemented first.

Note: the client already has a separate `ThreatSource.unknown` used only when an
unrecognised `source` arrives. It is unrelated to `RiskLevel.UNKNOWN` and is
never sent to the backend.
