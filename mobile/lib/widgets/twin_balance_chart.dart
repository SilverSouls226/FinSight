import 'package:flutter/material.dart';

import '../models/financial_state_snapshot.dart';
import '../theme/app_colors.dart';

/// The Financial Digital Twin's core visualization: a 30-day projected
/// balance line with an income-uncertainty band (widening cone) and
/// obligation due-date markers where the projected balance steps down.
///
/// Interactive: draws itself in with an animation on load, and responds to
/// touch/drag by showing a crosshair + tooltip with the day and projected
/// value at that point.
///
/// All numbers are derived client-side from the Financial State Snapshot
/// for display purposes only — Python remains the source of truth for any
/// real forecasting/Monte Carlo output.
class TwinBalanceChart extends StatefulWidget {
  final FinancialStateSnapshot snapshot;
  static const int horizonDays = 30;

  const TwinBalanceChart({super.key, required this.snapshot});

  @override
  State<TwinBalanceChart> createState() => _TwinBalanceChartState();
}

class _TwinBalanceChartState extends State<TwinBalanceChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double? _touchDay;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant TwinBalanceChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateTouch(Offset localPosition, Size size) {
    const leftPadding = 8.0;
    const rightPadding = 8.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final rawDay =
        ((localPosition.dx - leftPadding) / chartWidth) * TwinBalanceChart.horizonDays;
    setState(() {
      _touchDay = rawDay.clamp(0, TwinBalanceChart.horizonDays.toDouble());
    });
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => _updateTouch(d.localPosition, size),
            onPanUpdate: (d) => _updateTouch(d.localPosition, size),
            onPanEnd: (_) => setState(() => _touchDay = null),
            onTapDown: (d) => _updateTouch(d.localPosition, size),
            onTapUp: (_) => Future.delayed(
              const Duration(seconds: 2),
              () {
                if (mounted) setState(() => _touchDay = null);
              },
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _TwinChartPainter(
                    snapshot: widget.snapshot,
                    progress: Curves.easeOutCubic.transform(_controller.value),
                    touchDay: _touchDay,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          );
        },
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
  final double progress;
  final double? touchDay;

  _TwinChartPainter({required this.snapshot, this.progress = 1.0, this.touchDay});

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

  _Point _interpolate(List<_Point> series, double day) {
    if (day <= series.first.day) return series.first;
    if (day >= series.last.day) return series.last;
    final lowIdx = day.floor();
    final a = series[lowIdx];
    final b = series[(lowIdx + 1).clamp(0, series.length - 1)];
    final t = day - a.day;
    return _Point(
      day,
      a.mid + (b.mid - a.mid) * t,
      a.upper + (b.upper - a.upper) * t,
      a.lower + (b.lower - a.lower) * t,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fullSeries = _buildSeries();
    if (fullSeries.isEmpty) return;

    // Reveal only up to `progress` of the horizon for the draw-in animation.
    final visibleDayCount = (fullSeries.length * progress).ceil().clamp(2, fullSeries.length);
    final series = fullSeries.sublist(0, visibleDayCount);

    const leftPadding = 8.0;
    const rightPadding = 8.0;
    const topPadding = 16.0;
    const bottomPadding = 24.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final minY = fullSeries.map((p) => p.lower).reduce((a, b) => a < b ? a : b);
    final maxY = fullSeries.map((p) => p.upper).reduce((a, b) => a > b ? a : b);
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

    // Leading-edge dot for the draw-in animation.
    if (progress < 1.0) {
      canvas.drawCircle(
        Offset(xFor(series.last.day), yFor(series.last.mid)),
        4,
        Paint()..color = AppColors.accent,
      );
    }

    // Obligation markers
    final obligationPaint = Paint()..color = AppColors.pressure;
    final dashedLinePaint = Paint()
      ..color = AppColors.pressure.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (final o in snapshot.upcomingObligations) {
      final day = o.dueDate.difference(snapshot.lastUpdated).inDays.toDouble();
      if (day < 0 || day > series.last.day) continue;
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

    // Touch crosshair + tooltip
    final td = touchDay;
    if (td != null && progress >= 1.0) {
      final point = _interpolate(fullSeries, td);
      final x = xFor(point.day);

      final crosshairPaint = Paint()
        ..color = AppColors.textSecondary.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, topPadding), Offset(x, size.height - bottomPadding), crosshairPaint);
      canvas.drawCircle(Offset(x, yFor(point.mid)), 5, Paint()..color = AppColors.accent);
      canvas.drawCircle(
        Offset(x, yFor(point.mid)),
        5,
        Paint()
          ..color = AppColors.background
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      _drawTooltip(canvas, size, point, x, yFor(point.mid), topPadding);
    }
  }

  void _drawTooltip(Canvas canvas, Size size, _Point point, double x, double y, double topPadding) {
    final dayLabel = point.day.round() == 0 ? 'Today' : 'Day ${point.day.round()}';
    final valueLabel = '₹${point.mid.toStringAsFixed(0)}';

    final textPainter = TextPainter(
      text: TextSpan(children: [
        TextSpan(
          text: '$dayLabel\n',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
        ),
        TextSpan(
          text: valueLabel,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ]),
      textDirection: TextDirection.ltr,
    )..layout();

    const hPad = 8.0, vPad = 6.0;
    final boxWidth = textPainter.width + hPad * 2;
    final boxHeight = textPainter.height + vPad * 2;

    double boxLeft = x - boxWidth / 2;
    boxLeft = boxLeft.clamp(0.0, size.width - boxWidth);
    double boxTop = y - boxHeight - 14;
    if (boxTop < topPadding) boxTop = y + 14;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, Paint()..color = AppColors.surfaceRaised);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    textPainter.paint(canvas, Offset(boxLeft + hPad, boxTop + vPad));
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
    return oldDelegate.snapshot != snapshot ||
        oldDelegate.progress != progress ||
        oldDelegate.touchDay != touchDay;
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
