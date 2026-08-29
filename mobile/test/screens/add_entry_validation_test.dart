import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finsentinel/app.dart';
import 'package:finsentinel/models/user_profile.dart';
import 'package:finsentinel/services/mock_financial_state_service.dart';
import 'package:finsentinel/services/user_profile_storage.dart';
import 'package:finsentinel/state/providers.dart';

// See add_entry_type_picker_test.dart for why each Add-flow scenario is
// its own test file, and why `pumpAndSettle()` is avoided.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  const savedProfile = UserProfile(
    name: 'Kalyan',
    riskTolerance: RiskTolerance.moderate,
    priorities: [],
  );

  testWidgets('amount validation blocks save and keeps the sheet open', (tester) async {
    final fakeState = MockFinancialStateService();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userProfileProvider.overrideWith(
          (ref) => UserProfileController(UserProfileStorage(), initial: savedProfile),
        ),
        financialStateServiceProvider.overrideWith((ref) => fakeState),
      ],
      child: const FinSentinelApp(),
    ));
    await _settle(tester);

    await tester.tap(find.byKey(const Key('rootAddFab')));
    await _settle(tester);
    await tester.tap(find.text('Income'));
    await _settle(tester);

    // Leave amount blank, fill only the source, then try to save.
    await tester.enterText(find.widgetWithText(TextFormField, 'Source / From'), 'Freelance Client');
    await tester.tap(find.text('Save'));
    await _settle(tester);

    // Still on the income form -- validation blocked the save.
    expect(find.text('Add income'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
  });
}
