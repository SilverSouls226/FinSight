import '../models/financial_state_snapshot.dart';
import '../models/simulation_result.dart';
import '../utils/risk_estimator.dart';

/// "Can I afford this?" simulation abstraction.
///
/// Not part of the locked API contracts today. [MockSimulationService]
/// computes an estimate on-device from the current snapshot so the screen
/// works fully offline. When Sanjani's team exposes a real Monte Carlo
/// simulation endpoint, add `ApiSimulationService` implementing this same
/// interface — the Simulation screen won't need to change.
abstract class SimulationService {
  Future<SimulationResult> simulatePurchase({
    required FinancialStateSnapshot snapshot,
    required double purchaseAmount,
  });
}

class MockSimulationService implements SimulationService {
  @override
  Future<SimulationResult> simulatePurchase({
    required FinancialStateSnapshot snapshot,
    required double purchaseAmount,
  }) async {
    final baselineRisk = RiskEstimator.estimateShortfallProbability(snapshot);

    final projectedSnapshot = FinancialStateSnapshot(
      userId: snapshot.userId,
      lastUpdated: snapshot.lastUpdated,
      currentBalances: CurrentBalances(
        checking: snapshot.currentBalances.checking - purchaseAmount,
        savings: snapshot.currentBalances.savings,
        other: snapshot.currentBalances.other,
      ),
      projectedIncome30Days: snapshot.projectedIncome30Days,
      upcomingObligations: snapshot.upcomingObligations,
      activeGoals: snapshot.activeGoals,
      safeToSpend: snapshot.safeToSpend,
      // Force a fresh (heuristic) recompute for the post-purchase state.
      shortfallProbability30d: null,
    );

    final projectedRisk =
        RiskEstimator.estimateShortfallProbability(projectedSnapshot);
    final safeToSpendAfter = snapshot.safeToSpend - purchaseAmount;

    final bool affordable = safeToSpendAfter >= 0 && projectedRisk < 0.5;

    final String recommendation;
    if (!affordable) {
      recommendation =
          'Not recommended right now. This purchase would push your shortfall '
          'risk to ${(projectedRisk * 100).round()}% and use up more than your '
          'safe-to-spend buffer. Consider waiting until your next income lands, '
          'or reduce the amount.';
    } else if (projectedRisk - baselineRisk > 0.1) {
      recommendation =
          'Affordable, but it noticeably raises your risk (from '
          '${(baselineRisk * 100).round()}% to ${(projectedRisk * 100).round()}%). '
          'Proceed only if this purchase is a priority.';
    } else {
      recommendation =
          'This purchase fits comfortably within your safe-to-spend buffer '
          'with minimal impact on shortfall risk.';
    }

    return SimulationResult(
      purchaseAmount: purchaseAmount,
      shortfallRiskWithoutPurchase: baselineRisk,
      shortfallRiskWithPurchase: projectedRisk,
      safeToSpendAfterPurchase: safeToSpendAfter,
      recommendation: recommendation,
      isAffordable: affordable,
    );
  }
}
