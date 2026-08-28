import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/risk_estimator.dart';
import 'risk_gauge.dart';

/// Hero card on the Home screen: the "Financial Weather" concept that makes
/// FinSentinel instantly legible — a single glanceable status instead of a
/// spreadsheet of numbers.
class FinancialWeatherCard extends StatelessWidget {
  final double riskFraction;
  final String explanation;

  const FinancialWeatherCard({
    super.key,
    required this.riskFraction,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    final weather = RiskEstimator.weatherFromRisk(riskFraction);
    final color = switch (weather) {
      FinancialWeather.stable => AppColors.stable,
      FinancialWeather.pressure => AppColors.pressure,
      FinancialWeather.storm => AppColors.storm,
    };
    final softColor = switch (weather) {
      FinancialWeather.stable => AppColors.stableSoft,
      FinancialWeather.pressure => AppColors.pressureSoft,
      FinancialWeather.storm => AppColors.stormSoft,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [softColor, AppColors.surface],
        ),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(weather.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FINANCIAL WEATHER',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    weather.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          RiskGauge(riskFraction: riskFraction),
          const SizedBox(height: 16),
          Text(
            explanation,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
