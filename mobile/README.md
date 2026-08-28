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

The app is already wired for a one-line switch from mock data to live
APIs — **no screen or widget code needs to change**.

**Where the base URL is set:** one place, `lib/services/api_config.dart`:
```dart
static const String baseUrl = 'https://TODO-backend-url.example.com';
```
Set this to the deployed FastAPI backend URL. Nothing else in the app
hardcodes a URL.

**How mock mode is disabled:** one flag, `lib/state/providers.dart`:
```dart
const bool useMockServices = false;
```
Flipping this swaps the Riverpod providers from `Mock*Service` to
`Api*Service`. Every screen consumes the same providers either way.

**Financial state endpoint (Sanjani) — ⚠️ ROUTE IS TBD:**
`ApiFinancialStateService` currently calls
`GET {baseUrl}/users/{userId}/financial-state`. **This route has not been
confirmed by Sanjani** — the shared contract (`docs/api_contracts.md`)
only defines the *payload* shape (Contract 2), not the route. This is a
working placeholder, not a confirmed integration. When she confirms the
real route, update the single `Uri.parse(...)` line in
`lib/services/api_financial_state_service.dart` — nothing else changes.
Expected response JSON: a single `Financial State Snapshot` object
(Contract 2) — see `test/fixtures/financial_state_snapshot.json`.

**Intervention endpoint (Sameer) — ✅ confirmed:**
`ApiInterventionService` calls `POST {baseUrl}/api/evaluate/{userId}`
with the current `Financial State Snapshot` JSON (Contract 2) as the
request body (fetched first via `FinancialStateService`). Expected
response JSON: a single `Contextual Intervention` object (Contract 3, not
an array) — see `test/fixtures/contextual_intervention.json`. A `204 No
Content` or empty body means "no intervention right now" and is treated
as a valid, non-error result, not a failure.

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
