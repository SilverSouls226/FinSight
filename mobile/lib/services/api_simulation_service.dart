import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/financial_state_snapshot.dart';
import '../models/simulation_result.dart';
import 'api_config.dart';
import 'service_exceptions.dart';
import 'simulation_service.dart';

/// Real implementation of [SimulationService], calling Sanjani's State
/// Engine: `POST {baseUrl}/simulate/{user_id}?proposed_expense={amount}`.
///
/// Route and response shape confirmed directly from her real service
/// (member2_state_engine/app/api/endpoints.py, `simulate_scenario`):
/// `{"user_id", "proposed_expense", "base_shortfall_risk_percent",
/// "new_shortfall_risk_percent", "is_safe"}` — risk as 0-100 percentages,
/// not 0-1 fractions like the rest of this app, so this class converts.
///
/// Her endpoint doesn't return a post-purchase safe-to-spend figure or a
/// human-readable recommendation, so those two are still derived locally
/// from the snapshot + her real risk numbers — presentation only, not a
/// financial decision. The risk percentages and the is_safe flag, which
/// ARE the financial decision, come entirely from her real Monte Carlo
/// simulation. Flutter never computes shortfall risk itself.
class ApiSimulationService implements SimulationService {
  ApiSimulationService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.sanjaniBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<SimulationResult> simulatePurchase({
    required FinancialStateSnapshot snapshot,
    required double purchaseAmount,
  }) async {
    final uri = Uri.parse('$_baseUrl/simulate/${snapshot.userId}').replace(
      queryParameters: {'proposed_expense': purchaseAmount.toString()},
    );

    late http.Response response;
    try {
      response = await _client.post(uri).timeout(ApiConfig.requestTimeout);
    } on TimeoutException {
      throw const ServiceTimeoutException();
    } catch (_) {
      throw const ServiceUnavailableException();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ServiceUnavailableException();
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const MalformedResponseException();
    }

    final baseRiskPercent = _toDouble(json['base_shortfall_risk_percent']);
    final newRiskPercent = _toDouble(json['new_shortfall_risk_percent']);
    final isSafe = json['is_safe'] as bool?;
    if (baseRiskPercent == null || newRiskPercent == null || isSafe == null) {
      throw const MalformedResponseException();
    }

    final baselineRisk = (baseRiskPercent / 100).clamp(0.0, 1.0);
    final projectedRisk = (newRiskPercent / 100).clamp(0.0, 1.0);
    final safeToSpendAfter = snapshot.safeToSpend - purchaseAmount;

    final String recommendation;
    if (!isSafe) {
      recommendation =
          'Not recommended right now. This purchase would push your shortfall '
          'risk to ${(projectedRisk * 100).round()}% (per Sanjani\'s Monte Carlo '
          'simulation). Consider waiting until your next income lands, or '
          'reduce the amount.';
    } else if (projectedRisk - baselineRisk > 0.1) {
      recommendation =
          'Affordable, but it noticeably raises your risk (from '
          '${(baselineRisk * 100).round()}% to ${(projectedRisk * 100).round()}%). '
          'Proceed only if this purchase is a priority.';
    } else {
      recommendation =
          'This purchase fits comfortably within your safe-to-spend buffer '
          'with minimal impact on shortfall risk.';
    }

    return SimulationResult(
      purchaseAmount: purchaseAmount,
      shortfallRiskWithoutPurchase: baselineRisk,
      shortfallRiskWithPurchase: projectedRisk,
      safeToSpendAfterPurchase: safeToSpendAfter,
      recommendation: recommendation,
      isAffordable: isSafe,
    );
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
