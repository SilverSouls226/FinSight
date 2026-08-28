import 'package:flutter_test/flutter_test.dart';

import 'package:finsentinel/models/intervention.dart';

void main() {
  final validJson = {
    'intervention_id': 'int_456',
    'user_id': 'usr_123',
    'timestamp': '2026-08-28T10:10:00Z',
    'severity': 'high',
    'title': 'Upcoming Cash Flow Shortfall',
    'summary': 'You may be short on cash for your rent payment next week.',
    'explanation': 'Your rent of \$1,100 is due on Sept 1st.',
    'suggested_actions': [
      {
        'action_type': 'transfer',
        'description': 'Transfer \$150 from your Emergency Fund to Checking.',
        'requires_user_approval': true,
      },
      {
        'action_type': 'budget_cut',
        'description': 'Pause discretionary spending for 4 days.',
      },
    ],
  };

  group('ContextualIntervention.fromJson', () {
    test('parses every documented contract field correctly', () {
      final intervention = ContextualIntervention.fromJson(validJson);

      expect(intervention.interventionId, 'int_456');
      expect(intervention.severity, InterventionSeverity.high);
      expect(intervention.title, 'Upcoming Cash Flow Shortfall');
      expect(intervention.suggestedActions, hasLength(2));
      expect(intervention.suggestedActions.first.requiresUserApproval, isTrue);
      expect(intervention.suggestedActions.last.requiresUserApproval, isFalse);
    });

    test('defaults to info severity for unknown/missing severity values', () {
      final json = {...validJson, 'severity': 'unknown_value'};
      final intervention = ContextualIntervention.fromJson(json);
      expect(intervention.severity, InterventionSeverity.info);
    });

    test('handles empty suggested_actions gracefully', () {
      final json = {...validJson, 'suggested_actions': []};
      final intervention = ContextualIntervention.fromJson(json);
      expect(intervention.suggestedActions, isEmpty);
    });

    test('handles missing fields without throwing', () {
      final intervention = ContextualIntervention.fromJson(const {});
      expect(intervention.interventionId, '');
      expect(intervention.severity, InterventionSeverity.info);
      expect(intervention.suggestedActions, isEmpty);
    });
  });

  group('decision trace', () {
    test('uses backend-provided decision_trace when present', () {
      final json = {
        ...validJson,
        'decision_trace': [
          {'factor': 'Income decreased', 'detail': 'Freelance payment delayed'},
        ],
      };
      final intervention = ContextualIntervention.fromJson(json);
      expect(intervention.effectiveDecisionTrace, hasLength(1));
      expect(intervention.effectiveDecisionTrace.first.factor, 'Income decreased');
    });

    test('falls back to explanation-derived trace when absent', () {
      final intervention = ContextualIntervention.fromJson(validJson);
      expect(intervention.decisionTrace, isNull);
      expect(intervention.effectiveDecisionTrace, isNotEmpty);
    });
  });
}
