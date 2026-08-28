import '../mock/demo_scenario.dart';
import '../models/intervention.dart';
import 'intervention_service.dart';

/// Serves Contextual Interventions from the bundled demo scenario asset.
///
/// Mirrors [MockFinancialStateService]'s stage concept so the Intervention
/// Feed always matches the currently active Financial State stage.
class MockInterventionService implements InterventionService {
  MockInterventionService({DemoScenarioLoader? loader})
      : _loader = loader ?? DemoScenarioLoader();

  final DemoScenarioLoader _loader;
  String _currentStageId = 'stable';

  void setStage(String stageId) {
    _currentStageId = stageId;
  }

  @override
  Future<List<ContextualIntervention>> fetchInterventions(String userId) async {
    final stages = await _loader.loadStages();
    final stage = stages.firstWhere(
      (s) => s.stageId == _currentStageId,
      orElse: () => stages.first,
    );
    return stage.interventions;
  }
}
