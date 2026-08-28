import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:finsentinel/models/financial_state_snapshot.dart';
import 'package:finsentinel/models/intervention.dart';

Map<String, dynamic> _loadFixture(String name) {
  final raw = File('test/fixtures/$name').readAsStringSync();
  return jsonDecode(raw) as Map<String, dynamic>;
}

/// These fixtures represent the ACTUAL expected shape of Sanjani's and
/// Sameer's real backend responses (Contracts 2 & 3 in
/// docs/api_contracts.md), sanitized for testing. They are not the
/// hackathon demo scenario in assets/mock/ — that drives the scripted UI
/// walkthrough; these drive contract-parsing correctness.
void main() {
  group('Financial State Snapshot fixtures', () {
    test('parses the standard fixture (optional field present)', () {
      final snapshot = FinancialStateSnapshot.fromJson(_loadFixture('financial_state_snapshot.json'));

      expect(snapshot.userId, 'usr_123');
      expect(snapshot.currentBalances.checking, 1250.00);
      expect(snapshot.currentBalances.savings, 5000.00);
      expect(snapshot.projectedIncome30Days.estimatedAmount, 3200.00);
      expect(snapshot.projectedIncome30Days.variance, 400.00);
      expect(snapshot.upcomingObligations, hasLength(1));
      expect(snapshot.upcomingObligations.single.category, ObligationCategory.fixedEssential);
      expect(snapshot.activeGoals.single.priority, GoalPriority.high);
      expect(snapshot.safeToSpend, 150.00);
      expect(snapshot.shortfallProbability30d, 0.34);
    });

    test('parses the optional-fields-absent fixture identically apart from the optional field', () {
      final snapshot =
          FinancialStateSnapshot.fromJson(_loadFixture('financial_state_snapshot_no_optional_fields.json'));

      expect(snapshot.userId, 'usr_123');
      expect(snapshot.safeToSpend, 150.00);
      expect(snapshot.shortfallProbability30d, isNull);
    });
  });

  group('Contextual Intervention fixtures', () {
    test('parses the standard fixture with decision_trace present', () {
      final intervention = ContextualIntervention.fromJson(_loadFixture('contextual_intervention.json'));

      expect(intervention.interventionId, 'int_456');
      expect(intervention.severity, InterventionSeverity.high);
      expect(intervention.suggestedActions, hasLength(2));
      expect(intervention.suggestedActions.first.requiresUserApproval, isTrue);
      expect(intervention.suggestedActions.last.requiresUserApproval, isFalse);
      expect(intervention.decisionTrace, isNotNull);
      expect(intervention.effectiveDecisionTrace, intervention.decisionTrace);
    });

    test('parses the low-risk fixture (info severity, optional fields absent)', () {
      final intervention = ContextualIntervention.fromJson(_loadFixture('intervention_low_risk.json'));

      expect(intervention.severity, InterventionSeverity.info);
      expect(intervention.title, "You're on track");
      expect(intervention.decisionTrace, isNull);
      // Falls back to a derived trace so the Decision Trace screen still renders.
      expect(intervention.effectiveDecisionTrace, isNotEmpty);
    });

    test('parses the high-risk fixture (high severity, approval-required action)', () {
      final intervention = ContextualIntervention.fromJson(_loadFixture('intervention_high_risk.json'));

      expect(intervention.severity, InterventionSeverity.high);
      expect(intervention.suggestedActions.any((a) => a.requiresUserApproval), isTrue);
      expect(intervention.decisionTrace, isNotNull);
      expect(intervention.decisionTrace, hasLength(4));
    });
  });
}
