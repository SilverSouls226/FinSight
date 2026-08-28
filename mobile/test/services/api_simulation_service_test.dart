import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:finsentinel/models/financial_state_snapshot.dart';
import 'package:finsentinel/services/api_simulation_service.dart';
import 'package:finsentinel/services/service_exceptions.dart';

FinancialStateSnapshot _snapshot() {
  return FinancialStateSnapshot(
    userId: 'usr_123',
    lastUpdated: DateTime(2026, 8, 28),
    currentBalances: const CurrentBalances(checking: 800, savings: 0),
    projectedIncome30Days: const ProjectedIncome(estimatedAmount: 800, variance: 0),
    upcomingObligations: [
      UpcomingObligation(
        name: 'Apartment Rent',
        amount: 1100,
        dueDate: DateTime(2026, 9, 4),
        category: ObligationCategory.fixedEssential,
      ),
    ],
    activeGoals: const [],
    safeToSpend: 0,
  );
}

void main() {
  group('ApiSimulationService (Sanjani\'s POST /simulate/{user_id})', () {
    test('calls the real route with proposed_expense as a query parameter', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          '{"user_id":"usr_123","proposed_expense":12000.0,'
          '"base_shortfall_risk_percent":5.0,"new_shortfall_risk_percent":90.0,'
          '"is_safe":false}',
          200,
        );
      });

      final service = ApiSimulationService(client: client, baseUrl: 'https://api.test');
      await service.simulatePurchase(snapshot: _snapshot(), purchaseAmount: 12000);

      expect(captured.method, 'POST');
      expect(captured.url.path, '/simulate/usr_123');
      expect(captured.url.queryParameters['proposed_expense'], '12000.0');
    });

    test('converts 0-100 percentages from the backend into 0-1 fractions', () async {
      final client = MockClient((request) async => http.Response(
            '{"user_id":"usr_123","proposed_expense":12000.0,'
            '"base_shortfall_risk_percent":5.0,"new_shortfall_risk_percent":90.0,'
            '"is_safe":false}',
            200,
          ));

      final service = ApiSimulationService(client: client, baseUrl: 'https://api.test');
      final result = await service.simulatePurchase(snapshot: _snapshot(), purchaseAmount: 12000);

      expect(result.shortfallRiskWithoutPurchase, closeTo(0.05, 0.0001));
      expect(result.shortfallRiskWithPurchase, closeTo(0.90, 0.0001));
      expect(result.isAffordable, isFalse);
      expect(result.purchaseAmount, 12000);
    });

    test('a safe purchase per the real Monte Carlo result is marked affordable', () async {
      final client = MockClient((request) async => http.Response(
            '{"user_id":"usr_123","proposed_expense":50.0,'
            '"base_shortfall_risk_percent":5.0,"new_shortfall_risk_percent":7.0,'
            '"is_safe":true}',
            200,
          ));

      final service = ApiSimulationService(client: client, baseUrl: 'https://api.test');
      final result = await service.simulatePurchase(snapshot: _snapshot(), purchaseAmount: 50);

      expect(result.isAffordable, isTrue);
    });

    test('throws ServiceUnavailableException on a 500 response', () async {
      final client = MockClient((request) async => http.Response('error', 500));
      final service = ApiSimulationService(client: client, baseUrl: 'https://api.test');

      expect(
        () => service.simulatePurchase(snapshot: _snapshot(), purchaseAmount: 100),
        throwsA(isA<ServiceUnavailableException>()),
      );
    });

    test('throws MalformedResponseException on invalid JSON', () async {
      final client = MockClient((request) async => http.Response('{bad', 200));
      final service = ApiSimulationService(client: client, baseUrl: 'https://api.test');

      expect(
        () => service.simulatePurchase(snapshot: _snapshot(), purchaseAmount: 100),
        throwsA(isA<MalformedResponseException>()),
      );
    });

    test('throws MalformedResponseException when required fields are missing', () async {
      final client = MockClient((request) async => http.Response('{"user_id":"usr_123"}', 200));
      final service = ApiSimulationService(client: client, baseUrl: 'https://api.test');

      expect(
        () => service.simulatePurchase(snapshot: _snapshot(), purchaseAmount: 100),
        throwsA(isA<MalformedResponseException>()),
      );
    });

    test('throws ServiceTimeoutException when the request times out', () async {
      final client = MockClient((request) async => throw TimeoutException('simulated timeout'));
      final service = ApiSimulationService(client: client, baseUrl: 'https://api.test');

      expect(
        () => service.simulatePurchase(snapshot: _snapshot(), purchaseAmount: 100),
        throwsA(isA<ServiceTimeoutException>()),
      );
    });
  });
}
