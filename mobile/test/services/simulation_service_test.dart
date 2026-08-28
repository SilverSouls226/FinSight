import 'package:flutter_test/flutter_test.dart';

import 'package:finsentinel/models/financial_state_snapshot.dart';
import 'package:finsentinel/services/simulation_service.dart';

FinancialStateSnapshot _snapshot({double checking = 1250, double shortfall = 0.08}) {
  return FinancialStateSnapshot(
    userId: 'usr_123',
    lastUpdated: DateTime(2026, 8, 28),
    currentBalances: CurrentBalances(checking: checking, savings: 5000),
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
    shortfallProbability30d: shortfall,
  );
}

void main() {
  group('MockSimulationService.simulatePurchase', () {
    test('a large purchase raises shortfall risk relative to baseline', () async {
      final service = MockSimulationService();
      final result = await service.simulatePurchase(
        snapshot: _snapshot(),
        purchaseAmount: 12000,
      );

      expect(result.shortfallRiskWithPurchase, greaterThan(result.shortfallRiskWithoutPurchase));
      expect(result.isAffordable, isFalse);
      expect(result.safeToSpendAfterPurchase, lessThan(0));
    });

    test('a small purchase within the safe-to-spend buffer is affordable', () async {
      final service = MockSimulationService();
      final result = await service.simulatePurchase(
        snapshot: _snapshot(),
        purchaseAmount: 50,
      );

      expect(result.isAffordable, isTrue);
      expect(result.safeToSpendAfterPurchase, greaterThanOrEqualTo(0));
    });

    test('riskDelta is the difference between with/without purchase risk', () async {
      final service = MockSimulationService();
      final result = await service.simulatePurchase(
        snapshot: _snapshot(),
        purchaseAmount: 5000,
      );

      expect(
        result.riskDelta,
        closeTo(result.shortfallRiskWithPurchase - result.shortfallRiskWithoutPurchase, 0.0001),
      );
    });
  });
}
