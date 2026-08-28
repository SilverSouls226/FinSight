import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/intervention.dart';
import 'api_config.dart';
import 'financial_state_service.dart';
import 'intervention_service.dart';
import 'service_exceptions.dart';

/// Real implementation of [InterventionService], calling Sameer's AI Brain
/// endpoint: `POST {baseUrl}/api/evaluate/{user_id}`.
///
/// Per the integration spec, that endpoint takes the current
/// "Financial State Snapshot" JSON as its request body (Contract 2 in
/// docs/api_contracts.md) and returns a single "Contextual Intervention"
/// JSON object (Contract 3) — not a list, and not GET. This class fetches
/// the snapshot via [FinancialStateService] (never a database, never
/// backend code) to build that request body.
///
/// [fetchInterventions] still returns `List<ContextualIntervention>` to
/// match [InterventionService], so nothing above this class (providers,
/// screens) needs to change: the single evaluated intervention is wrapped
/// in a one-element list, or an empty list when the backend has nothing
/// to say (204 No Content, or an empty/null body).
class ApiInterventionService implements InterventionService {
  ApiInterventionService({
    required this.financialStateService,
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.sameerBaseUrl;

  final FinancialStateService financialStateService;
  final http.Client _client;
  final String _baseUrl;

  @override
  Future<List<ContextualIntervention>> fetchInterventions(String userId) async {
    final snapshot = await financialStateService.fetchSnapshot(userId);
    final uri = Uri.parse('$_baseUrl/api/evaluate/$userId');

    late http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(snapshot.toJson()),
          )
          .timeout(ApiConfig.requestTimeout);
    } on TimeoutException {
      throw const ServiceTimeoutException();
    } catch (_) {
      throw const ServiceUnavailableException();
    }

    if (response.statusCode == 204) {
      // No intervention warranted right now — a valid, non-error outcome.
      return const [];
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ServiceUnavailableException();
    }

    if (response.body.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(response.body);

      // Contract is a single object; accept a bare list or {"interventions": [...]}
      // defensively too, so a future backend shape change degrades gracefully
      // rather than breaking parsing outright.
      if (decoded == null) return const [];
      if (decoded is List) {
        return decoded
            .map((e) => ContextualIntervention.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      final map = decoded as Map<String, dynamic>;
      if (map.containsKey('interventions')) {
        return (map['interventions'] as List)
            .map((e) => ContextualIntervention.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (map.isEmpty) return const [];
      return [ContextualIntervention.fromJson(map)];
    } catch (_) {
      throw const MalformedResponseException();
    }
  }
}
