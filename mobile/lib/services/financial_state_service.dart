import '../models/financial_state_snapshot.dart';

/// Abstraction over "where the Financial State Snapshot comes from".
///
/// The UI depends only on this interface, never on HTTP or mock details
/// directly. Swap [MockFinancialStateService] for
/// [ApiFinancialStateService] at the provider wiring layer
/// (see lib/state/providers.dart) with zero screen/widget changes.
abstract class FinancialStateService {
  Future<FinancialStateSnapshot> fetchSnapshot(String userId);
}
