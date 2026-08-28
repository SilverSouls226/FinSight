import 'package:flutter_test/flutter_test.dart';

import 'package:finsentinel/services/mock_financial_state_service.dart';
import 'package:finsentinel/services/mock_intervention_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MockFinancialStateService', () {
    test('serves the stable stage snapshot by default', () async {
      final service = MockFinancialStateService();
      final snapshot = await service.fetchSnapshot('usr_123');
      expect(snapshot.shortfallProbability30d, closeTo(0.08, 0.001));
    });

    test('reflects the scripted demo flow when the stage advances', () async {
      final service = MockFinancialStateService();

      final stable = await service.fetchSnapshot('usr_123');
      expect(stable.shortfallProbability30d, closeTo(0.08, 0.001));

      service.setStage('pressure');
      final pressure = await service.fetchSnapshot('usr_123');
      expect(pressure.shortfallProbability30d, closeTo(0.41, 0.001));
      expect(pressure.currentBalances.checking, lessThan(stable.currentBalances.checking));

      service.setStage('resolved');
      final resolved = await service.fetchSnapshot('usr_123');
      expect(resolved.shortfallProbability30d, closeTo(0.06, 0.001));
    });

    test('falls back to the first stage for an unknown stage id', () async {
      final service = MockFinancialStateService();
      service.setStage('does-not-exist');
      final snapshot = await service.fetchSnapshot('usr_123');
      expect(snapshot.shortfallProbability30d, closeTo(0.08, 0.001));
    });
  });

  group('MockInterventionService', () {
    test('serves the high-severity collision intervention during pressure stage', () async {
      final service = MockInterventionService();
      service.setStage('pressure');
      final interventions = await service.fetchInterventions('usr_123');

      expect(interventions, isNotEmpty);
      expect(interventions.first.severity.name, 'high');
      expect(interventions.first.suggestedActions, isNotEmpty);
    });

    test('serves an info-severity intervention once resolved', () async {
      final service = MockInterventionService();
      service.setStage('resolved');
      final interventions = await service.fetchInterventions('usr_123');

      expect(interventions, isNotEmpty);
      expect(interventions.first.severity.name, 'info');
    });
  });
}
