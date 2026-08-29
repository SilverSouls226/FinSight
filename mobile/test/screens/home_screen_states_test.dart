import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finsentinel/models/financial_state_snapshot.dart';
import 'package:finsentinel/models/intervention.dart';
import 'package:finsentinel/models/user_profile.dart';
import 'package:finsentinel/screens/home/home_screen.dart';
import 'package:finsentinel/services/financial_state_service.dart';
import 'package:finsentinel/services/intervention_service.dart';
import 'package:finsentinel/services/service_exceptions.dart';
import 'package:finsentinel/services/user_profile_storage.dart';
import 'package:finsentinel/state/providers.dart';
import 'package:finsentinel/widgets/error_view.dart';
import 'package:finsentinel/widgets/loading_view.dart';

FinancialStateSnapshot _fakeSnapshot() {
  return FinancialStateSnapshot(
    userId: 'usr_123',
    lastUpdated: DateTime(2026, 8, 28),
    currentBalances: const CurrentBalances(checking: 1250, savings: 5000),
    projectedIncome30Days: const ProjectedIncome(estimatedAmount: 3200, variance: 400),
    upcomingObligations: const [],
    activeGoals: const [],
    safeToSpend: 850,
    shortfallProbability30d: 0.08,
  );
}

class _NeverRespondsFinancialStateService implements FinancialStateService {
  @override
  Future<FinancialStateSnapshot> fetchSnapshot(String userId) => Completer<FinancialStateSnapshot>().future;
}

class _FailingFinancialStateService implements FinancialStateService {
  @override
  Future<FinancialStateSnapshot> fetchSnapshot(String userId) async {
    throw const ServiceUnavailableException();
  }
}

class _FakeFinancialStateService implements FinancialStateService {
  @override
  Future<FinancialStateSnapshot> fetchSnapshot(String userId) async => _fakeSnapshot();
}

class _EmptyInterventionService implements InterventionService {
  @override
  Future<List<ContextualIntervention>> fetchInterventions(String userId) async => [];
}

Widget _wrap(Widget child, List<Override> overrides) {
  return ProviderScope(
    overrides: [
      userProfileProvider.overrideWith(
        (ref) => UserProfileController(
          UserProfileStorage(),
          initial: const UserProfile(
            name: 'Test User',
            riskTolerance: RiskTolerance.moderate,
            priorities: [],
          ),
        ),
      ),
      ...overrides,
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('shows LoadingView while the financial state is pending', (tester) async {
    await tester.pumpWidget(_wrap(
      const HomeScreen(),
      [
        financialStateServiceProvider.overrideWithValue(_NeverRespondsFinancialStateService()),
        interventionServiceProvider.overrideWithValue(_EmptyInterventionService()),
      ],
    ));
    await tester.pump();

    expect(find.byType(LoadingView), findsOneWidget);
  });

  testWidgets('shows ErrorView, not a crash, when the backend is unavailable', (tester) async {
    await tester.pumpWidget(_wrap(
      const HomeScreen(),
      [
        financialStateServiceProvider.overrideWithValue(_FailingFinancialStateService()),
        interventionServiceProvider.overrideWithValue(_EmptyInterventionService()),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders financial weather once data loads', (tester) async {
    await tester.pumpWidget(_wrap(
      const HomeScreen(),
      [
        financialStateServiceProvider.overrideWithValue(_FakeFinancialStateService()),
        interventionServiceProvider.overrideWithValue(_EmptyInterventionService()),
      ],
    ));
    await tester.pumpAndSettle();

    // Fake snapshot's shortfallProbability30d (0.08) falls under the
    // "stable" weather threshold, so the risk card shows this copy --
    // see RiskEstimator.weatherFromRisk and _RiskCard's title switch.
    expect(find.text('Shortfall risk is low'), findsOneWidget);
    expect(find.byType(ErrorView), findsNothing);
  });
}
