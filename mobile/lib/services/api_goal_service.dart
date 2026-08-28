import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'goal_service.dart';
import 'service_exceptions.dart';

/// Real implementation of [GoalService], calling Sanjani's State Engine:
/// `POST {baseUrl}/goals`.
class ApiGoalService implements GoalService {
  ApiGoalService({http.Client? client, String? baseUrl, String? userId})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.sanjaniBaseUrl,
        _userId = userId ?? 'usr_123';

  final http.Client _client;
  final String _baseUrl;
  final String _userId;

  @override
  Future<void> addGoal({
    required String name,
    required double targetAmount,
    double currentAmount = 0.0,
    String priority = 'medium',
    DateTime? deadline,
  }) async {
    final uri = Uri.parse('$_baseUrl/goals');

    late http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': _userId,
              'name': name,
              'target_amount': targetAmount,
              'current_amount': currentAmount,
              'priority': priority,
              if (deadline != null) 'deadline': deadline.toIso8601String(),
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
