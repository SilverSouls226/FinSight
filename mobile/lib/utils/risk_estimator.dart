import 'dart:math' as math;

import '../models/financial_state_snapshot.dart';

/// Financial Weather status derived from a snapshot's risk level.
enum FinancialWeather { stable, pressure, storm }

extension FinancialWeatherLabel on FinancialWeather {
  String get label {
    switch (this) {
      case FinancialWeather.stable:
        return 'Stable';
      case FinancialWeather.pressure:
        return 'Pressure';
      case FinancialWeather.storm:
        return 'Storm';
    }
  }

  String get emoji {
    switch (this) {
      case FinancialWeather.stable:
        return '🟢';
      case FinancialWeather.pressure:
        return '🟡';
      case FinancialWeather.storm:
        return '🔴';
    }
  }
}

/// Client-side risk heuristic.
///
/// IMPORTANT: This is a UI-only fallback. Python (Sanjani's forecasting /
/// Monte Carlo engine) is the source of financial truth for risk metrics.
/// This estimator is used ONLY when a snapshot doesn't carry a
/// `shortfall_probability_30d` value (e.g. an older/partial backend
/// response), so the UI never crashes or shows blank risk indicators.
class RiskEstimator {
  const RiskEstimator._();

  /// Returns a 0.0-1.0 shortfall probability estimate.
  static double estimateShortfallProbability(FinancialStateSnapshot snapshot) {
    if (snapshot.shortfallProbability30d != null) {
      return snapshot.shortfallProbability30d!.clamp(0.0, 1.0);
    }

    final buffer = snapshot.currentBalances.checking +
        snapshot.projectedIncome30Days.estimatedAmount -
        snapshot.totalUpcomingObligations;
    final variance = snapshot.projectedIncome30Days.variance;

    if (variance <= 0) {
      return buffer < 0 ? 0.9 : 0.05;
    }

    // Rough normalized-shortfall heuristic: how many "variance units" of
    // buffer exist. Small/negative buffer relative to variance -> high risk.
    final z = buffer / variance;
    final risk = 1 / (1 + _exp(z));
    return risk.clamp(0.02, 0.97);
  }

  static FinancialWeather weatherFromRisk(double risk) {
    if (risk >= 0.35) return FinancialWeather.storm;
    if (risk >= 0.18) return FinancialWeather.pressure;
    return FinancialWeather.stable;
  }

  static double _exp(double x) => math.exp(x);
}
