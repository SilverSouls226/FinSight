import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/normalized_financial_event.dart';
import 'api_config.dart';
import 'ingestion_service.dart';
import 'service_exceptions.dart';

/// Real implementation of [IngestionService], calling Skandan's ingestion
/// service: `POST {baseUrl}/ingest`.
///
/// Request body: `{"user_id", "source", "raw_text"}`. Response: a single
/// `Normalized Financial Event` object (Contract 1). A 422 response means
/// "couldn't parse this / duplicate" — a routine, expected outcome for
/// SMS that isn't a recognizable bank message, not a service failure, so
/// it returns `null` rather than throwing.
class ApiIngestionService implements IngestionService {
  ApiIngestionService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.skandanBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<NormalizedFinancialEvent?> ingestRawText({
    required String userId,
    required String source,
    required String rawText,
  }) async {
    final uri = Uri.parse('$_baseUrl/ingest');

    late http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'user_id': userId, 'source': source, 'raw_text': rawText}),
          )
          .timeout(ApiConfig.requestTimeout);
    } on TimeoutException {
      throw const ServiceTimeoutException();
    } catch (_) {
      throw const ServiceUnavailableException();
    }

    if (response.statusCode == 422) {
      // Not parseable as a bank event, or a duplicate — expected, not an error.
      return null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ServiceUnavailableException();
    }

    try {
      return NormalizedFinancialEvent.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      throw const MalformedResponseException();
    }
  }
}
