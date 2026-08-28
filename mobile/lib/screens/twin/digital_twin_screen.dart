import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/financial_state_snapshot.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../utils/twin_projection.dart';
import '../../widgets/error_view.dart';
import '../../widgets/goal_progress_bar.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/obligation_tile.dart';
import '../../widgets/twin_assistant_card.dart';
import '../../widgets/twin_balance_chart.dart';

/// Screen 3: Financial Digital Twin.
/// Visualizes balance, projected income (with uncertainty), obligations,
/// goals and spending as one coherent, continuously-updating model.
class DigitalTwinScreen extends ConsumerWidget {
  const DigitalTwinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(financialSnapshotProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Financial Digital Twin')),
      body: snapshotAsync.when(
        loading: () => const LoadingView(message: 'Building your digital twin...'),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(financialSnapshotProvider)),
        data: (snapshot) => _TwinBody(snapshot: snapshot),
      ),
    );
  }
}

class _TwinBody extends StatelessWidget {
  final FinancialStateSnapshot snapshot;

  const _TwinBody({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final runway = TwinProjection.runwayDays(snapshot);
    final netChange = TwinProjection.netChange30Days(snapshot);
    final variancePct = TwinProjection.incomeVariancePercent(snapshot);

    int step = 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _FadeSlideIn(
          index: step++,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('30-DAY PROJECTED BALANCE',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1)),
                  const SizedBox(height: 12),
                  TwinBalanceChart(snapshot: snapshot),
                  const SizedBox(height: 8),
                  const TwinChartLegend(),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap or drag the chart to explore any day.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _FadeSlideIn(
          index: step++,
          child: _MetricGrid(
            tiles: [
              _StatTile(
                label: 'Checking',
                value: formatCurrency(snapshot.currentBalances.checking),
                icon: Icons.account_balance_wallet_rounded,
              ),
              _StatTile(
                label: 'Savings',
                value: formatCurrency(snapshot.currentBalances.savings),
                icon: Icons.savings_rounded,
              ),
              _StatTile(
                label: 'Projected income (30d)',
                value: formatCurrency(snapshot.projectedIncome30Days.estimatedAmount),
                sub: '± ${formatCurrency(snapshot.projectedIncome30Days.variance)} variance',
                icon: Icons.trending_up_rounded,
              ),
              _StatTile(
                label: 'Safe to spend',
                value: formatCurrency(snapshot.safeToSpend),
                accent: AppColors.stable,
                icon: Icons.shield_rounded,
              ),
              _StatTile(
                label: 'Runway',
                value: runway == null ? '30+ days' : '$runway day${runway == 1 ? '' : 's'}',
                sub: runway == null ? 'Stays positive' : 'Until balance turns negative',
                accent: runway == null
                    ? AppColors.stable
                    : (runway <= 7 ? AppColors.storm : AppColors.pressure),
                icon: Icons.timelapse_rounded,
              ),
              _StatTile(
                label: 'Net change (30d)',
                value: '${netChange >= 0 ? '+' : ''}${formatCurrency(netChange)}',
                sub: 'Income minus obligations',
                accent: netChange >= 0 ? AppColors.stable : AppColors.storm,
                icon: netChange >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              ),
              _StatTile(
                label: 'Upcoming obligations',
                value: formatCurrency(snapshot.totalUpcomingObligations),
                sub: '${snapshot.upcomingObligations.length} tracked',
                accent: AppColors.pressure,
                icon: Icons.receipt_long_rounded,
              ),
              _StatTile(
                label: 'Income confidence',
                value: '± ${variancePct.toStringAsFixed(0)}%',
                sub: variancePct <= 15 ? 'Fairly stable' : 'Volatile',
                accent: variancePct <= 15 ? AppColors.stable : AppColors.pressure,
                icon: Icons.insights_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _FadeSlideIn(
          index: step++,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Section('OBLIGATIONS'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      for (int i = 0; i < snapshot.upcomingObligations.length; i++) ...[
                        ObligationTile(obligation: snapshot.upcomingObligations[i]),
                        if (i != snapshot.upcomingObligations.length - 1) const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _FadeSlideIn(
          index: step++,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Section('GOALS'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      for (int i = 0; i < snapshot.activeGoals.length; i++) ...[
                        GoalProgressBar(goal: snapshot.activeGoals[i]),
                        if (i != snapshot.activeGoals.length - 1) const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _FadeSlideIn(
          index: step++,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Section('ASK YOUR TWIN'),
              TwinAssistantCard(snapshot: snapshot),
            ],
          ),
        ),
      ],
    );
  }
}

/// Wraps a section in a staggered fade + slide-up entrance animation,
/// delayed by [index] so sections cascade in one after another.
class _FadeSlideIn extends StatefulWidget {
  final int index;
  final Widget child;

  const _FadeSlideIn({required this.index, required this.child});

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Lays out metric tiles in a uniform grid — every tile shares identical
/// dimensions regardless of its content length.
class _MetricGrid extends StatelessWidget {
  final List<_StatTile> tiles;

  const _MetricGrid({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemBuilder: (context, i) => tiles[i],
    );
  }
}

class _Section extends StatelessWidget {
  final String label;

  const _Section(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color accent;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    this.sub,
    this.accent = AppColors.textPrimary,
    this.icon = Icons.circle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: accent.withValues(alpha: 0.85)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: accent, fontSize: 17, fontWeight: FontWeight.w800),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
