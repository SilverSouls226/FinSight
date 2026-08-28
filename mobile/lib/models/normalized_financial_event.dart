/// Dart model for the "Normalized Financial Event" contract.
///
/// Source of truth: docs/api_contracts.md, Contract 1
/// (Skandan's Ingestion -> Sanjani's State Engine). Flutter doesn't
/// consume this contract from Sanjani — it's only relevant here because
/// the app itself now calls Skandan's `POST /ingest` directly (real SMS
/// interception -> ingestion), and needs to parse what comes back to show
/// the user what was just detected.
library;

class NormalizedFinancialEvent {
  final String eventId;
  final String userId;
  final DateTime timestamp;
  final String source;
  final String type;
  final double amount;
  final String currency;
  final String vendor;
  final double confidenceScore;
  final bool isRecurring;

  const NormalizedFinancialEvent({
    required this.eventId,
    required this.userId,
    required this.timestamp,
    required this.source,
    required this.type,
    required this.amount,
    required this.currency,
    required this.vendor,
    required this.confidenceScore,
    required this.isRecurring,
  });

  factory NormalizedFinancialEvent.fromJson(Map<String, dynamic> json) {
    return NormalizedFinancialEvent(
      eventId: json['event_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      source: json['source'] as String? ?? '',
      type: json['type'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? '',
      vendor: json['vendor'] as String? ?? '',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      isRecurring: json['is_recurring'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'event_id': eventId,
        'user_id': userId,
        'timestamp': timestamp.toIso8601String(),
        'source': source,
        'type': type,
        'amount': amount,
        'currency': currency,
        'vendor': vendor,
        'confidence_score': confidenceScore,
        'is_recurring': isRecurring,
      };
}
