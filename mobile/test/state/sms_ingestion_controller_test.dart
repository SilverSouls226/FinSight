import 'package:flutter_test/flutter_test.dart';

import 'package:finsentinel/models/normalized_financial_event.dart';
import 'package:finsentinel/services/ingestion_service.dart';
import 'package:finsentinel/services/sms_listener.dart';
import 'package:finsentinel/state/sms_ingestion_controller.dart';

typedef SmsHandler = void Function(String? sender, String? body);

class _FakeSmsListener extends SmsListener {
  _FakeSmsListener({this.grantPermission = true});

  final bool grantPermission;
  SmsHandler? registeredHandler;

  @override
  Future<bool> requestPermission() async => grantPermission;

  @override
  void startListening(void Function(String? sender, String? body) onSms) {
    registeredHandler = onSms;
  }

  void simulateIncomingSms(String? sender, String? body) {
    registeredHandler?.call(sender, body);
  }
}

class _FakeIngestionService implements IngestionService {
  _FakeIngestionService({this.result});

  NormalizedFinancialEvent? result;
  int callCount = 0;

  @override
  Future<NormalizedFinancialEvent?> ingestRawText({
    required String userId,
    required String source,
    required String rawText,
  }) async {
    callCount++;
    return result;
  }
}

NormalizedFinancialEvent _event({double amount = 800}) {
  return NormalizedFinancialEvent(
    eventId: 'evt_1',
    userId: 'usr_123',
    timestamp: DateTime(2026, 8, 28),
    source: 'sms',
    type: 'income',
    amount: amount,
    currency: 'INR',
    vendor: 'FreelanceClient',
    confidenceScore: 0.9,
    isRecurring: false,
  );
}

void main() {
  // _FakeSmsListener extends the real SmsListener, whose constructor
  // creates a Telephony instance that registers a platform method-call
  // handler — needs a bound Flutter test environment even though these
  // are plain (non-widget) tests.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmsIngestionController', () {
    test('enable() requests permission and registers a listener', () async {
      final listener = _FakeSmsListener();
      final ingestion = _FakeIngestionService(result: _event());
      final controller = SmsIngestionController(listener, ingestion);

      await controller.enable();

      expect(controller.state.enabled, isTrue);
      expect(controller.state.permissionDenied, isFalse);
      expect(listener.registeredHandler, isNotNull);
    });

    test('sets permissionDenied when the user declines', () async {
      final listener = _FakeSmsListener(grantPermission: false);
      final controller = SmsIngestionController(listener, _FakeIngestionService());

      await controller.enable();

      expect(controller.state.enabled, isFalse);
      expect(controller.state.permissionDenied, isTrue);
    });

    test('ignores SMS from non-bank senders', () async {
      final listener = _FakeSmsListener();
      final ingestion = _FakeIngestionService(result: _event());
      final controller = SmsIngestionController(listener, ingestion);
      await controller.enable();

      listener.simulateIncomingSms('MOM', 'Don\'t forget dinner tonight!');
      await Future<void>.delayed(Duration.zero);

      expect(ingestion.callCount, 0);
      expect(controller.state.recentEvents, isEmpty);
    });

    test('forwards bank SMS to the ingestion service and records the result', () async {
      final listener = _FakeSmsListener();
      final ingestion = _FakeIngestionService(result: _event());
      final controller = SmsIngestionController(listener, ingestion);
      await controller.enable();

      listener.simulateIncomingSms(
        'HDFCBK',
        'Credited INR 800.00 to a/c XX1234 from FreelanceClient.',
      );
      await Future<void>.delayed(Duration.zero);

      expect(ingestion.callCount, 1);
      expect(controller.state.recentEvents, hasLength(1));
      expect(controller.state.recentEvents.first.vendor, 'FreelanceClient');
    });

    test('a 422-equivalent (null result) does not add to recentEvents', () async {
      final listener = _FakeSmsListener();
      final ingestion = _FakeIngestionService(result: null);
      final controller = SmsIngestionController(listener, ingestion);
      await controller.enable();

      listener.simulateIncomingSms('HDFCBK', 'unparseable bank sms text');
      await Future<void>.delayed(Duration.zero);

      expect(ingestion.callCount, 1);
      expect(controller.state.recentEvents, isEmpty);
    });

    test('disable() stops acting on new messages without unregistering the OS listener', () async {
      final listener = _FakeSmsListener();
      final ingestion = _FakeIngestionService(result: _event());
      final controller = SmsIngestionController(listener, ingestion);
      await controller.enable();
      controller.disable();

      listener.simulateIncomingSms('HDFCBK', 'Credited INR 800.00 from FreelanceClient.');
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.enabled, isFalse);
      expect(ingestion.callCount, 0);
    });
  });
}
