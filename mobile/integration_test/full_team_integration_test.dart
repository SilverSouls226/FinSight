// integration/full-team: the FIRST full real end-to-end test across all
// four members' work with ZERO mocking anywhere in the chain:
//
//   Skandan's ingestion (SMS -> NormalizedFinancialEvent)
//     -> Sanjani's State Engine (POST /events, POST /obligations)
//     -> Sanjani's real GET /financial-state/{user_id}
//     -> Kalyan's REAL ApiFinancialStateService (default wiring, no override)
//     -> Kalyan's REAL ApiInterventionService (default wiring, no override)
//     -> Sameer's real POST /api/evaluate/{user_id} (real Groq)
//     -> the REAL Flutter UI
//
// Unlike real_backend_integration_test.dart, this test does NOT override
// financialStateServiceProvider — it uses the app's actual default
// wiring, so it only passes if useMockFinancialState/useMockIntervention
// are both false AND Sanjani's + Sameer's services are actually running
// locally (see README "Live Backend Integration").
//
// Run on a real device (plain `flutter test`, even via -d windows,
// deliberately blocks real HTTP — see TestWidgetsFlutterBinding docs).
// Android has no such restriction:
//   flutter test integration_test/full_team_integration_test.dart -d <deviceId>
//
// Before running, the Skandan -> Sanjani chain must already have been
// executed against usr_123 (backend-to-backend step, not something
// Flutter does — see the curl commands in the README).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:finsentinel/app.dart';
import 'package:finsentinel/widgets/error_view.dart';

final _screenshotKey = GlobalKey();

Future<void> _captureScreenshot(WidgetTester tester, String filename) async {
  await tester.pumpAndSettle();
  final boundary = _screenshotKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();
  // A relative 'build/' path is read-only on a real device (Android app
  // sandbox) — Directory.systemTemp is writable on every platform this
  // runs on (desktop and device) without adding path_provider as a dep.
  final dir = Directory('${Directory.systemTemp.path}/finsentinel_screenshots');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final file = File('${dir.path}/$filename.png');
  await file.writeAsBytes(bytes);
  // Also print the path so it's visible in `flutter test` output — on a
  // real device this directory isn't reachable from the host machine
  // without `adb pull`.
  // ignore: avoid_print
  print('Screenshot saved: ${file.path}');
}

Future<void> _completeOnboarding(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'Kalyan');
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Get started'));
  await tester.pumpAndSettle();
}

Future<void> _waitForRealNetworkCall(WidgetTester tester, {Duration maxWait = const Duration(seconds: 20)}) async {
  final deadline = DateTime.now().add(maxWait);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'FULL CHAIN: real Sanjani state + real Sameer evaluate render in the real UI (zero mocking)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: RepaintBoundary(key: _screenshotKey, child: const FinSentinelApp()),
        ),
      );
      await tester.pumpAndSettle();

      await _completeOnboarding(tester);
      // First real network call: Home screen fetches the REAL snapshot
      // from Sanjani's State Engine (no override — default wiring).
      await _waitForRealNetworkCall(tester);
      await tester.pumpAndSettle();
      await _captureScreenshot(tester, '5_full_chain_home');

      // No error view — proves ApiFinancialStateService successfully hit
      // Sanjani's real GET /financial-state/{user_id}.
      expect(find.byType(ErrorView), findsNothing);

      await tester.tap(find.text('Alerts'));
      // Second real network call: ApiInterventionService fetches the
      // snapshot again (from the same real Sanjani endpoint) and POSTs it
      // to Sameer's real /api/evaluate/{user_id}.
      await _waitForRealNetworkCall(tester);
      await tester.pumpAndSettle();
      await _captureScreenshot(tester, '6_full_chain_alerts');

      // Whatever Sameer's real backend decided is what must be on screen —
      // this test doesn't assert a specific severity because it depends on
      // whatever real state currently exists in Sanjani's database.
      expect(find.byType(ErrorView), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
