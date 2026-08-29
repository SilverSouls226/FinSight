import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finsentinel/app.dart';
import 'package:finsentinel/models/user_profile.dart';
import 'package:finsentinel/services/mock_financial_state_service.dart';
import 'package:finsentinel/services/mock_obligation_service.dart';
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

  testWidgets('adding an obligation reflects in the mock overlay', (tester) async {
    final fakeState = MockFinancialStateService();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userProfileProvider.overrideWith(
          (ref) => UserProfileController(UserProfileStorage(), initial: savedProfile),
        ),
        financialStateServiceProvider.overrideWith((ref) => fakeState),
        obligationServiceProvider.overrideWith((ref) => MockObligationService(fakeState)),
      ],
      child: const FinSentinelApp(),
    ));
    await _settle(tester);

    await tester.tap(find.byKey(const Key('rootAddFab')));
    await _settle(tester);
    await tester.tap(find.text('Obligation'));
    await _settle(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Widget Test Rent');
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '1500');
    await tester.tap(find.text('Save'));
    await _settle(tester);

    expect(find.text('Obligation added'), findsOneWidget);

    final snapshot = await fakeState.fetchSnapshot('usr_123');
    expect(snapshot.upcomingObligations.any((o) => o.name == 'Widget Test Rent' && o.amount == 1500.0), isTrue);
  });
}
