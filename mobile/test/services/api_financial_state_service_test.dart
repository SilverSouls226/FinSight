import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:finsentinel/services/api_financial_state_service.dart';
import 'package:finsentinel/services/service_exceptions.dart';

String _readFixture(String name) => File('test/fixtures/$name').readAsStringSync();

void main() {
  group('ApiFinancialStateService', () {
    test('parses a successful 200 response into a FinancialStateSnapshot', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/users/usr_123/financial-state');
        return http.Response(_readFixture('financial_state_snapshot.json'), 200);
      });

      final service = ApiFinancialStateService(client: client, baseUrl: 'https://api.test');
      final snapshot = await service.fetchSnapshot('usr_123');

      expect(snapshot.userId, 'usr_123');
      expect(snapshot.currentBalances.checking, 1250.00);
      expect(snapshot.safeToSpend, 150.00);
      expect(snapshot.shortfallProbability30d, 0.34);
    });

    test('parses successfully even when optional fields are absent from the backend', () async {
      final client = MockClient((request) async {
        return http.Response(
          _readFixture('financial_state_snapshot_no_optional_fields.json'),
          200,
        );
      });

      final service = ApiFinancialStateService(client: client, baseUrl: 'https://api.test');
      final snapshot = await service.fetchSnapshot('usr_123');

      expect(snapshot.shortfallProbability30d, isNull);
      expect(snapshot.safeToSpend, 150.00);
    });

    test('throws ServiceUnavailableException on a 500 response', () async {
      final client = MockClient((request) async => http.Response('Internal Server Error', 500));
      final service = ApiFinancialStateService(client: client, baseUrl: 'https://api.test');

      expect(
        () => service.fetchSnapshot('usr_123'),
        throwsA(isA<ServiceUnavailableException>()),
      );
    });

    test('throws ServiceUnavailableException on a 404 response', () async {
      final client = MockClient((request) async => http.Response('Not Found', 404));
      final service = ApiFinancialStateService(client: client, baseUrl: 'https://api.test');

      expect(
        () => service.fetchSnapshot('usr_123'),
        throwsA(isA<ServiceUnavailableException>()),
      );
    });

    test('throws MalformedResponseException on invalid JSON', () async {
      final client = MockClient((request) async => http.Response('{not valid json', 200));
      final service = ApiFinancialStateService(client: client, baseUrl: 'https://api.test');

      expect(
        () => service.fetchSnapshot('usr_123'),
        throwsA(isA<MalformedResponseException>()),
      );
    });

    test('throws ServiceUnavailableException when the connection fails', () async {
      final client = MockClient((request) async => throw const SocketException('refused'));
      final service = ApiFinancialStateService(client: client, baseUrl: 'https://api.test');

      expect(
        () => service.fetchSnapshot('usr_123'),
        throwsA(isA<ServiceUnavailableException>()),
      );
    });

    test('throws ServiceTimeoutException when the request times out', () async {
      final client = MockClient((request) async => throw TimeoutException('simulated timeout'));
      final service = ApiFinancialStateService(client: client, baseUrl: 'https://api.test');

      expect(
        () => service.fetchSnapshot('usr_123'),
        throwsA(isA<ServiceTimeoutException>()),
      );
    });
  });
}
