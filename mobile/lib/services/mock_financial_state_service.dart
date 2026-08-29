import '../mock/demo_scenario.dart';
import '../models/financial_state_snapshot.dart';
import 'financial_state_service.dart';

/// Serves Financial State Snapshots from the bundled demo scenario asset.
///
/// Fully offline. [setStage] lets the demo controller advance the scripted
/// narrative (stable -> pressure -> resolved); `fetchSnapshot` always
/// returns whatever stage is currently selected, merged with any manually
/// "added" entries below.
///
/// The scripted stages themselves stay read-only/fixed -- manual adds are
/// layered on top as an in-memory overlay (mirrors the manual-entry
/// "Add" flow, so it works offline exactly like the real backend does
/// live: apply the entry, then reflect it in the next snapshot fetch).
class MockFinancialStateService implements FinancialStateService {
  MockFinancialStateService({DemoScenarioLoader? loader})
      : _loader = loader ?? DemoScenarioLoader();

  final DemoScenarioLoader _loader;
  String _currentStageId = 'stable';

  double _manualBalanceDelta = 0;
  double? _openingBalanceOverride;
  final List<UpcomingObligation> _manualObligations = [];
  final List<ActiveGoal> _manualGoals = [];
  double _safetyBuffer = 100.0;
  bool _safetyBufferChanged = false;

  void setStage(String stageId) {
    _currentStageId = stageId;
  }

  String get currentStageId => _currentStageId;

  void addManualIncome(double amount) => _manualBalanceDelta += amount;

  void addManualExpense(double amount) => _manualBalanceDelta -= amount;

  void setOpeningBalance(double amount) => _openingBalanceOverride = amount;

  void addManualObligation(UpcomingObligation obligation) => _manualObligations.add(obligation);

  void addManualGoal(ActiveGoal goal) => _manualGoals.add(goal);

  void setSafetyBuffer(double buffer) {
    _safetyBuffer = buffer;
    _safetyBufferChanged = true;
  }

  @override
  Future<FinancialStateSnapshot> fetchSnapshot(String userId) async {
    final stages = await _loader.loadStages();
    final stage = stages.firstWhere(
      (s) => s.stageId == _currentStageId,
      orElse: () => stages.first,
    );
    final base = stage.snapshot;

    if (_manualBalanceDelta == 0 &&
        _openingBalanceOverride == null &&
        _manualObligations.isEmpty &&
        _manualGoals.isEmpty &&
        !_safetyBufferChanged) {
      return base;
    }

    final checking = (_openingBalanceOverride ?? base.currentBalances.checking) + _manualBalanceDelta;
    final mergedObligations = [...base.upcomingObligations, ..._manualObligations];
    final mergedGoals = [...base.activeGoals, ..._manualGoals];
    final obligationsTotal = mergedObligations.fold(0.0, (sum, o) => sum + o.amount);
    // Mirrors calculate_safe_to_spend on the real backend so mock mode's
    // safe-to-spend behaves consistently with live mode.
    final safeToSpend = (checking - obligationsTotal - _safetyBuffer).clamp(0.0, double.infinity);

    return FinancialStateSnapshot(
      userId: base.userId,
      lastUpdated: DateTime.now(),
      currentBalances: CurrentBalances(
        checking: checking,
        savings: base.currentBalances.savings,
        other: base.currentBalances.other,
      ),
      projectedIncome30Days: base.projectedIncome30Days,
      upcomingObligations: mergedObligations,
      activeGoals: mergedGoals,
      safeToSpend: safeToSpend,
      shortfallProbability30d: base.shortfallProbability30d,
    );
  }
}
