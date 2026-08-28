import 'manual_entry_service.dart';
import 'mock_financial_state_service.dart';

/// Offline implementation of [ManualEntryService] -- mutates the shared
/// [MockFinancialStateService]'s in-memory overlay so the next snapshot
/// fetch (Home/Twin/Goals) reflects the entry immediately, exactly like
/// the real backend does live.
class MockManualEntryService implements ManualEntryService {
  MockManualEntryService(this._mockState);

  final MockFinancialStateService _mockState;

  @override
  Future<void> addIncome({
    required double amount,
    required String vendor,
    DateTime? date,
    bool isRecurring = false,
    String currency = 'INR',
  }) async {
    _mockState.addManualIncome(amount);
  }

  @override
  Future<void> addExpense({
    required double amount,
    required String vendor,
    DateTime? date,
    String currency = 'INR',
  }) async {
    _mockState.addManualExpense(amount);
  }

  @override
  Future<void> addOpeningBalance({required double amount, String currency = 'INR'}) async {
    _mockState.setOpeningBalance(amount);
  }
}
