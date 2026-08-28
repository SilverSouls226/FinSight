/// Abstraction over pushing the local [UserProfile] (see
/// lib/models/user_profile.dart) to the backend's "Profile & Preferences"
/// record. Local SharedPreferences storage (UserProfileStorage) stays the
/// source of truth for onboarding-gate purposes -- this is a best-effort
/// sync so `safety_buffer` actually affects the real safe-to-spend
/// calculation. Never blocks or breaks the local save if it fails.
abstract class ProfileSyncService {
  Future<void> syncProfile({
    required String? name,
    required String riskTolerance, // conservative | moderate | aggressive
    required double safetyBuffer,
    required List<String> priorities,
    String preferredCurrency = 'INR',
  });
}
