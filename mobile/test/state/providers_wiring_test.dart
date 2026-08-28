import 'package:flutter_test/flutter_test.dart';

import 'package:finsentinel/models/financial_state_snapshot.dart';
import 'package:finsentinel/services/api_financial_state_service.dart';
import 'package:finsentinel/services/api_intervention_service.dart';
import 'package:finsentinel/services/api_simulation_service.dart';
import 'package:finsentinel/services/financial_state_service.dart';
import 'package:finsentinel/services/intervention_service.dart';
import 'package:finsentinel/services/mock_financial_state_service.dart';
import 'package:finsentinel/services/mock_intervention_service.dart';
import 'package:finsentinel/services/simulation_service.dart';
import 'package:finsentinel/state/providers.dart';

class _StubFinancialStateService implements FinancialStateService {
  @override
  Future<FinancialStateSnapshot> fetchSnapshot(String userId) => throw UnimplementedError();
}

void main() {
  group('mock/API service wiring', () {
    test('useMockServices is only true when both backends are mocked', () {
      // useMockServices is a derived convenience (gates the demo panel on
      // Home) — it must never silently diverge from its two inputs.
      expect(useMockServices, useMockFinancialState && useMockIntervention);
    });

    test('Mock* implementations satisfy the same interfaces as Api* implementations', () {
      // This is exactly what lets providers.dart swap one line
      // (useMockServices) without any UI/screen changes: both sides of the
      // switch are interchangeable at the type level.
      final FinancialStateService mockState = MockFinancialStateService();
      final FinancialStateService apiState = ApiFinancialStateService();
      expect(mockState, isA<FinancialStateService>());
      expect(apiState, isA<FinancialStateService>());

      final InterventionService mockIntervention = MockInterventionService();
      final InterventionService apiIntervention = ApiInterventionService(
        financialStateService: _StubFinancialStateService(),
      );
      expect(mockIntervention, isA<InterventionService>());
      expect(apiIntervention, isA<InterventionService>());

      final SimulationService mockSimulation = MockSimulationService();
      final SimulationService apiSimulation = ApiSimulationService();
      expect(mockSimulation, isA<SimulationService>());
      expect(apiSimulation, isA<SimulationService>());
    });
  });
}
