import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finsentinel/models/intervention.dart';
import 'package:finsentinel/screens/interventions/intervention_feed_screen.dart';
import 'package:finsentinel/services/intervention_service.dart';
import 'package:finsentinel/state/providers.dart';
import 'package:finsentinel/widgets/empty_state_view.dart';

final _highSeverityIntervention = ContextualIntervention(
  interventionId: 'int_test',
  userId: 'usr_123',
  timestamp: DateTime(2026, 8, 28),
  severity: InterventionSeverity.high,
  title: 'Potential cash-flow collision',
  summary: 'You may be short on cash for rent.',
  explanation: 'Income decreased and rent is approaching.',
  suggestedActions: const [
    SuggestedAction(
      actionType: 'transfer',
      description: 'Transfer funds to cover the gap.',
      requiresUserApproval: true,
    ),
  ],
);

class _FakeInterventionService implements InterventionService {
  final List<ContextualIntervention> interventions;
  _FakeInterventionService(this.interventions);

  @override
  Future<List<ContextualIntervention>> fetchInterventions(String userId) async => interventions;
}

void main() {
  testWidgets('renders a high-severity intervention with its badge', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          interventionServiceProvider.overrideWithValue(
            _FakeInterventionService([_highSeverityIntervention]),
          ),
        ],
        child: const MaterialApp(home: InterventionFeedScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Potential cash-flow collision'), findsOneWidget);
    expect(find.text('HIGH'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no interventions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          interventionServiceProvider.overrideWithValue(_FakeInterventionService(const [])),
        ],
        child: const MaterialApp(home: InterventionFeedScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.text('No active interventions'), findsOneWidget);
  });
}
