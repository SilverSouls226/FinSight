import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/risk_estimator.dart';

/// Side-by-side "without purchase" vs "with purchase" shortfall-risk bars,
/// the centerpiece of the Simulation screen's "Can I afford this?" answer.
class SimulationRiskBar extends StatelessWidget {
  final String label;
  final double riskFraction;

  const SimulationRiskBar({super.key, required this.label, required this.riskFraction});

  @override
  Widget build(BuildContext context) {
    final weather = RiskEstimator.weatherFromRisk(riskFraction);
    final color = switch (weather) {
      FinancialWeather.stable => AppColors.stable,
      FinancialWeather.pressure => AppColors.pressure,
      FinancialWeather.storm => AppColors.storm,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            Text(
              formatPercent(riskFraction),
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: riskFraction.clamp(0.0, 1.0),
            minHeight: 12,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
