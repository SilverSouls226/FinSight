/// Abstraction over the manual "Add" flow's Goal form (savings target).
/// `deadline` is internal-only -- not part of the locked ActiveGoal
/// contract on the FinancialStateSnapshot.
abstract class GoalService {
  Future<void> addGoal({
    required String name,
    required double targetAmount,
    double currentAmount = 0.0,
    String priority = 'medium',
    DateTime? deadline,
  });
}
