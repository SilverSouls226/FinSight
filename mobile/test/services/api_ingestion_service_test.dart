import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:finsentinel/services/api_ingestion_service.dart';
import 'package:finsentinel/services/service_exceptions.dart';

void main() {
  group('ApiIngestionService (Skandan\'s POST /ingest)', () {
    test('POSTs user_id/source/raw_text and parses the returned event', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'event_id': 'evt_1',
            'user_id': 'usr_123',
            'timestamp': '2026-08-28T10:00:00Z',
            'source': 'sms',
            'type': 'income',
            'amount': 800.0,
            'currency': 'INR',
            'vendor': 'FreelanceClient',
            'confidence_score': 0.9,
            'is_recurring': false,
          }),
          200,
        );
      });

      final service = ApiIngestionService(client: client, baseUrl: 'https://api.test');
      final event = await service.ingestRawText(
        userId: 'usr_123',
        source: 'sms',
        rawText: 'Credited INR 800.00 to a/c XX1234 from FreelanceClient.',
      );

      expect(captured.method, 'POST');
      expect(captured.url.path, '/ingest');
      final sentBody = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(sentBody['user_id'], 'usr_123');
      expect(sentBody['source'], 'sms');
      expect(sentBody['raw_text'], contains('FreelanceClient'));

      expect(event, isNotNull);
      expect(event!.amount, 800.0);
      expect(event.vendor, 'FreelanceClient');
    });

    test('returns null (not an error) on 422 - unparseable or duplicate', () async {
      final client = MockClient((request) async => http.Response('{"detail":"nope"}', 422));
      final service = ApiIngestionService(client: client, baseUrl: 'https://api.test');

      final event = await service.ingestRawText(userId: 'usr_123', source: 'sms', rawText: 'not a bank sms');
      expect(event, isNull);
    });

    test('throws ServiceUnavailableException on a 500 response', () async {
      final client = MockClient((request) async => http.Response('error', 500));
      final service = ApiIngestionService(client: client, baseUrl: 'https://api.test');

      expect(
        () => service.ingestRawText(userId: 'usr_123', source: 'sms', rawText: 'x'),
        throwsA(isA<ServiceUnavailableException>()),
      );
    });

    test('throws MalformedResponseException on invalid JSON', () async {
      final client = MockClient((request) async => http.Response('{bad', 200));
      final service = ApiIngestionService(client: client, baseUrl: 'https://api.test');

      expect(
        () => service.ingestRawText(userId: 'usr_123', source: 'sms', rawText: 'x'),
        throwsA(isA<MalformedResponseException>()),
      );
    });

    test('throws ServiceTimeoutException when the request times out', () async {
      final client = MockClient((request) async => throw TimeoutException('simulated timeout'));
      final service = ApiIngestionService(client: client, baseUrl: 'https://api.test');

      expect(
        () => service.ingestRawText(userId: 'usr_123', source: 'sms', rawText: 'x'),
        throwsA(isA<ServiceTimeoutException>()),
      );
    });
  });
}
