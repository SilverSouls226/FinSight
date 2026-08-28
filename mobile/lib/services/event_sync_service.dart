import '../models/normalized_financial_event.dart';

/// Abstraction over "push a Normalized Financial Event into the Financial
/// State". Separate from [IngestionService] (which only turns raw text
/// into a structured event) because it talks to a different backend --
/// Sanjani's State Engine, not Skandan's Ingestion service.
abstract class EventSyncService {
  Future<void> submitEvent(NormalizedFinancialEvent event);
}
