import '../models/financial_state_snapshot.dart';
import 'goal_service.dart';
import 'mock_financial_state_service.dart';

/// Offline implementation of [GoalService] -- pushes a new [ActiveGoal]
/// into the shared [MockFinancialStateService]'s overlay. `deadline`
/// isn't modeled in mock mode, matching the real contract (it never
/// appears on ActiveGoal either).
class MockGoalService implements GoalService {
  MockGoalService(this._mockState);

  final MockFinancialStateService _mockState;

  @override
  Future<void> addGoal({
    required String name,
    required double targetAmount,
    double currentAmount = 0.0,
    String priority = 'medium',
    DateTime? deadline,
  }) async {
    _mockState.addManualGoal(ActiveGoal.fromJson({
      'name': name,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'priority': priority,
    }));
  }
}
