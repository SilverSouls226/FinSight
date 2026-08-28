/// Central place to point the app at Sanjani's State API and Sameer's
/// Intervention API. Two separate base URLs because they're two
/// independent FastAPI services (not one gateway) — flip
/// `useMockFinancialState` / `useMockIntervention` to false in
/// lib/state/providers.dart to integrate either one — no screen code
/// changes required either way.
class ApiConfig {
  const ApiConfig._();

  // integration/full-team: pointed at real local services for live
  // end-to-end testing. Runtime host reference:
  //   - local iOS simulator / macOS / this machine's own runtime: 127.0.0.1
  //   - Android emulator: 10.0.2.2 (maps to host loopback)
  //   - physical device over USB: `adb reverse tcp:PORT tcp:PORT` tunnels
  //     127.0.0.1 straight through, no LAN IP needed
  //   - physical device over Wi-Fi: host machine's LAN IP
  // This machine has no Android/iOS emulator, so desktop/web runs use
  // loopback directly; the phone used `adb reverse`, so loopback works
  // there too.

  /// Sanjani's Financial Digital Twin / State Engine.
  /// Real route confirmed: GET {sanjaniBaseUrl}/financial-state/{user_id}
  static const String sanjaniBaseUrl = 'http://127.0.0.1:8002';

  /// Sameer's Autonomous Decision / AI Brain.
  /// Real route confirmed: POST {sameerBaseUrl}/api/evaluate/{user_id}
  static const String sameerBaseUrl = 'http://127.0.0.1:8000';

  /// Skandan's Ingestion service.
  /// Real route confirmed: POST {skandanBaseUrl}/ingest
  static const String skandanBaseUrl = 'http://127.0.0.1:8001';

  static const Duration requestTimeout = Duration(seconds: 10);
}
