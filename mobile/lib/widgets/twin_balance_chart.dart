import 'package:flutter/material.dart';

import '../models/financial_state_snapshot.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// The Financial Digital Twin's core visualization: a 30-day projected
/// balance line with an income-uncertainty band (widening cone) and
/// obligation due-date markers where the projected balance steps down.
///
/// Interactive: draws itself in with an animation on load, shows a live
/// animated headline number above the chart, and responds to touch/drag
/// with a crosshair + tooltip for the day and projected value at that
/// point.
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

class _Point {
  final double day;
  final double mid;
  final double upper;
  final double lower;
  const _Point(this.day, this.mid, this.upper, this.lower);
}

List<_Point> _buildSeries(FinancialStateSnapshot snapshot) {
  final startBalance = snapshot.currentBalances.checking;
  final income = snapshot.projectedIncome30Days.estimatedAmount;
  final variance = snapshot.projectedIncome30Days.variance;
  final obligations = [...snapshot.upcomingObligations]..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  final now = snapshot.lastUpdated;
  final points = <_Point>[];

  double obligationsPaidBy(double day) {
    final cutoff = now.add(Duration(days: day.round()));
    return obligations.where((o) => !o.dueDate.isAfter(cutoff)).fold(0.0, (sum, o) => sum + o.amount);
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

class _TwinBalanceChartState extends State<TwinBalanceChart> with SingleTickerProviderStateMixin {
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
    final rawDay = ((localPosition.dx - leftPadding) / chartWidth) * TwinBalanceChart.horizonDays;
    setState(() {
      _touchDay = rawDay.clamp(0, TwinBalanceChart.horizonDays.toDouble());
    });
  }

  @override
  Widget build(BuildContext context) {
    final series = _buildSeries(widget.snapshot);
    final headlinePoint = _touchDay != null ? _interpolate(series, _touchDay!) : series.last;
    final headlineDayLabel = _touchDay == null
        ? 'Day 30 projection'
        : (headlinePoint.day.round() == 0 ? 'Today' : 'Day ${headlinePoint.day.round()}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: headlinePoint.mid, end: headlinePoint.mid),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              builder: (context, value, _) => Text(
                formatCurrency(value),
                style: TextStyle(
                  color: value < 0 ? AppColors.storm : AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  headlineDayLabel,
                  key: ValueKey(headlineDayLabel),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => _updateTouch(d.localPosition, size),
                onPanUpdate: (d) => _updateTouch(d.localPosition, size),
                onPanEnd: (_) => setState(() => _touchDay = null),
                onTapDown: (d) => _updateTouch(d.localPosition, size),
                onTapUp: (_) => Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) setState(() => _touchDay = null);
                }),
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
        ),
        const SizedBox(height: 6),
        const Text(
          'Tap or drag to explore any day',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}

/// Builds a smoothed path through [points] using quadratic Beziers via
/// each segment's midpoint -- avoids the sharp elbows of straight
/// line-to-line-to segments without any curve overshoot.
Path _smoothPath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  if (points.length == 1) {
    path.moveTo(points[0].dx, points[0].dy);
    return path;
  }
  path.moveTo(points[0].dx, points[0].dy);
  for (int i = 0; i < points.length - 1; i++) {
    final p0 = points[i];
    final p1 = points[i + 1];
    final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
    if (i == 0) {
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    } else {
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
  }
  path.lineTo(points.last.dx, points.last.dy);
  return path;
}

class _TwinChartPainter extends CustomPainter {
  final FinancialStateSnapshot snapshot;
  final double progress;
  final double? touchDay;

  _TwinChartPainter({required this.snapshot, this.progress = 1.0, this.touchDay});

  @override
  void paint(Canvas canvas, Size size) {
    final fullSeries = _buildSeries(snapshot);
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

    double xFor(double day) => leftPadding + (day / TwinBalanceChart.horizonDays) * chartWidth;
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

    final midPoints = [for (final p in series) Offset(xFor(p.day), yFor(p.mid))];
    final upperPoints = [for (final p in series) Offset(xFor(p.day), yFor(p.upper))];
    final lowerPoints = [for (final p in series) Offset(xFor(p.day), yFor(p.lower))];

    // Uncertainty band (smoothed)
    final bandPath = _smoothPath(upperPoints);
    final lowerReversedPath = _smoothPath(lowerPoints.reversed.toList());
    bandPath.addPath(lowerReversedPath, Offset.zero);
    bandPath.close();
    final bandPaint = Paint()..color = AppColors.accent.withValues(alpha: 0.10);
    canvas.drawPath(bandPath, bandPaint);

    // Gradient fill under the mid line down to the chart floor.
    final fillPath = _smoothPath(midPoints)
      ..lineTo(midPoints.last.dx, size.height - bottomPadding)
      ..lineTo(midPoints.first.dx, size.height - bottomPadding)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.accent.withValues(alpha: 0.22), AppColors.accent.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, topPadding, size.width, chartHeight));
    canvas.drawPath(fillPath, fillPaint);

    // Mid projection line (smoothed, with a soft glow behind it).
    final midPath = _smoothPath(midPoints);
    final glowPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(midPath, glowPaint);

    final midPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(midPath, midPaint);

    // Leading-edge dot for the draw-in animation.
    if (progress < 1.0) {
      canvas.drawCircle(midPoints.last, 4, Paint()..color = AppColors.accent);
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
    _drawText(canvas, 'Day 30', Offset(size.width - rightPadding - 42, size.height - bottomPadding + 6));

    // Touch crosshair + tooltip
    final td = touchDay;
    if (td != null && progress >= 1.0) {
      final point = _interpolate(fullSeries, td);
      final x = xFor(point.day);

      final crosshairPaint = Paint()
        ..color = AppColors.textSecondary.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, topPadding), Offset(x, size.height - bottomPadding), crosshairPaint);
      canvas.drawCircle(
        Offset(x, yFor(point.mid)),
        7,
        Paint()..color = AppColors.accent.withValues(alpha: 0.25),
      );
      canvas.drawCircle(Offset(x, yFor(point.mid)), 5, Paint()..color = AppColors.accent);
      canvas.drawCircle(
        Offset(x, yFor(point.mid)),
        5,
        Paint()
          ..color = AppColors.background
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
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
