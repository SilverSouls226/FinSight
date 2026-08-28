import '../models/financial_state_snapshot.dart';
import 'mock_financial_state_service.dart';
import 'obligation_service.dart';

/// Offline implementation of [ObligationService] -- pushes a new
/// [UpcomingObligation] into the shared [MockFinancialStateService]'s
/// overlay. `recurrence` isn't modeled in mock mode (the real rolling-
/// forward logic lives server-side); the obligation is simply shown as-is.
class MockObligationService implements ObligationService {
  MockObligationService(this._mockState);

  final MockFinancialStateService _mockState;

  @override
  Future<void> addObligation({
    required String name,
    required double amount,
    required DateTime dueDate,
    required String recurrence,
    String category = 'fixed_essential',
    String currency = 'INR',
  }) async {
    _mockState.addManualObligation(UpcomingObligation.fromJson({
      'name': name,
      'amount': amount,
      'due_date': dueDate.toIso8601String(),
      'category': category,
    }));
  }
}
