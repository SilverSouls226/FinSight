/// Abstraction over the manual "Add" flow's Obligation form (rent, EMI,
/// subscriptions, utilities). `recurrence` is internal-only -- it rolls
/// `due_date` forward on the backend once passed, but is never part of
/// the FinancialStateSnapshot's UpcomingObligation contract.
abstract class ObligationService {
  Future<void> addObligation({
    required String name,
    required double amount,
    required DateTime dueDate,
    required String recurrence, // once | weekly | monthly | quarterly | yearly
    String category = 'fixed_essential',
    String currency = 'INR',
  });
}
