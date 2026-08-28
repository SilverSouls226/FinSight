import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finsentinel/app.dart';
import 'package:finsentinel/models/user_profile.dart';
import 'package:finsentinel/screens/onboarding/onboarding_screen.dart';
import 'package:finsentinel/screens/root/root_shell.dart';
import 'package:finsentinel/services/user_profile_storage.dart';
import 'package:finsentinel/state/providers.dart';

void main() {
  testWidgets('App boots into onboarding when no profile exists', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FinSentinelApp()));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Your Financial Digital Twin'), findsOneWidget);
  });

  testWidgets('App skips onboarding when a profile was already saved (persistence)', (tester) async {
    // Regression test for: onboarding used to re-run on every restart
    // because the profile only ever lived in memory.
    final storage = UserProfileStorage();
    const savedProfile = UserProfile(
      name: 'Kalyan',
      riskTolerance: RiskTolerance.moderate,
      priorities: [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith(
            (ref) => UserProfileController(storage, initial: savedProfile),
          ),
        ],
        child: const FinSentinelApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(RootShell), findsOneWidget);
  });
}
