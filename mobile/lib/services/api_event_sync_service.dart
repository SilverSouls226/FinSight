import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/normalized_financial_event.dart';
import 'api_config.dart';
import 'event_sync_service.dart';
import 'service_exceptions.dart';

/// Real implementation of [EventSyncService], calling Sanjani's State
/// Engine: `POST {baseUrl}/events`.
///
/// Request body: the exact `Normalized Financial Event` object (Contract 1)
/// -- her endpoint applies it directly to the user's checking balance
/// (income adds, expense/bill_due subtracts) and dedupes by `event_id`, so
/// a resend of the same event is a safe no-op, not a double-count.
class ApiEventSyncService implements EventSyncService {
  ApiEventSyncService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.sanjaniBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<void> submitEvent(NormalizedFinancialEvent event) async {
    final uri = Uri.parse('$_baseUrl/events');

    late http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(event.toJson()),
          )
          .timeout(ApiConfig.requestTimeout);
    } on TimeoutException {
      throw const ServiceTimeoutException();
    } catch (_) {
      throw const ServiceUnavailableException();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ServiceUnavailableException();
    }
  }
}
