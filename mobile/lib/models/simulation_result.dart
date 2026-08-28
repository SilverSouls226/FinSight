/// Result of a "Can I afford this?" simulation.
///
/// Not part of the locked API contracts — this is computed client-side
/// from the current [FinancialStateSnapshot] via [SimulationService] so the
/// Simulation screen works fully offline in mock mode. When the backend
/// exposes a real simulation/Monte Carlo endpoint, only the service
/// implementation swapped (Mock -> Api); this result shape stays the UI
/// contract.
library;

class SimulationResult {
  final double purchaseAmount;
  final double shortfallRiskWithoutPurchase;
  final double shortfallRiskWithPurchase;
  final double safeToSpendAfterPurchase;
  final String recommendation;
  final bool isAffordable;

  const SimulationResult({
    required this.purchaseAmount,
    required this.shortfallRiskWithoutPurchase,
    required this.shortfallRiskWithPurchase,
    required this.safeToSpendAfterPurchase,
    required this.recommendation,
    required this.isAffordable,
  });

  double get riskDelta =>
      shortfallRiskWithPurchase - shortfallRiskWithoutPurchase;
}
