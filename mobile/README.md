# FinSentinel — Mobile (Flutter)

Member 4 (Kalyan)'s module for **FinSentinel**, CSI ORIGIN 2026: a Financial
Digital Twin that continuously predicts financial problems and proactively
tells the user when action is needed.

This app owns **only** the mobile presentation layer. It does not compute
balances, forecasts, Monte Carlo simulations, or AI reasoning — it renders
whatever Sanjani's State API and Sameer's AI Brain API send it, using the
exact JSON contracts in `docs/api_contracts.md`.

## Running the app

Requires the Flutter SDK (stable channel, this project was built against
Flutter 3.47.1 / Dart 3.13.1).

```bash
cd mobile
flutter pub get
flutter run
```

The app runs fully offline out of the box — no backend required. It ships
with a bundled scripted demo scenario (`assets/mock/demo_scenario.json`)
that drives the full judging story.

## Running tests

```bash
cd mobile
flutter test
```

## Building the demo APK

```bash
cd mobile
flutter build apk --debug     # fast, for quick device testing
flutter build apk --release   # smaller/faster, for the actual demo
```

Output: `mobile/build/app/outputs/flutter-apk/app-debug.apk` (or
`app-release.apk`).

## Architecture

```
lib/
  models/       Dart classes mirroring the locked API contracts exactly
  services/     Abstract service interfaces + Mock/Api implementations
  state/        Riverpod providers wiring services to the UI
  screens/      One folder per core screen
  widgets/      Shared, reusable presentational widgets
  mock/         Demo scenario loader (reads assets/mock/demo_scenario.json)
  theme/        Dark, instrument-panel visual theme
  utils/        Formatters + the client-side risk estimator fallback
assets/mock/    Bundled JSON used in mock mode
```

The UI never talks to HTTP or JSON directly — it depends only on
`FinancialStateService` and `InterventionService` interfaces
(`lib/services/financial_state_service.dart`,
`lib/services/intervention_service.dart`). Two implementations exist for
each:

- `Mock*Service` — reads `assets/mock/demo_scenario.json`. Used today.
- `Api*Service` — calls the real backend over HTTP with the exact
  contract JSON, with timeout/error handling built in.

### Screens

| # | Screen | File |
|---|--------|------|
| 1 | Onboarding | `screens/onboarding/onboarding_screen.dart` |
| 2 | Home / Financial Weather | `screens/home/home_screen.dart` |
| 3 | Financial Digital Twin | `screens/twin/digital_twin_screen.dart` |
| 4 | Intervention Feed | `screens/interventions/intervention_feed_screen.dart` |
| 5 | Simulation ("Can I afford this?") | `screens/simulation/simulation_screen.dart` |
| 6 | Decision Trace | `screens/decision_trace/decision_trace_screen.dart` |
| 7 | Goals / Risk Profile | `screens/goals/goals_screen.dart` |

### Demo flow (mock mode)

The Home screen has a "Demo scenario" panel (visible only when
`useMockServices = true`) with a button that steps through the scripted
narrative required for judging:

1. **Stable** — 🟢, 8% shortfall risk, one info-level intervention.
2. Tap **"Simulate: Freelance payment delayed"** →
   **Pressure** — 🟡, checking balance drops, risk jumps to 41%, a
   high-severity "Potential cash-flow collision" intervention appears with
   suggested actions and a full decision trace.
3. Open the Simulation tab and try **₹12,000** — shows shortfall risk
   rising further with the purchase, and a recommendation.
4. Tap **"Simulate: Freelance payment arrived"** →
   **Resolved** — 🟢, risk falls back to 6%, an info-level "Cash flow
   stabilized" intervention replaces the high-severity one.

This proves continuous adaptation end-to-end without any backend running.

## Live Backend Integration

The app is wired for a one-line switch (per backend) from mock data to
live APIs — **no screen or widget code needs to change**. As of
`integration/full-team`, **both** backends are confirmed live and
integration-tested — real ingestion → real state → real AI reasoning →
real UI, verified end-to-end including on a physical device.

**Where the base URLs are set:** one place, `lib/services/api_config.dart`
— two constants because Sanjani's and Sameer's services are independent
FastAPI apps, not one gateway:
```dart
static const String sanjaniBaseUrl = 'http://127.0.0.1:8002'; // her local port
static const String sameerBaseUrl  = 'http://127.0.0.1:8000'; // his local port
```
Nothing else in the app hardcodes a URL.

**How mock mode is disabled:** two independent flags,
`lib/state/providers.dart`:
```dart
const bool useMockFinancialState = false; // Sanjani
const bool useMockIntervention = false;   // Sameer
```
Flipping either swaps that Riverpod provider from `Mock*Service` to
`Api*Service`, independently of the other. Every screen consumes the same
providers either way.

**Financial state endpoint (Sanjani) — ✅ confirmed:**
`ApiFinancialStateService` calls `GET {sanjaniBaseUrl}/financial-state/{userId}`
— confirmed directly from her real service
(`member2_state_engine/app/api/endpoints.py`). Expected response JSON: a
single `Financial State Snapshot` object (Contract 2) — see
`test/fixtures/financial_state_snapshot.json`. Her service also exposes
`POST /obligations`, `POST /goals`, and a real `POST /simulate/{userId}`
Monte Carlo endpoint — wired into the Simulation screen via
`ApiSimulationService`, gated by the same `useMockFinancialState` flag
(same backend service). Her endpoint returns risk as 0–100 percentages;
`ApiSimulationService` converts to the 0–1 fractions the rest of the app
uses. She doesn't return a post-purchase safe-to-spend figure or
recommendation text, so those two remain derived locally from the
snapshot + her real risk numbers — presentation only, the risk
percentages and the `is_safe` flag (the actual financial decision) are
entirely hers.

**Intervention endpoint (Sameer) — ✅ confirmed:**
`ApiInterventionService` calls `POST {sameerBaseUrl}/api/evaluate/{userId}`
with the current `Financial State Snapshot` JSON (Contract 2) as the
request body (fetched first via `FinancialStateService` — this works
whether that snapshot came from Sanjani's real service or a mock).
Expected response JSON: a single `Contextual Intervention` object
(Contract 3, not an array) — see `test/fixtures/contextual_intervention.json`.
A `204 No Content` or empty body means "no intervention right now" and is
treated as a valid, non-error result, not a failure.

### Running the full four-service stack locally

```bash
# 1. Sameer's AI Brain (needs backend/.env with a real GROQ_API_KEY —
#    falls back to a deterministic explainer if the key is missing/invalid)
cd backend && uvicorn app.main:app --host 127.0.0.1 --port 8000

# 2. Sanjani's State Engine
cd member2_state_engine && uvicorn app.main:app --host 127.0.0.1 --port 8002

# 3. Skandan's Ingestion service (not called by Flutter directly — feeds Sanjani)
cd member1_ingestion && uvicorn app.main:app --host 127.0.0.1 --port 8001
```

Skandan's and Sanjani's services aren't wired to each other automatically
— they're independent services connected only by the shared JSON
contract. To push a real event through the full pipeline before opening
the app:
```bash
# Ingest raw SMS -> NormalizedFinancialEvent
curl -X POST http://127.0.0.1:8001/ingest -H "Content-Type: application/json" \
  -d '{"user_id":"usr_123","source":"sms","raw_text":"Credited INR 800.00 to a/c XX1234 from FreelanceClient on 28-08-26."}'

# Feed that event into Sanjani's state (paste the JSON from above)
curl -X POST http://127.0.0.1:8002/events -H "Content-Type: application/json" -d '<event JSON>'

# Add an obligation directly (Skandan's SMS parser only produces income/expense, not bills)
curl -X POST http://127.0.0.1:8002/obligations -H "Content-Type: application/json" \
  -d '{"user_id":"usr_123","name":"Apartment Rent","amount":1100.0,"due_date":"2026-09-04T00:00:00Z","category":"fixed_essential"}'
```
Then open the app — Home/Alerts will fetch the real resulting state and
real intervention.

**On a physical Android device over USB**, tunnel both ports before
running:
```bash
adb reverse tcp:8000 tcp:8000
adb reverse tcp:8002 tcp:8002
```

### Two additive, backward-compatible fields

Two fields are read by the UI but are **not required** for integration —
if the backend never sends them, the UI falls back to a client-side
estimate automatically, so nothing breaks:

- `shortfall_probability_30d` (float, 0–1) — optional addition to the
  Financial State Snapshot. Powers the Financial Weather status and risk
  gauge directly if present; otherwise `lib/utils/risk_estimator.dart`
  derives an estimate from balances/income/obligations.
- `decision_trace` (array of `{ "factor": string, "detail": string }`) —
  optional addition to the Contextual Intervention. Powers the Decision
  Trace screen directly if present; otherwise
  `DecisionFactor.fallbackFromExplanation` derives one by splitting
  `explanation` into sentences.

If/when Sanjani's or Sameer's team wants to add either field to the
locked contract for real, it's a pure addition — the mobile app already
understands it.

### Real bank SMS interception (Android only)

The Home screen has an "Auto-detect bank SMS" toggle (Android only —
hidden on other platforms). Turning it on:
1. Requests SMS permission via `SmsListener` (`lib/services/sms_listener.dart`,
   wrapping the `another_telephony` plugin — a maintained fork of the
   discontinued `telephony` package, needed for AGP 9 compatibility; see
   `android/build.gradle.kts` for the one Java-compatibility patch it
   still needs).
2. Listens for incoming SMS **while the app is in the foreground only**
   (`listenInBackground: false` — no foreground service, no background
   wiring; out of scope for this feature).
3. Filters to likely bank senders (`lib/utils/bank_sms_filter.dart` — a
   substring allowlist like `HDFCBK`, `SBIBNK`, `ICICIB`; this is a
   client-side triage step only, not the real parsing).
4. Forwards matches to Skandan's real ingestion endpoint,
   `POST {skandanBaseUrl}/ingest`, via `ApiIngestionService`. A 422
   response (unparseable / duplicate) is treated as a routine non-event,
   not an error.
5. Shows detected events (vendor, amount) in a small list on the card.

**Scope note:** this only gets a message turned into a Normalized
Financial Event by Skandan's service — it does **not** automatically
update Sanjani's Financial State, since her service and his aren't wired
to each other (see above). The Home screen's balance/risk won't move
just from a detected SMS; forwarding into her `/events` would be a
follow-up.

### What the mobile app depends on (and nothing else)

- Only the JSON shapes in `docs/api_contracts.md`. No backend code, no
  database, no internal classes are imported.
- Never assumes a specific ordering or internal source for that JSON —
  only the HTTP method/route documented above and the response shape.

## Error handling

The app never crashes on a backend problem. `ApiFinancialStateService` and
`ApiInterventionService` translate failures into typed exceptions
(`lib/services/service_exceptions.dart`) that the UI renders as a retry
card (`lib/widgets/error_view.dart`):

- Backend unavailable / non-2xx response → `ServiceUnavailableException`
- Request exceeds 10s → `ServiceTimeoutException`
- Response isn't valid/expected JSON → `MalformedResponseException`
- Empty intervention list → a dedicated empty state, not an error
- Missing/partial snapshot fields → models default missing fields instead
  of throwing (see `test/models/financial_state_snapshot_test.dart`)

## Tests

```
test/
  fixtures/   Sanitized JSON representing REAL expected backend responses
              (not the demo scenario — see below)
  models/     JSON parsing + model correctness against the exact contracts,
              including the fixtures above
  services/   Mock service stage-switching, simulation risk math, and
              ApiFinancialStateService/ApiInterventionService success +
              failure paths against a mocked HTTP client (package:http's
              testing.dart — no real network, no extra dependency)
  screens/    Loading/error states, navigation, intervention rendering,
              simulation flow
  widget_test.dart   App boot smoke test
```

`test/fixtures/*.json` are separate from `assets/mock/demo_scenario.json`:
the fixtures exist purely to pin down contract-parsing correctness
(including a low-risk and a high-risk intervention, and a snapshot with
the optional field absent); the demo scenario asset drives the scripted
judging walkthrough in the running app.

Run with `flutter test`. All tests pass offline (no network required).
