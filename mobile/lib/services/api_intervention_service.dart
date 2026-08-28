import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/intervention.dart';
import 'api_config.dart';
import 'intervention_service.dart';
import 'service_exceptions.dart';

/// Real implementation of [InterventionService], calling Sameer's AI Brain
/// API: `GET {baseUrl}/users/{userId}/interventions`.
///
/// Response body MUST be a JSON array of "Contextual Intervention" objects
/// as defined in docs/api_contracts.md. Never imports backend/AI code —
/// only speaks JSON over HTTP.
class ApiInterventionService implements InterventionService {
  ApiInterventionService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<List<ContextualIntervention>> fetchInterventions(String userId) async {
    final uri = Uri.parse('$_baseUrl/users/$userId/interventions');

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
      final decoded = jsonDecode(response.body);
      final list = decoded is List
          ? decoded
          : (decoded as Map<String, dynamic>)['interventions'] as List? ?? [];
      return list
          .map((e) => ContextualIntervention.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw const MalformedResponseException();
    }
  }
}
