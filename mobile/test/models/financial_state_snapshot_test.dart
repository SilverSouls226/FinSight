import 'package:flutter_test/flutter_test.dart';

import 'package:finsentinel/models/financial_state_snapshot.dart';

void main() {
  group('FinancialStateSnapshot.fromJson', () {
    final validJson = {
      'user_id': 'usr_123',
      'last_updated': '2026-08-28T10:05:00Z',
      'current_balances': {'checking': 1250.00, 'savings': 5000.00},
      'projected_income_30_days': {'estimated_amount': 3200.00, 'variance': 400.00},
      'upcoming_obligations': [
        {
          'name': 'Apartment Rent',
          'amount': 1100.00,
          'due_date': '2026-09-01T00:00:00Z',
          'category': 'fixed_essential',
        }
      ],
      'active_goals': [
        {
          'name': 'Emergency Fund',
          'target_amount': 10000.00,
          'current_amount': 5000.00,
          'priority': 'high',
        }
      ],
      'safe_to_spend': 150.00,
    };

    test('parses every documented contract field correctly', () {
      final snapshot = FinancialStateSnapshot.fromJson(validJson);

      expect(snapshot.userId, 'usr_123');
      expect(snapshot.currentBalances.checking, 1250.00);
      expect(snapshot.currentBalances.savings, 5000.00);
      expect(snapshot.projectedIncome30Days.estimatedAmount, 3200.00);
      expect(snapshot.projectedIncome30Days.variance, 400.00);
      expect(snapshot.upcomingObligations, hasLength(1));
      expect(snapshot.upcomingObligations.first.name, 'Apartment Rent');
      expect(snapshot.upcomingObligations.first.category, ObligationCategory.fixedEssential);
      expect(snapshot.activeGoals.first.priority, GoalPriority.high);
      expect(snapshot.safeToSpend, 150.00);
      expect(snapshot.shortfallProbability30d, isNull);
    });

    test('round-trips through toJson without losing contract fields', () {
      final snapshot = FinancialStateSnapshot.fromJson(validJson);
      final rehydrated = FinancialStateSnapshot.fromJson(snapshot.toJson());

      expect(rehydrated.userId, snapshot.userId);
      expect(rehydrated.safeToSpend, snapshot.safeToSpend);
      expect(rehydrated.upcomingObligations.length, snapshot.upcomingObligations.length);
    });

    test('reads optional shortfall_probability_30d when the backend sends it', () {
      final json = {...validJson, 'shortfall_probability_30d': 0.41};
      final snapshot = FinancialStateSnapshot.fromJson(json);
      expect(snapshot.shortfallProbability30d, 0.41);
    });

    test('handles missing/malformed fields without throwing', () {
      final snapshot = FinancialStateSnapshot.fromJson(const {});

      expect(snapshot.userId, '');
      expect(snapshot.currentBalances.checking, 0.0);
      expect(snapshot.upcomingObligations, isEmpty);
      expect(snapshot.activeGoals, isEmpty);
      expect(snapshot.safeToSpend, 0.0);
    });

    test('preserves unexpected extra keys in current_balances', () {
      final json = {
        ...validJson,
        'current_balances': {'checking': 100.0, 'savings': 200.0, 'investment': 50.0},
      };
      final snapshot = FinancialStateSnapshot.fromJson(json);
      expect(snapshot.currentBalances.other['investment'], 50.0);
      expect(snapshot.currentBalances.total, 350.0);
    });

    test('totalBalance and totalUpcomingObligations are derived correctly', () {
      final snapshot = FinancialStateSnapshot.fromJson(validJson);
      expect(snapshot.totalBalance, 1250.00 + 5000.00);
      expect(snapshot.totalUpcomingObligations, 1100.00);
    });
  });

  group('ActiveGoal.progress', () {
    test('clamps between 0 and 1', () {
      const overfunded = ActiveGoal(
        name: 'Test',
        targetAmount: 100,
        currentAmount: 500,
        priority: GoalPriority.medium,
      );
      expect(overfunded.progress, 1.0);

      const zeroTarget = ActiveGoal(
        name: 'Test',
        targetAmount: 0,
        currentAmount: 50,
        priority: GoalPriority.low,
      );
      expect(zeroTarget.progress, 0.0);
    });
  });
}
