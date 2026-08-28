import 'package:another_telephony/telephony.dart';
import 'package:flutter/widgets.dart';

import '../state/providers.dart' show demoUserId;
import '../utils/bank_sms_filter.dart';
import 'api_event_sync_service.dart';
import 'api_ingestion_service.dart';

/// Runs in a separate headless Flutter isolate the OS spins up specifically
/// to deliver an SMS while the app is backgrounded -- which is the normal
/// case for an *outgoing* payment, since the user is necessarily in their
/// UPI app (GPay, PhonePe, ...) rather than FinSentinel at the moment the
/// bank's debit SMS arrives.
///
/// Must be a top-level function (not a class method or closure) so the
/// Dart VM can look it up by a stable callback handle across isolates --
/// see `another_telephony`'s `PluginUtilities.getCallbackHandle` usage.
///
/// This isolate has no access to the main isolate's Riverpod state, so it
/// talks to the backends directly rather than going through
/// SmsIngestionController: it re-runs the same filter, ingests via
/// Skandan's service, then syncs into Sanjani's Financial State. There is
/// no UI to update here -- the next time the app is foregrounded,
/// financialSnapshotProvider fetches the real (now-updated) balance.
@pragma('vm:entry-point')
Future<void> backgroundSmsHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();

  final body = message.body;
  if (body == null || body.trim().isEmpty) return;
  if (!looksLikeBankSms(message.address)) return;

  try {
    final event = await ApiIngestionService().ingestRawText(
      userId: demoUserId,
      source: 'sms',
      rawText: body,
    );
    if (event == null) return;
    await ApiEventSyncService().submitEvent(event);
  } catch (_) {
    // Best-effort: nothing to surface an error to from a background
    // isolate. A failed sync here just means the balance won't reflect
    // this event until it's detected again (e.g. a foreground retry).
  }
}
