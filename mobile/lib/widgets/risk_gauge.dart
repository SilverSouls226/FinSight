import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/risk_estimator.dart';

/// Semi-circular gauge showing shortfall probability, colored by risk band.
class RiskGauge extends StatelessWidget {
  final double riskFraction; // 0.0 - 1.0
  final double size;

  const RiskGauge({super.key, required this.riskFraction, this.size = 180});

  @override
  Widget build(BuildContext context) {
    final weather = RiskEstimator.weatherFromRisk(riskFraction);
    final color = switch (weather) {
      FinancialWeather.stable => AppColors.stable,
      FinancialWeather.pressure => AppColors.pressure,
      FinancialWeather.storm => AppColors.storm,
    };

    return SizedBox(
      width: size,
      height: size * 0.74,
      child: CustomPaint(
        painter: _RiskGaugePainter(riskFraction: riskFraction, color: color),
        child: Padding(
          padding: EdgeInsets.only(top: size * 0.24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                formatPercent(riskFraction),
                style: TextStyle(
                  color: color,
                  fontSize: size * 0.17,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Shortfall risk (30d)',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskGaugePainter extends CustomPainter {
  final double riskFraction;
  final Color color;

  _RiskGaugePainter({required this.riskFraction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.height * 0.16;
    final center = Offset(size.width / 2, size.height);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = math.pi;
    const sweepTotal = math.pi;

    canvas.drawArc(rect, startAngle, sweepTotal, false, trackPaint);
    canvas.drawArc(
      rect,
      startAngle,
      sweepTotal * riskFraction.clamp(0.0, 1.0),
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RiskGaugePainter oldDelegate) {
    return oldDelegate.riskFraction != riskFraction || oldDelegate.color != color;
  }
}
