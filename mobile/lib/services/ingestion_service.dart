import '../models/normalized_financial_event.dart';

/// Abstraction over "where raw SMS/receipt text gets turned into a
/// Normalized Financial Event" — Skandan's ingestion service.
///
/// Returns `null` (not an error) when the backend couldn't parse the text
/// or flagged it as a duplicate (his `/ingest` returns 422 for both cases)
/// — a message that isn't a recognizable bank SMS is an expected, routine
/// outcome, not a failure.
abstract class IngestionService {
  Future<NormalizedFinancialEvent?> ingestRawText({
    required String userId,
    required String source,
    required String rawText,
  });
}
