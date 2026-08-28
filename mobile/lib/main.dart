import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/user_profile_storage.dart';
import 'state/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load any previously-saved onboarding profile before the first frame,
  // so a returning user lands straight on Home instead of onboarding again.
  final storage = UserProfileStorage();
  final savedProfile = await storage.load();

  runApp(
    ProviderScope(
      overrides: [
        userProfileStorageProvider.overrideWithValue(storage),
        userProfileProvider.overrideWith(
          (ref) => UserProfileController(storage, initial: savedProfile),
        ),
      ],
      child: const FinSentinelApp(),
    ),
  );
}
