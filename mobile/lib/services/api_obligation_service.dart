import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'obligation_service.dart';
import 'service_exceptions.dart';

/// Real implementation of [ObligationService], calling Sanjani's State
/// Engine: `POST {baseUrl}/obligations`.
class ApiObligationService implements ObligationService {
  ApiObligationService({http.Client? client, String? baseUrl, String? userId})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.sanjaniBaseUrl,
        _userId = userId ?? 'usr_123';

  final http.Client _client;
  final String _baseUrl;
  final String _userId;

  @override
  Future<void> addObligation({
    required String name,
    required double amount,
    required DateTime dueDate,
    required String recurrence,
    String category = 'fixed_essential',
    String currency = 'INR',
  }) async {
    final uri = Uri.parse('$_baseUrl/obligations');

    late http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': _userId,
              'name': name,
              'amount': amount,
              'due_date': dueDate.toIso8601String(),
              'category': category,
              'recurrence': recurrence,
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
