import 'package:another_telephony/telephony.dart';

import 'background_sms_handler.dart';

/// Thin wrapper around the `telephony` plugin (Android only) — isolates
/// the rest of the app from the plugin's API so it's swappable/mockable,
/// consistent with every other external integration in this codebase.
///
/// Listens both in the foreground (via [onSms], routed through the normal
/// Riverpod-backed controller) and in the background (via
/// [backgroundSmsHandler], a separate isolate with no UI access) --
/// foreground-only was tried first, but an *outgoing* payment's SMS
/// arrives while the user is necessarily in their UPI app, not this one,
/// so foreground-only detection silently dropped every real debit alert.
class SmsListener {
  final Telephony _telephony = Telephony.instance;

  /// Requests SMS permission. Returns true only if the user granted it.
  Future<bool> requestPermission() async {
    final granted = await _telephony.requestSmsPermissions;
    return granted ?? false;
  }

  /// Starts listening for incoming SMS. [onSms] receives the sender
  /// address and message body for messages that arrive while the app is
  /// in the foreground; messages that arrive while backgrounded are
  /// handled independently by [backgroundSmsHandler].
  void startListening(void Function(String? sender, String? body) onSms) {
    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        onSms(message.address, message.body);
      },
      listenInBackground: true,
      onBackgroundMessage: backgroundSmsHandler,
    );
  }
}
