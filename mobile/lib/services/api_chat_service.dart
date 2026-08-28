import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/financial_state_snapshot.dart';
import 'api_config.dart';
import 'chat_service.dart';
import 'service_exceptions.dart';

/// Real implementation of [ChatService], calling Sameer's AI Brain
/// endpoint: `POST {baseUrl}/api/chat/{user_id}`.
///
/// Request body: `{"question": "...", "snapshot": <Financial State
/// Snapshot JSON>}`. The backend answers using only the facts in that
/// snapshot via Groq, with a deterministic local fallback if the API key
/// is missing or the call fails on his side -- so this always gets a
/// real, grounded answer, not a scripted one.
class ApiChatService implements ChatService {
  ApiChatService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.sameerBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<String> ask(String question, FinancialStateSnapshot snapshot) async {
    final uri = Uri.parse('$_baseUrl/api/chat/${snapshot.userId}');

    late http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'question': question, 'snapshot': snapshot.toJson()}),
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

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['answer'] as String? ?? '';
    } catch (_) {
      throw const MalformedResponseException();
    }
  }
}
