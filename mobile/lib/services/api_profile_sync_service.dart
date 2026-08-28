import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'profile_sync_service.dart';
import 'service_exceptions.dart';

/// Real implementation of [ProfileSyncService], calling Sanjani's State
/// Engine: `POST {baseUrl}/users` (upsert).
class ApiProfileSyncService implements ProfileSyncService {
  ApiProfileSyncService({http.Client? client, String? baseUrl, String? userId})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.sanjaniBaseUrl,
        _userId = userId ?? 'usr_123';

  final http.Client _client;
  final String _baseUrl;
  final String _userId;

  @override
  Future<void> syncProfile({
    required String? name,
    required String riskTolerance,
    required double safetyBuffer,
    required List<String> priorities,
    String preferredCurrency = 'INR',
  }) async {
    final uri = Uri.parse('$_baseUrl/users');

    late http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': _userId,
              if (name != null && name.isNotEmpty) 'name': name,
              'risk_tolerance': riskTolerance,
              'safety_buffer': safetyBuffer,
              'priorities': priorities,
              'preferred_currency': preferredCurrency,
            }),
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
