/// Central place to point the app at Sanjani's State API and Sameer's
/// Intervention API once they're live. Change [baseUrl] and flip
/// `useMockServices` to false in lib/state/providers.dart to integrate —
/// no screen code changes required.
class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = 'https://TODO-backend-url.example.com';
  static const Duration requestTimeout = Duration(seconds: 10);
}
