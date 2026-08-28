import 'package:flutter_test/flutter_test.dart';

import 'package:finsentinel/models/financial_state_snapshot.dart';
import 'package:finsentinel/services/api_financial_state_service.dart';
import 'package:finsentinel/services/api_intervention_service.dart';
import 'package:finsentinel/services/financial_state_service.dart';
import 'package:finsentinel/services/intervention_service.dart';
import 'package:finsentinel/services/mock_financial_state_service.dart';
import 'package:finsentinel/services/mock_intervention_service.dart';
import 'package:finsentinel/state/providers.dart';

class _StubFinancialStateService implements FinancialStateService {
  @override
  Future<FinancialStateSnapshot> fetchSnapshot(String userId) => throw UnimplementedError();
}

void main() {
  group('mock/API service wiring', () {
    test('useMockServices defaults to true for the hackathon demo', () {
      // Guards against accidentally flipping the switch and shipping a
      // build that requires a live backend to demo offline.
      expect(useMockServices, isTrue);
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
    });
  });
}
