import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finsentinel/app.dart';
import 'package:finsentinel/models/intervention.dart';
import 'package:finsentinel/screens/root/root_shell.dart';
import 'package:finsentinel/services/intervention_service.dart';
import 'package:finsentinel/state/providers.dart';

/// Screens backed by a FutureProvider show an indeterminate
/// CircularProgressIndicator while loading, which animates forever and
/// makes pumpAndSettle time out. Pump repeatedly until it disappears
/// instead, so the mock asset load has time to resolve.
Future<void> _settleAsync(WidgetTester tester) async {
  for (int i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
  }
}

Future<void> _completeOnboarding(WidgetTester tester) async {
  // Page 1: name
  await tester.enterText(find.byType(TextField).first, 'Kalyan');
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();

  // Page 2: risk tolerance (default selection is fine)
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();

  // Page 3: priorities (skip, none required)
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();

  // Page 4: optional goal, finish -> lands on Home, which loads async data.
  await tester.tap(find.text('Get started'));
  await _settleAsync(tester);
}

final _testIntervention = ContextualIntervention(
  interventionId: 'int_test',
  userId: 'usr_123',
  timestamp: DateTime(2026, 8, 28),
  severity: InterventionSeverity.high,
  title: 'Potential cash-flow collision',
  summary: 'You may be short on cash for your rent payment.',
  explanation: 'Income decreased and rent is approaching.',
  suggestedActions: const [
    SuggestedAction(
      actionType: 'transfer',
      description: 'Transfer funds to cover the gap.',
      requiresUserApproval: true,
    ),
  ],
);

class _FakeInterventionService implements InterventionService {
  @override
  Future<List<ContextualIntervention>> fetchInterventions(String userId) async {
    return [_testIntervention];
  }
}

void main() {
  setUp(() {
    // Completing onboarding in these tests calls UserProfileController's
    // real persistence path, which needs shared_preferences' plugin
    // channel mocked out in a test environment.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('completing onboarding reveals the main bottom-navigation shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FinSentinelApp()));
    await tester.pumpAndSettle();

    await _completeOnboarding(tester);

    expect(find.byType(RootShell), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('bottom navigation switches between all core screens', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FinSentinelApp()));
    await tester.pumpAndSettle();
    await _completeOnboarding(tester);

    await tester.tap(find.text('Insights'));
    await _settleAsync(tester);
    expect(find.text('Financial Digital Twin'), findsOneWidget);

    await tester.tap(find.text('Simulate'));
    await _settleAsync(tester);
    expect(find.text('Can I afford this?'), findsOneWidget);

    await tester.tap(find.text('Alerts'));
    await _settleAsync(tester);
    expect(find.text('Interventions'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await _settleAsync(tester);
    expect(find.text('Goals & Risk Profile'), findsOneWidget);
  });

  testWidgets('tapping an intervention opens its detail then decision trace', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          interventionServiceProvider.overrideWithValue(_FakeInterventionService()),
        ],
        child: const FinSentinelApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _completeOnboarding(tester);

    await tester.tap(find.text('Alerts'));
    await _settleAsync(tester);

    expect(find.text('Potential cash-flow collision'), findsOneWidget);
    await tester.tap(find.text('Potential cash-flow collision'));
    await tester.pumpAndSettle();

    expect(find.text('WHY THIS MATTERS'), findsOneWidget);

    await tester.tap(find.text('See full decision trace'));
    await tester.pumpAndSettle();

    expect(find.text('Decision Trace'), findsOneWidget);
    expect(find.text('Recommendation'), findsOneWidget);
  });
}
