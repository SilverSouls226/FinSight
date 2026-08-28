import '../mock/demo_scenario.dart';
import '../models/financial_state_snapshot.dart';
import 'financial_state_service.dart';

/// Serves Financial State Snapshots from the bundled demo scenario asset.
///
/// Fully offline. [setStage] lets the demo controller advance the scripted
/// narrative (stable -> pressure -> resolved); `fetchSnapshot` always
/// returns whatever stage is currently selected.
class MockFinancialStateService implements FinancialStateService {
  MockFinancialStateService({DemoScenarioLoader? loader})
      : _loader = loader ?? DemoScenarioLoader();

  final DemoScenarioLoader _loader;
  String _currentStageId = 'stable';

  void setStage(String stageId) {
    _currentStageId = stageId;
  }

  String get currentStageId => _currentStageId;

  @override
  Future<FinancialStateSnapshot> fetchSnapshot(String userId) async {
    final stages = await _loader.loadStages();
    final stage = stages.firstWhere(
      (s) => s.stageId == _currentStageId,
      orElse: () => stages.first,
    );
    return stage.snapshot;
  }
}
