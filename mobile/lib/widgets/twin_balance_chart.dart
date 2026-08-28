import 'package:flutter/material.dart';

import '../models/financial_state_snapshot.dart';
import '../theme/app_colors.dart';

/// The Financial Digital Twin's core visualization: a 30-day projected
/// balance line with an income-uncertainty band (widening cone) and
/// obligation due-date markers where the projected balance steps down.
///
/// All numbers are derived client-side from the Financial State Snapshot
/// for display purposes only — Python remains the source of truth for any
/// real forecasting/Monte Carlo output.
class TwinBalanceChart extends StatelessWidget {
  final FinancialStateSnapshot snapshot;
  static const int horizonDays = 30;

  const TwinBalanceChart({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: CustomPaint(
        painter: _TwinChartPainter(snapshot: snapshot),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Point {
  final double day;
  final double mid;
  final double upper;
  final double lower;
  const _Point(this.day, this.mid, this.upper, this.lower);
}

class _TwinChartPainter extends CustomPainter {
  final FinancialStateSnapshot snapshot;

  _TwinChartPainter({required this.snapshot});

  List<_Point> _buildSeries() {
    final startBalance = snapshot.currentBalances.checking;
    final income = snapshot.projectedIncome30Days.estimatedAmount;
    final variance = snapshot.projectedIncome30Days.variance;
    final obligations = [...snapshot.upcomingObligations]
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final now = snapshot.lastUpdated;
    final points = <_Point>[];

    double obligationsPaidBy(double day) {
      final cutoff = now.add(Duration(days: day.round()));
      return obligations
          .where((o) => !o.dueDate.isAfter(cutoff))
          .fold(0.0, (sum, o) => sum + o.amount);
    }

    for (int d = 0; d <= TwinBalanceChart.horizonDays; d++) {
      final t = d / TwinBalanceChart.horizonDays;
      final incomeSoFar = income * t;
      final varianceSoFar = variance * t;
      final paidSoFar = obligationsPaidBy(d.toDouble());
      final mid = startBalance + incomeSoFar - paidSoFar;
      points.add(_Point(d.toDouble(), mid, mid + varianceSoFar, mid - varianceSoFar));
    }
    return points;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final series = _buildSeries();
    if (series.isEmpty) return;

    const leftPadding = 8.0;
    const rightPadding = 8.0;
    const topPadding = 16.0;
    const bottomPadding = 24.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final minY = series.map((p) => p.lower).reduce((a, b) => a < b ? a : b);
    final maxY = series.map((p) => p.upper).reduce((a, b) => a > b ? a : b);
    final yRange = (maxY - minY).abs() < 1 ? 1.0 : (maxY - minY);
    final paddedMin = minY - yRange * 0.15;
    final paddedMax = maxY + yRange * 0.15;
    final paddedRange = paddedMax - paddedMin;

    double xFor(double day) =>
        leftPadding + (day / TwinBalanceChart.horizonDays) * chartWidth;
    double yFor(double value) =>
        topPadding + chartHeight - ((value - paddedMin) / paddedRange) * chartHeight;

    // Zero line
    if (paddedMin < 0 && paddedMax > 0) {
      final zeroY = yFor(0);
      final zeroPaint = Paint()
        ..color = AppColors.storm.withValues(alpha: 0.4)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(leftPadding, zeroY), Offset(size.width - rightPadding, zeroY), zeroPaint);
    }

    // Uncertainty band
    final bandPath = Path();
    bandPath.moveTo(xFor(series.first.day), yFor(series.first.upper));
    for (final p in series) {
      bandPath.lineTo(xFor(p.day), yFor(p.upper));
    }
    for (final p in series.reversed) {
      bandPath.lineTo(xFor(p.day), yFor(p.lower));
    }
    bandPath.close();
    final bandPaint = Paint()..color = AppColors.accent.withValues(alpha: 0.12);
    canvas.drawPath(bandPath, bandPaint);

    // Mid projection line
    final midPath = Path();
    midPath.moveTo(xFor(series.first.day), yFor(series.first.mid));
    for (final p in series.skip(1)) {
      midPath.lineTo(xFor(p.day), yFor(p.mid));
    }
    final midPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(midPath, midPaint);

    // Obligation markers
    final obligationPaint = Paint()..color = AppColors.pressure;
    final dashedLinePaint = Paint()
      ..color = AppColors.pressure.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (final o in snapshot.upcomingObligations) {
      final day = o.dueDate.difference(snapshot.lastUpdated).inDays.toDouble();
      if (day < 0 || day > TwinBalanceChart.horizonDays) continue;
      final x = xFor(day);
      canvas.drawLine(Offset(x, topPadding), Offset(x, size.height - bottomPadding), dashedLinePaint);
      canvas.drawCircle(Offset(x, topPadding), 3.5, obligationPaint);
    }

    // Axis labels: Today / Day 30
    _drawText(canvas, 'Today', Offset(leftPadding, size.height - bottomPadding + 6));
    _drawText(
      canvas,
      'Day 30',
      Offset(size.width - rightPadding - 42, size.height - bottomPadding + 6),
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _TwinChartPainter oldDelegate) {
    return oldDelegate.snapshot != snapshot;
  }
}

/// Legend row shown under the chart.
class TwinChartLegend extends StatelessWidget {
  const TwinChartLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: const [
        _LegendItem(color: AppColors.accent, label: 'Projected balance'),
        _LegendItem(color: AppColors.pressure, label: 'Obligation due'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}
