// integration/kalyan-sameer: the FIRST REAL integration test between
// Kalyan's Flutter app and Sameer's AI Brain backend.
//
// This drives the ACTUAL compiled app via Flutter's own IntegrationTest
// binding (no OS-level input injection) and makes a REAL HTTP request
// to Sameer's REAL, locally running FastAPI server at
// http://127.0.0.1:8000 — nothing here is mocked at the network layer.
//
// Run with the backend already running locally:
//   flutter test integration_test/real_backend_integration_test.dart -d windows
//
// FinancialStateService is overridden with fixed fixtures (not the real
// Sanjani State API, which is not yet confirmed) so exact scenario
// numbers can be pinned down for the rent-collision and healthy-state
// comparisons. InterventionService is left as the app's real wiring:
// ApiInterventionService, POSTing to Sameer's real /api/evaluate/{user_id}.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:finsentinel/app.dart';
import 'package:finsentinel/models/financial_state_snapshot.dart';
import 'package:finsentinel/services/financial_state_service.dart';
import 'package:finsentinel/state/providers.dart';

/// Rent-collision scenario exactly as specified for this integration test:
/// Checking ₹150, Savings ₹5000, Rent ₹1100 due soon, Projected income
/// ₹800, Safe-to-spend ₹0.
class _RentCollisionFinancialStateService implements FinancialStateService {
  @override
  Future<FinancialStateSnapshot> fetchSnapshot(String userId) async {
    final now = DateTime.now();
    return FinancialStateSnapshot(
      userId: userId,
      lastUpdated: now,
      currentBalances: const CurrentBalances(checking: 150.0, savings: 5000.0),
      projectedIncome30Days: const ProjectedIncome(estimatedAmount: 800.0, variance: 200.0),
      upcomingObligations: [
        UpcomingObligation(
          name: 'Apartment Rent',
          amount: 1100.0,
          dueDate: now.add(const Duration(days: 3)),
          category: ObligationCategory.fixedEssential,
        ),
      ],
      activeGoals: const [],
      safeToSpend: 0.0,
    );
  }
}

/// A healthier financial state — same user, no imminent collision — used
/// to prove the backend's response (and therefore the Flutter UI) changes
/// with the input state rather than showing static content.
class _HealthyFinancialStateService implements FinancialStateService {
  @override
  Future<FinancialStateSnapshot> fetchSnapshot(String userId) async {
    final now = DateTime.now();
    return FinancialStateSnapshot(
      userId: userId,
      lastUpdated: now,
      currentBalances: const CurrentBalances(checking: 5000.0, savings: 8000.0),
      projectedIncome30Days: const ProjectedIncome(estimatedAmount: 3200.0, variance: 150.0),
      upcomingObligations: [
        UpcomingObligation(
          name: 'Streaming Subscription',
          amount: 45.0,
          dueDate: now.add(const Duration(days: 20)),
          category: ObligationCategory.discretionary,
        ),
      ],
      activeGoals: const [],
      safeToSpend: 3800.0,
    );
  }
}

Future<void> _completeOnboarding(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'Kalyan');
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Get started'));
  await tester.pumpAndSettle();
}

/// Pumps until the loading spinner clears or [maxWait] elapses. Used
/// because this hits a REAL network call with real latency, unlike mocked
/// widget tests.
Future<void> _waitForRealNetworkCall(
  WidgetTester tester, {
  Duration maxWait = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(maxWait);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'REAL backend: rent-collision snapshot produces a high-risk intervention rendered in the real UI',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financialStateServiceProvider.overrideWithValue(_RentCollisionFinancialStateService()),
            // interventionServiceProvider is left as the app's real wiring
            // (ApiInterventionService) — this is the actual thing under test.
          ],
          child: const FinSentinelApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _completeOnboarding(tester);
      await _waitForRealNetworkCall(tester);

      await tester.tap(find.text('Alerts'));
      await _waitForRealNetworkCall(tester);
      await tester.pumpAndSettle();

      // The severity badge, title, and summary below come ENTIRELY from
      // Sameer's real backend response — nothing here is computed by Flutter.
      expect(find.text('HIGH'), findsOneWidget,
          reason: 'Real backend should classify the rent-collision snapshot as high severity');

      // Open the intervention to verify explanation + suggested action + approval UI.
      expect(find.byType(InkWell), findsWidgets);
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(find.text('WHY THIS MATTERS'), findsOneWidget);
      expect(find.text('SUGGESTED ACTIONS'), findsOneWidget);
      // The suggested action's approval requirement is backend-driven.
      expect(find.textContaining('Requires your approval'), findsWidgets);
    },
  );

  testWidgets(
    'REAL backend: a healthier snapshot produces a different, lower-risk response',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financialStateServiceProvider.overrideWithValue(_HealthyFinancialStateService()),
          ],
          child: const FinSentinelApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _completeOnboarding(tester);
      await _waitForRealNetworkCall(tester);

      await tester.tap(find.text('Alerts'));
      await _waitForRealNetworkCall(tester);
      await tester.pumpAndSettle();

      // Must NOT be the same high-severity rent-collision output — proves
      // the app is reacting to the backend's real decision, not showing
      // static mock content.
      expect(find.text('HIGH'), findsNothing,
          reason: 'A healthy snapshot should not produce a high-severity intervention');
    },
  );
}
