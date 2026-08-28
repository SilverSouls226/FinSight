import 'package:flutter_test/flutter_test.dart';

import 'package:finsentinel/models/normalized_financial_event.dart';

void main() {
  final validJson = {
    'event_id': 'evt_987654321',
    'user_id': 'usr_123',
    'timestamp': '2026-08-28T10:00:00Z',
    'source': 'sms',
    'type': 'expense',
    'amount': 45.50,
    'currency': 'USD',
    'vendor': 'Uber Eats',
    'confidence_score': 0.95,
    'is_recurring': false,
  };

  group('NormalizedFinancialEvent.fromJson', () {
    test('parses every documented contract field correctly', () {
      final event = NormalizedFinancialEvent.fromJson(validJson);

      expect(event.eventId, 'evt_987654321');
      expect(event.userId, 'usr_123');
      expect(event.source, 'sms');
      expect(event.type, 'expense');
      expect(event.amount, 45.50);
      expect(event.currency, 'USD');
      expect(event.vendor, 'Uber Eats');
      expect(event.confidenceScore, 0.95);
      expect(event.isRecurring, isFalse);
    });

    test('round-trips through toJson', () {
      final event = NormalizedFinancialEvent.fromJson(validJson);
      final restored = NormalizedFinancialEvent.fromJson(event.toJson());
      expect(restored.eventId, event.eventId);
      expect(restored.amount, event.amount);
      expect(restored.vendor, event.vendor);
    });

    test('handles missing fields without throwing', () {
      final event = NormalizedFinancialEvent.fromJson(const {});
      expect(event.eventId, '');
      expect(event.amount, 0.0);
      expect(event.isRecurring, isFalse);
    });
  });
}
