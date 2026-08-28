import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'manual_entry_service.dart';
import 'service_exceptions.dart';

/// Real implementation of [ManualEntryService], calling Sanjani's State
/// Engine: `POST {baseUrl}/entries`.
///
/// Request body matches Contract-adjacent `ManualEntryCreate`:
/// `{"user_id", "type", "amount", "vendor", "date"?, "is_recurring", "currency"}`.
/// The server builds the actual NormalizedFinancialEvent (event_id,
/// source="user_input", confidence_score=1.0) -- this client never
/// constructs one itself, matching the "manual entries always use
/// source=user_input and confidence_score=1.0" rule by construction.
class ApiManualEntryService implements ManualEntryService {
  ApiManualEntryService({http.Client? client, String? baseUrl, String? userId})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.sanjaniBaseUrl,
        _userId = userId ?? 'usr_123';

  final http.Client _client;
  final String _baseUrl;
  final String _userId;

  Future<void> _post(Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl/entries');

    late http.Response response;
    try {
      response = await _client
          .post(uri, headers: const {'Content-Type': 'application/json'}, body: jsonEncode(body))
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

  @override
  Future<void> addIncome({
    required double amount,
    required String vendor,
    DateTime? date,
    bool isRecurring = false,
    String currency = 'INR',
  }) {
    return _post({
      'user_id': _userId,
      'type': 'income',
      'amount': amount,
      'vendor': vendor,
      if (date != null) 'date': date.toIso8601String(),
      'is_recurring': isRecurring,
      'currency': currency,
    });
  }

  @override
  Future<void> addExpense({
    required double amount,
    required String vendor,
    DateTime? date,
    String currency = 'INR',
  }) {
    return _post({
      'user_id': _userId,
      'type': 'expense',
      'amount': amount,
      'vendor': vendor,
      if (date != null) 'date': date.toIso8601String(),
      'is_recurring': false,
      'currency': currency,
    });
  }

  @override
  Future<void> addOpeningBalance({required double amount, String currency = 'INR'}) {
    return _post({
      'user_id': _userId,
      'type': 'income',
      'amount': amount,
      'vendor': 'Opening Balance',
      'is_recurring': false,
      'currency': currency,
    });
  }
}
