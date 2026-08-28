import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finsentinel/app.dart';
import 'package:finsentinel/screens/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('App boots into onboarding when no profile exists', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FinSentinelApp()));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Your Financial Digital Twin'), findsOneWidget);
  });
}
