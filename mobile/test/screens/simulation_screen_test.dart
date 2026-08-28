import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finsentinel/models/financial_state_snapshot.dart';
import 'package:finsentinel/models/intervention.dart';
import 'package:finsentinel/screens/simulation/simulation_screen.dart';
import 'package:finsentinel/services/financial_state_service.dart';
import 'package:finsentinel/services/intervention_service.dart';
import 'package:finsentinel/state/providers.dart';

class _FakeFinancialStateService implements FinancialStateService {
  @override
  Future<FinancialStateSnapshot> fetchSnapshot(String userId) async {
    return FinancialStateSnapshot(
      userId: userId,
      lastUpdated: DateTime(2026, 8, 28),
      currentBalances: const CurrentBalances(checking: 1250, savings: 5000),
      projectedIncome30Days: const ProjectedIncome(estimatedAmount: 3200, variance: 400),
      upcomingObligations: [
        UpcomingObligation(
          name: 'Rent',
          amount: 1100,
          dueDate: DateTime(2026, 9, 4),
          category: ObligationCategory.fixedEssential,
        ),
      ],
      activeGoals: const [],
      safeToSpend: 850,
      shortfallProbability30d: 0.08,
    );
  }
}

class _EmptyInterventionService implements InterventionService {
  @override
  Future<List<ContextualIntervention>> fetchInterventions(String userId) async => [];
}

void main() {
  testWidgets('running a simulation shows both risk bars and a recommendation', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financialStateServiceProvider.overrideWithValue(_FakeFinancialStateService()),
          interventionServiceProvider.overrideWithValue(_EmptyInterventionService()),
        ],
        child: const MaterialApp(home: SimulationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Default prefilled amount matches the spec's "Can I afford this?" example.
    expect(find.text('12000'), findsOneWidget);

    await tester.tap(find.text('Simulate'));
    await tester.pumpAndSettle();

    expect(find.text('WITHOUT PURCHASE'), findsOneWidget);
    expect(find.text('WITH PURCHASE'), findsOneWidget);
    expect(find.textContaining('For a'), findsOneWidget);
  });

  testWidgets('rejects an invalid amount without crashing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financialStateServiceProvider.overrideWithValue(_FakeFinancialStateService()),
          interventionServiceProvider.overrideWithValue(_EmptyInterventionService()),
        ],
        child: const MaterialApp(home: SimulationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Simulate'));
    await tester.pump();

    expect(find.text('Enter a valid purchase amount.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
