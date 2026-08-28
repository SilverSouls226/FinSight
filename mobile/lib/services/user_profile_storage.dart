import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

/// Persists the on-device onboarding profile so completing onboarding once
/// is enough — without this, [UserProfile] lived only in memory and reset
/// to null (re-triggering onboarding) on every cold start or app-kill.
class UserProfileStorage {
  static const _key = 'user_profile_v1';

  Future<UserProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt/old-format data shouldn't block the user from using the
      // app — fall back to onboarding again rather than crashing.
      return null;
    }
  }

  Future<void> save(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
