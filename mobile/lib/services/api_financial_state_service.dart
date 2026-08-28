import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/financial_state_snapshot.dart';
import 'api_config.dart';
import 'financial_state_service.dart';
import 'service_exceptions.dart';

/// Real implementation of [FinancialStateService], calling Sanjani's
/// State Engine: `GET {baseUrl}/financial-state/{user_id}`.
///
/// Route confirmed directly from Sanjani's real service
/// (member2_state_engine/app/api/endpoints.py) during the full-team
/// integration test — no longer a placeholder guess.
///
/// Response body MUST match the "Financial State Snapshot" contract in
/// docs/api_contracts.md. This class never imports backend code or
/// touches a database — it only speaks JSON over HTTP.
class ApiFinancialStateService implements FinancialStateService {
  ApiFinancialStateService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.sanjaniBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<FinancialStateSnapshot> fetchSnapshot(String userId) async {
    final uri = Uri.parse('$_baseUrl/financial-state/$userId');

    late http.Response response;
    try {
      response = await _client.get(uri).timeout(ApiConfig.requestTimeout);
    } on TimeoutException {
      throw const ServiceTimeoutException();
    } catch (_) {
      throw const ServiceUnavailableException();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ServiceUnavailableException();
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return FinancialStateSnapshot.fromJson(json);
    } catch (_) {
      throw const MalformedResponseException();
    }
  }
}
