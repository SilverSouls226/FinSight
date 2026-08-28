import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/financial_state_snapshot.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/error_view.dart';
import '../../widgets/goal_progress_bar.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/obligation_tile.dart';
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
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
                const SizedBox(height: 12),
                const TwinChartLegend(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Checking',
                value: formatCurrency(snapshot.currentBalances.checking),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: 'Savings',
                value: formatCurrency(snapshot.currentBalances.savings),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Projected income (30d)',
                value: formatCurrency(snapshot.projectedIncome30Days.estimatedAmount),
                sub: '± ${formatCurrency(snapshot.projectedIncome30Days.variance)} variance',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: 'Safe to spend',
                value: formatCurrency(snapshot.safeToSpend),
                accent: AppColors.stable,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
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
        const SizedBox(height: 20),
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

  const _StatTile({
    required this.label,
    required this.value,
    this.sub,
    this.accent = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: accent, fontSize: 18, fontWeight: FontWeight.w800)),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub!, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}
