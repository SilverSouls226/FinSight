import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finsentinel/app.dart';
import 'package:finsentinel/models/user_profile.dart';
import 'package:finsentinel/services/mock_financial_state_service.dart';
import 'package:finsentinel/services/mock_manual_entry_service.dart';
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

  testWidgets('setting an opening balance updates the Home total balance', (tester) async {
    final fakeState = MockFinancialStateService();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userProfileProvider.overrideWith(
          (ref) => UserProfileController(UserProfileStorage(), initial: savedProfile),
        ),
        financialStateServiceProvider.overrideWith((ref) => fakeState),
        manualEntryServiceProvider.overrideWith((ref) => MockManualEntryService(fakeState)),
      ],
      child: const FinSentinelApp(),
    ));
    await _settle(tester);

    final before = await fakeState.fetchSnapshot('usr_123');

    await tester.tap(find.byKey(const Key('rootAddFab')));
    await _settle(tester);

    final scrollable = tester.widget<Scrollable>(
      find.descendant(of: find.byType(DraggableScrollableSheet), matching: find.byType(Scrollable)),
    );
    scrollable.controller!.jumpTo(400);
    await _settle(tester);

    await tester.tap(find.text('Current balance'));
    await _settle(tester);

    expect(find.text('Set current balance'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '4200');
    await tester.tap(find.text('Set balance'));
    await _settle(tester);

    // Sheet closes and a success SnackBar appears.
    expect(find.text('Opening balance set'), findsOneWidget);
    expect(find.text('Set current balance'), findsNothing);

    final after = await fakeState.fetchSnapshot('usr_123');
    expect(after.currentBalances.checking, 4200.0);
    expect(after.currentBalances.checking, isNot(before.currentBalances.checking));
  });
}
