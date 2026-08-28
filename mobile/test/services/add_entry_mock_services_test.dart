import 'package:flutter_test/flutter_test.dart';

import 'package:finsentinel/services/mock_financial_state_service.dart';
import 'package:finsentinel/services/mock_goal_service.dart';
import 'package:finsentinel/services/mock_manual_entry_service.dart';
import 'package:finsentinel/services/mock_obligation_service.dart';
import 'package:finsentinel/services/mock_profile_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MockFinancialStateService manual overlay', () {
    test('income and expense deltas adjust checking balance', () async {
      final mockState = MockFinancialStateService();
      final before = await mockState.fetchSnapshot('usr_test');

      mockState.addManualIncome(500.0);
      mockState.addManualExpense(120.0);

      final after = await mockState.fetchSnapshot('usr_test');
      expect(after.currentBalances.checking, before.currentBalances.checking + 500.0 - 120.0);
    });

    test('opening balance override replaces (not adds to) the base balance', () async {
      final mockState = MockFinancialStateService();
      mockState.setOpeningBalance(1000.0);

      final snapshot = await mockState.fetchSnapshot('usr_test');
      expect(snapshot.currentBalances.checking, 1000.0);
    });

    test('opening balance plus a later income delta compose correctly', () async {
      final mockState = MockFinancialStateService();
      mockState.setOpeningBalance(1000.0);
      mockState.addManualIncome(250.0);

      final snapshot = await mockState.fetchSnapshot('usr_test');
      expect(snapshot.currentBalances.checking, 1250.0);
    });

    test('manually added obligations and goals appear in the snapshot', () async {
      final mockState = MockFinancialStateService();
      final manualEntry = MockManualEntryService(mockState);
      final obligations = MockObligationService(mockState);
      final goals = MockGoalService(mockState);

      await manualEntry.addOpeningBalance(amount: 5000.0);
      await obligations.addObligation(
        name: 'Test Rent',
        amount: 1200.0,
        dueDate: DateTime.now().add(const Duration(days: 5)),
        recurrence: 'monthly',
      );
      await goals.addGoal(name: 'Test Goal', targetAmount: 10000.0, currentAmount: 500.0, priority: 'high');

      final snapshot = await mockState.fetchSnapshot('usr_test');
      expect(snapshot.upcomingObligations.any((o) => o.name == 'Test Rent' && o.amount == 1200.0), isTrue);
      expect(snapshot.activeGoals.any((g) => g.name == 'Test Goal' && g.targetAmount == 10000.0), isTrue);
    });

    test('safe_to_spend reacts to a manually-synced safety buffer', () async {
      final mockState = MockFinancialStateService();
      final baseline = await mockState.fetchSnapshot('usr_test');
      final baseObligationsTotal =
          baseline.upcomingObligations.fold(0.0, (sum, o) => sum + o.amount);

      final profileSync = MockProfileSyncService(mockState);
      mockState.setOpeningBalance(10000.0);
      await profileSync.syncProfile(
        name: 'Test User',
        riskTolerance: 'conservative',
        safetyBuffer: 9000.0,
        priorities: const [],
      );

      final snapshot = await mockState.fetchSnapshot('usr_test');
      final expected = (10000.0 - baseObligationsTotal - 9000.0).clamp(0.0, double.infinity);
      expect(snapshot.safeToSpend, expected);
      // With a large enough buffer relative to balance, it should hit the floor.
      expect(snapshot.safeToSpend, greaterThanOrEqualTo(0.0));
    });

    test('a snapshot with no manual entries is returned unmodified', () async {
      final mockState = MockFinancialStateService();
      final direct = await mockState.fetchSnapshot('usr_test');
      final again = await mockState.fetchSnapshot('usr_test');
      expect(again.currentBalances.checking, direct.currentBalances.checking);
      expect(again.upcomingObligations.length, direct.upcomingObligations.length);
    });
  });
}
