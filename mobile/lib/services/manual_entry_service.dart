/// Abstraction over the manual "Add" flow's Income / Expense / Opening
/// balance forms. Each ultimately becomes a NormalizedFinancialEvent
/// (source="user_input", confidence_score=1.0) on the backend, but the UI
/// never builds that event itself -- see ApiManualEntryService.
abstract class ManualEntryService {
  Future<void> addIncome({
    required double amount,
    required String vendor,
    DateTime? date,
    bool isRecurring = false,
    String currency = 'INR',
  });

  Future<void> addExpense({
    required double amount,
    required String vendor,
    DateTime? date,
    String currency = 'INR',
  });

  /// A one-time income event with vendor fixed to "Opening Balance" --
  /// lets a brand-new user who isn't stuck at Rs0 set a starting point.
  Future<void> addOpeningBalance({
    required double amount,
    String currency = 'INR',
  });
}
