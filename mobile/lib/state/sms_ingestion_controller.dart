import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/normalized_financial_event.dart';
import '../services/api_event_sync_service.dart';
import '../services/api_ingestion_service.dart';
import '../services/event_sync_service.dart';
import '../services/ingestion_service.dart';
import '../services/sms_listener.dart';
import '../utils/bank_sms_filter.dart';
import 'providers.dart' show demoUserId, financialSnapshotProvider;

/// Real bank SMS interception (Android only): listens for incoming SMS
/// while the app is open, filters to likely bank senders, forwards matches
/// to Skandan's real ingestion service to get a structured event, then
/// pushes that event into Sanjani's Financial State so it actually moves
/// the balances/projections the rest of the app is built on -- this is
/// the point of the feature: people with variable/informal income seeing
/// their real balance update as money actually arrives.

final ingestionServiceProvider = Provider<IngestionService>((ref) {
  return ApiIngestionService();
});

final eventSyncServiceProvider = Provider<EventSyncService>((ref) {
  return ApiEventSyncService();
});

final smsListenerProvider = Provider<SmsListener>((ref) {
  return SmsListener();
});

class SmsIngestionState {
  final bool enabled;
  final bool permissionDenied;
  final String? lastError;
  final List<NormalizedFinancialEvent> recentEvents;

  const SmsIngestionState({
    this.enabled = false,
    this.permissionDenied = false,
    this.lastError,
    this.recentEvents = const [],
  });

  SmsIngestionState copyWith({
    bool? enabled,
    bool? permissionDenied,
    String? lastError,
    List<NormalizedFinancialEvent>? recentEvents,
  }) {
    return SmsIngestionState(
      enabled: enabled ?? this.enabled,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      lastError: lastError,
      recentEvents: recentEvents ?? this.recentEvents,
    );
  }
}

class SmsIngestionController extends StateNotifier<SmsIngestionState> {
  SmsIngestionController(this._listener, this._ingestionService, this._eventSync, this._ref)
      : super(const SmsIngestionState());

  final SmsListener _listener;
  final IngestionService _ingestionService;
  final EventSyncService _eventSync;
  final Ref _ref;
  bool _listenerRegistered = false;

  Future<void> enable() async {
    final granted = await _listener.requestPermission();
    if (!granted) {
      state = state.copyWith(permissionDenied: true, enabled: false);
      return;
    }

    // The telephony plugin exposes no "stop listening" call, so the
    // native listener is registered once and left in place; enabled/
    // disabled is enforced by this controller ignoring messages while off.
    if (!_listenerRegistered) {
      _listener.startListening(_handleIncomingSms);
      _listenerRegistered = true;
    }

    state = state.copyWith(enabled: true, permissionDenied: false, lastError: null);
  }

  void disable() {
    state = state.copyWith(enabled: false);
  }

  /// Feeds a message through the exact same path a real incoming SMS
  /// would take (bank-sender filter -> real ingestion HTTP call). Exists
  /// because some bank alerts now arrive over RCS Business Messaging
  /// rather than classic SMS, which never fires `SMS_RECEIVED` and so
  /// can't be captured by [SmsListener] — this lets the rest of the
  /// pipeline still be exercised/tested for real.
  Future<void> simulateIncomingSms(String? sender, String? body) => _handleIncomingSms(sender, body);

  Future<void> _handleIncomingSms(String? sender, String? body) async {
    if (!state.enabled) return;
    if (body == null || body.trim().isEmpty) return;
    if (!looksLikeBankSms(sender)) return;

    NormalizedFinancialEvent? event;
    try {
      event = await _ingestionService.ingestRawText(
        userId: demoUserId,
        source: 'sms',
        rawText: body,
      );
    } catch (_) {
      state = state.copyWith(lastError: 'Could not reach the ingestion service.');
      return;
    }

    if (event == null) return;

    state = state.copyWith(
      recentEvents: [event, ...state.recentEvents].take(10).toList(),
      lastError: null,
    );

    try {
      await _eventSync.submitEvent(event);
      // Balance/projections/weather/twin all derive from this snapshot --
      // refetch so the detected amount is reflected everywhere immediately.
      _ref.invalidate(financialSnapshotProvider);
    } catch (_) {
      state = state.copyWith(
        lastError: 'Detected the event but could not update your balance yet.',
      );
    }
  }
}

final smsIngestionControllerProvider =
    StateNotifierProvider<SmsIngestionController, SmsIngestionState>((ref) {
  return SmsIngestionController(
    ref.watch(smsListenerProvider),
    ref.watch(ingestionServiceProvider),
    ref.watch(eventSyncServiceProvider),
    ref,
  );
});
