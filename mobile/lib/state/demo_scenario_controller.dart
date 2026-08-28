import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/demo_scenario.dart';
import 'providers.dart';

/// Returns the stage that comes after the currently active one, or null if
/// the scripted demo has reached its final stage.
final nextDemoStageProvider = Provider<AsyncValue<DemoStage?>>((ref) {
  final stagesAsync = ref.watch(demoStagesProvider);
  final currentStageId = ref.watch(currentStageIdProvider);

  return stagesAsync.whenData((stages) {
    final currentIndex = stages.indexWhere((s) => s.stageId == currentStageId);
    if (currentIndex == -1 || currentIndex + 1 >= stages.length) return null;
    return stages[currentIndex + 1];
  });
});

/// Advances the scripted demo scenario to its next stage, if any.
/// Used by the "Simulate next event" control on the Home screen so judges
/// can watch the Financial Weather / risk / interventions update live.
void advanceDemoStage(WidgetRef ref) {
  final next = ref.read(nextDemoStageProvider).valueOrNull;
  if (next != null) {
    ref.read(currentStageIdProvider.notifier).state = next.stageId;
  }
}

/// Resets the scripted demo scenario back to its first stage.
void resetDemoStage(WidgetRef ref) {
  ref.read(currentStageIdProvider.notifier).state = 'stable';
}
