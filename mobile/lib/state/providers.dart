import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/demo_scenario.dart';
import '../models/financial_state_snapshot.dart';
import '../models/intervention.dart';
import '../models/user_profile.dart';
import '../services/api_financial_state_service.dart';
import '../services/api_intervention_service.dart';
import '../services/financial_state_service.dart';
import '../services/intervention_service.dart';
import '../services/mock_financial_state_service.dart';
import '../services/mock_intervention_service.dart';
import '../services/simulation_service.dart';
import '../services/user_profile_storage.dart';

/// ---------------------------------------------------------------------
/// INTEGRATION SWITCH
/// ---------------------------------------------------------------------
/// Flip this to `false` and set a real ApiConfig.baseUrl (see
/// lib/services/api_config.dart) to switch the entire app from mock data
/// to Sanjani's/Sameer's live APIs. No screen or widget code changes.
const bool useMockServices = true;

const String demoUserId = 'usr_123';

/// ---------------------------------------------------------------------
/// Service wiring
/// ---------------------------------------------------------------------

final demoScenarioLoaderProvider = Provider<DemoScenarioLoader>((ref) {
  return DemoScenarioLoader();
});

final demoStagesProvider = FutureProvider<List<DemoStage>>((ref) async {
  final loader = ref.watch(demoScenarioLoaderProvider);
  return loader.loadStages();
});

final financialStateServiceProvider = Provider<FinancialStateService>((ref) {
  if (useMockServices) {
    return MockFinancialStateService(loader: ref.watch(demoScenarioLoaderProvider));
  }
  return ApiFinancialStateService();
});

final interventionServiceProvider = Provider<InterventionService>((ref) {
  if (useMockServices) {
    return MockInterventionService(loader: ref.watch(demoScenarioLoaderProvider));
  }
  // Sameer's evaluate endpoint takes a Financial State Snapshot as input,
  // so the intervention service depends on the financial state service to
  // build its request body (see api_intervention_service.dart).
  return ApiInterventionService(
    financialStateService: ref.watch(financialStateServiceProvider),
  );
});

final simulationServiceProvider = Provider<SimulationService>((ref) {
  return MockSimulationService();
});

/// ---------------------------------------------------------------------
/// Demo scenario stage control (mock-mode only)
/// ---------------------------------------------------------------------
/// Drives the scripted judging story: stable -> pressure -> resolved.
/// See docs' "Demo Flow" requirement.

final currentStageIdProvider = StateProvider<String>((ref) => 'stable');

/// ---------------------------------------------------------------------
/// Financial State Snapshot (re-fetches whenever the demo stage changes)
/// ---------------------------------------------------------------------

final financialSnapshotProvider =
    FutureProvider<FinancialStateSnapshot>((ref) async {
  final stageId = ref.watch(currentStageIdProvider);
  final service = ref.watch(financialStateServiceProvider);
  if (service is MockFinancialStateService) {
    service.setStage(stageId);
  }
  return service.fetchSnapshot(demoUserId);
});

/// ---------------------------------------------------------------------
/// Contextual Interventions (re-fetches whenever the demo stage changes)
/// ---------------------------------------------------------------------

final interventionsProvider =
    FutureProvider<List<ContextualIntervention>>((ref) async {
  final stageId = ref.watch(currentStageIdProvider);
  final service = ref.watch(interventionServiceProvider);
  if (service is MockInterventionService) {
    service.setStage(stageId);
  }
  return service.fetchInterventions(demoUserId);
});

/// ---------------------------------------------------------------------
/// Onboarding / user profile (local, on-device, persisted)
/// ---------------------------------------------------------------------

final userProfileStorageProvider = Provider<UserProfileStorage>((ref) {
  return UserProfileStorage();
});

class UserProfileController extends StateNotifier<UserProfile?> {
  UserProfileController(this._storage, {UserProfile? initial}) : super(initial);

  final UserProfileStorage _storage;

  void complete(UserProfile profile) {
    state = profile;
    _storage.save(profile);
  }

  void reset() {
    state = null;
    _storage.clear();
  }
}

/// Default wiring: starts with no saved profile (onboarding shows).
/// main.dart overrides this with the profile loaded from disk (if any)
/// before the first frame, so a returning user skips onboarding.
final userProfileProvider =
    StateNotifierProvider<UserProfileController, UserProfile?>(
  (ref) => UserProfileController(ref.watch(userProfileStorageProvider)),
);

/// ---------------------------------------------------------------------
/// Bottom navigation index for the root shell
/// ---------------------------------------------------------------------

final rootTabIndexProvider = StateProvider<int>((ref) => 0);
