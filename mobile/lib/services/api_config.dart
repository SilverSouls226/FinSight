/// Central place to point the app at Sanjani's State API and Sameer's
/// Intervention API once they're live. Change [baseUrl] and flip
/// `useMockServices` to false in lib/state/providers.dart to integrate —
/// no screen code changes required.
class ApiConfig {
  const ApiConfig._();

  // integration/kalyan-sameer: pointed at Sameer's real local FastAPI
  // backend for the first live end-to-end test. Runtime host reference:
  //   - local iOS simulator / macOS / this machine's own runtime: 127.0.0.1
  //   - Android emulator: 10.0.2.2 (maps to host loopback)
  //   - physical device: host machine's LAN IP
  // This machine has no Android/iOS device attached, so the app is run
  // natively on this machine (web/desktop), which reaches the backend via
  // the loopback address below.
  static const String baseUrl = 'http://127.0.0.1:8000';
  static const Duration requestTimeout = Duration(seconds: 10);
}
