import '../models/financial_state_snapshot.dart';

/// Abstraction over "answer a freeform question about a Financial State
/// Snapshot" -- backs the Twin Assistant chat card.
abstract class ChatService {
  Future<String> ask(String question, FinancialStateSnapshot snapshot);
}
