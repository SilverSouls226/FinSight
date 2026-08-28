import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:finsentinel/models/financial_state_snapshot.dart';
import 'package:finsentinel/services/api_intervention_service.dart';
import 'package:finsentinel/services/financial_state_service.dart';
import 'package:finsentinel/services/service_exceptions.dart';

String _readFixture(String name) => File('test/fixtures/$name').readAsStringSync();

class _FakeFinancialStateService implements FinancialStateService {
  @override
  Future<FinancialStateSnapshot> fetchSnapshot(String userId) async {
    return FinancialStateSnapshot.fromJson(
      jsonDecode(_readFixture('financial_state_snapshot.json')) as Map<String, dynamic>,
    );
  }
}

void main() {
  group('ApiInterventionService (Sameer\'s POST /api/evaluate/{user_id})', () {
    test('POSTs the Financial State Snapshot as the request body to the evaluate endpoint', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(_readFixture('intervention_high_risk.json'), 200);
      });

      final service = ApiInterventionService(
        financialStateService: _FakeFinancialStateService(),
        client: client,
        baseUrl: 'https://api.test',
      );

      final result = await service.fetchInterventions('usr_123');

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/evaluate/usr_123');
      final sentBody = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(sentBody['user_id'], 'usr_123');
      expect(sentBody['safe_to_spend'], 150.00);

      expect(result, hasLength(1));
      expect(result.first.severity.name, 'high');
      expect(result.first.title, 'Potential cash-flow collision');
    });

    test('parses a single Contextual Intervention object (not an array) per the contract', () async {
      final client = MockClient((request) async {
        return http.Response(_readFixture('contextual_intervention.json'), 200);
      });
      final service = ApiInterventionService(
        financialStateService: _FakeFinancialStateService(),
        client: client,
        baseUrl: 'https://api.test',
      );

      final result = await service.fetchInterventions('usr_123');
      expect(result, hasLength(1));
      expect(result.first.interventionId, 'int_456');
      expect(result.first.suggestedActions, hasLength(2));
      expect(result.first.suggestedActions.first.requiresUserApproval, isTrue);
      // Second suggested action omits requires_user_approval entirely in the
      // fixture, matching the contract's own example -> must default false.
      expect(result.first.suggestedActions.last.requiresUserApproval, isFalse);
    });

    test('returns an empty list on 204 No Content (no intervention warranted)', () async {
      final client = MockClient((request) async => http.Response('', 204));
      final service = ApiInterventionService(
        financialStateService: _FakeFinancialStateService(),
        client: client,
        baseUrl: 'https://api.test',
      );

      final result = await service.fetchInterventions('usr_123');
      expect(result, isEmpty);
    });

    test('returns an empty list on an empty 200 body', () async {
      final client = MockClient((request) async => http.Response('', 200));
      final service = ApiInterventionService(
        financialStateService: _FakeFinancialStateService(),
        client: client,
        baseUrl: 'https://api.test',
      );

      final result = await service.fetchInterventions('usr_123');
      expect(result, isEmpty);
    });

    test('throws ServiceUnavailableException on a 500 response', () async {
      final client = MockClient((request) async => http.Response('error', 500));
      final service = ApiInterventionService(
        financialStateService: _FakeFinancialStateService(),
        client: client,
        baseUrl: 'https://api.test',
      );

      expect(
        () => service.fetchInterventions('usr_123'),
        throwsA(isA<ServiceUnavailableException>()),
      );
    });

    test('throws MalformedResponseException on invalid JSON', () async {
      final client = MockClient((request) async => http.Response('{bad', 200));
      final service = ApiInterventionService(
        financialStateService: _FakeFinancialStateService(),
        client: client,
        baseUrl: 'https://api.test',
      );

      expect(
        () => service.fetchInterventions('usr_123'),
        throwsA(isA<MalformedResponseException>()),
      );
    });

    test('propagates a snapshot fetch failure without crashing the app', () async {
      final failingSnapshotService = _AlwaysFailsFinancialStateService();
      final client = MockClient((request) async => http.Response('{}', 200));
      final service = ApiInterventionService(
        financialStateService: failingSnapshotService,
        client: client,
        baseUrl: 'https://api.test',
      );

      expect(
        () => service.fetchInterventions('usr_123'),
        throwsA(isA<ServiceUnavailableException>()),
      );
    });
  });
}

class _AlwaysFailsFinancialStateService implements FinancialStateService {
  @override
  Future<FinancialStateSnapshot> fetchSnapshot(String userId) {
    throw const ServiceUnavailableException();
  }
}
