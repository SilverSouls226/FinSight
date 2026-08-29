import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finsentinel/app.dart';
import 'package:finsentinel/models/user_profile.dart';
import 'package:finsentinel/services/mock_financial_state_service.dart';
import 'package:finsentinel/services/user_profile_storage.dart';
import 'package:finsentinel/state/providers.dart';

// Note: avoids `pumpAndSettle()`. Once real (mock) financial data
// resolves, the Digital Twin tab -- kept mounted at all times by the root
// shell's IndexedStack -- has an infinitely-repeating pulse animation
// (Twin Assistant), so `pumpAndSettle()` never returns. Bounded
// `pump(duration)` calls are used instead.
//
// Each Add-flow scenario lives in its own test file (rather than multiple
// `testWidgets` blocks in one file): running more than one full
// app-boot-plus-bottom-sheet scenario back-to-back in a single process
// hangs on the second one, even with the modal route explicitly popped
// and every plausible leaked Timer/gesture flushed before the first test
// ends. Every scenario is individually verified to pass reliably in
// isolation; splitting by file sidesteps the cross-test interaction
// entirely, since `flutter test` gives each file its own process.
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

  testWidgets('FAB opens the Add sheet with all entry types listed', (tester) async {
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

    expect(find.byKey(const Key('rootAddFab')), findsOneWidget);
    await tester.tap(find.byKey(const Key('rootAddFab')));
    await _settle(tester);

    // Scoped to the sheet: the Home screen's "Add" quick-action label sits
    // underneath and also matches plain find.text('Add').
    expect(
      find.descendant(of: find.byType(DraggableScrollableSheet), matching: find.text('Add')),
      findsOneWidget,
    );
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Obligation'), findsOneWidget);
    expect(find.text('Goal'), findsOneWidget);

    // The type picker's ListView only builds tiles within/near the
    // viewport (standard Sliver culling); jump the ScrollController
    // directly to bring the last two items into the tree.
    final scrollable = tester.widget<Scrollable>(
      find.descendant(of: find.byType(DraggableScrollableSheet), matching: find.byType(Scrollable)),
    );
    scrollable.controller!.jumpTo(400);
    await _settle(tester);

    expect(find.text('Current balance'), findsOneWidget);
    expect(find.text('Set up profile & preferences'), findsOneWidget);
  });
}
