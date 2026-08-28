import 'package:another_telephony/telephony.dart';

/// Thin wrapper around the `telephony` plugin (Android only) — isolates
/// the rest of the app from the plugin's API so it's swappable/mockable,
/// consistent with every other external integration in this codebase.
///
/// Foreground-only by design (`listenInBackground: false`): messages are
/// only detected while the app is open. True background SMS interception
/// needs a foreground service + additional manifest wiring, out of scope
/// for this hackathon feature.
class SmsListener {
  final Telephony _telephony = Telephony.instance;

  /// Requests SMS permission. Returns true only if the user granted it.
  Future<bool> requestPermission() async {
    final granted = await _telephony.requestSmsPermissions;
    return granted ?? false;
  }

  /// Starts listening for incoming SMS while the app is in the
  /// foreground. [onSms] receives the sender address and message body.
  void startListening(void Function(String? sender, String? body) onSms) {
    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        onSms(message.address, message.body);
      },
      listenInBackground: false,
    );
  }
}
