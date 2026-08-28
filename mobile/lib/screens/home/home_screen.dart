import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/financial_state_snapshot.dart';
import '../../models/intervention.dart';
import '../../state/demo_scenario_controller.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../utils/risk_estimator.dart';
import '../../widgets/error_view.dart';
import '../../widgets/financial_weather_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/obligation_tile.dart';
import '../../widgets/safe_to_spend_card.dart';
import '../../widgets/severity_badge.dart';
import '../interventions/intervention_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(financialSnapshotProvider);
    final interventionsAsync = ref.watch(interventionsProvider);
    final profile = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(profile != null && profile.name.isNotEmpty
            ? 'Hi, ${profile.name.split(' ').first}'
            : 'FinSentinel'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(financialSnapshotProvider);
          ref.invalidate(interventionsProvider);
        },
        child: snapshotAsync.when(
          loading: () => const LoadingView(message: 'Reading your financial state...'),
          error: (e, _) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(financialSnapshotProvider),
          ),
          data: (snapshot) {
            final risk = RiskEstimator.estimateShortfallProbability(snapshot);
            final topObligations = snapshot.upcomingObligations.take(3).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                FinancialWeatherCard(
                  riskFraction: risk,
                  explanation: _weatherExplanation(snapshot, risk),
                ),
                const SizedBox(height: 16),
                SafeToSpendCard(
                  safeToSpend: snapshot.safeToSpend,
                  totalBalance: snapshot.totalBalance,
                ),
                const SizedBox(height: 16),
                _DemoControlPanel(),
                const SizedBox(height: 16),
                interventionsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (interventions) => _LatestInterventionPreview(interventions: interventions),
                ),
                const SizedBox(height: 16),
                if (topObligations.isNotEmpty) ...[
                  const _SectionLabel('UPCOMING OBLIGATIONS'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          for (int i = 0; i < topObligations.length; i++) ...[
                            ObligationTile(obligation: topObligations[i]),
                            if (i != topObligations.length - 1) const Divider(height: 1),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  String _weatherExplanation(FinancialStateSnapshot snapshot, double risk) {
    final weather = RiskEstimator.weatherFromRisk(risk);
    if (weather == FinancialWeather.stable) {
      return 'Your projected income covers upcoming obligations with a healthy buffer.';
    } else if (weather == FinancialWeather.pressure) {
      return 'Cash flow is tightening. Review upcoming obligations before spending.';
    }
    return 'High risk of a cash shortfall. Check the Alerts tab for recommended actions.';
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
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

class _LatestInterventionPreview extends StatelessWidget {
  final List<ContextualIntervention> interventions;

  const _LatestInterventionPreview({required this.interventions});

  @override
  Widget build(BuildContext context) {
    if (interventions.isEmpty) return const SizedBox.shrink();
    final top = interventions.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('PROACTIVE INTERVENTION'),
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => InterventionDetailScreen(intervention: top)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SeverityBadge(severity: top.severity),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(top.title,
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(top.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Judge-facing demo control: steps through the scripted mock scenario
/// (stable -> pressure -> resolved) so the continuous-adaptation story is
/// visible live, without needing a real backend connected.
class _DemoControlPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!useMockServices) return const SizedBox.shrink();

    final nextStage = ref.watch(nextDemoStageProvider);
    final currentStageId = ref.watch(currentStageIdProvider);

    return Card(
      color: AppColors.surfaceRaised,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science_outlined, color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                const Text('Demo scenario',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(currentStageId,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            nextStage.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (stage) {
                if (stage == null) {
                  return OutlinedButton(
                    onPressed: () => resetDemoStage(ref),
                    child: const Text('Restart scenario'),
                  );
                }
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => advanceDemoStage(ref),
                    child: Text('Simulate: ${stage.triggerEvent}'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
