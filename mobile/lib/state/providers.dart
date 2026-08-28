import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/demo_scenario.dart';
import '../models/financial_state_snapshot.dart';
import '../models/intervention.dart';
import '../models/user_profile.dart';
import '../services/api_financial_state_service.dart';
import '../services/api_intervention_service.dart';
import '../services/api_simulation_service.dart';
import '../services/financial_state_service.dart';
import '../services/intervention_service.dart';
import '../services/mock_financial_state_service.dart';
import '../services/mock_intervention_service.dart';
import '../services/simulation_service.dart';
import '../services/user_profile_storage.dart';

/// ---------------------------------------------------------------------
/// INTEGRATION SWITCHES
/// ---------------------------------------------------------------------
/// Two independent flags so either backend can be flipped to live
/// independently of the other. Set the matching ApiConfig base URL (see
/// lib/services/api_config.dart) alongside either flip. No screen or
/// widget code changes required either way.
///
/// integration/full-team: BOTH Sanjani's State Engine
/// (GET /financial-state/{user_id}) and Sameer's AI Brain
/// (POST /api/evaluate/{user_id}) are confirmed live and integration-tested
/// here, so both are false on this branch. Flip either back to true to
/// return that piece to offline mock mode.
const bool useMockFinancialState = false;

const bool useMockIntervention = false;

/// Backward-compat convenience: true only when both backends are mocked —
/// i.e. the default, fully-offline hackathon-demo configuration. Used
/// purely to gate the judge-facing "Demo scenario" panel on Home.
const bool useMockServices = useMockFinancialState && useMockIntervention;

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
  if (useMockFinancialState) {
    return MockFinancialStateService(loader: ref.watch(demoScenarioLoaderProvider));
  }
  return ApiFinancialStateService();
});

final interventionServiceProvider = Provider<InterventionService>((ref) {
  if (useMockIntervention) {
    return MockInterventionService(loader: ref.watch(demoScenarioLoaderProvider));
  }
  // Sameer's evaluate endpoint takes a Financial State Snapshot as input,
  // so the intervention service depends on the financial state service to
  // build its request body (see api_intervention_service.dart). This works
  // whether financialStateServiceProvider above is Mock or Api — the real
  // Sameer backend doesn't know or care whether the snapshot it receives
  // came from a mock or from Sanjani's live State API.
  return ApiInterventionService(
    financialStateService: ref.watch(financialStateServiceProvider),
  );
});

final simulationServiceProvider = Provider<SimulationService>((ref) {
  // Sanjani's real /simulate/{user_id} endpoint lives on the same State
  // Engine service as financial-state, so this follows that same flag —
  // no separate "useMockSimulation" flag needed.
  if (useMockFinancialState) {
    return MockSimulationService();
  }
  return ApiSimulationService();
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
