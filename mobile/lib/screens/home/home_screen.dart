import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/financial_state_snapshot.dart';
import '../../models/intervention.dart';
import '../../state/demo_scenario_controller.dart';
import '../../state/providers.dart';
import '../../state/sms_ingestion_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../utils/risk_estimator.dart';
import '../../widgets/add_entry/add_entry_sheet.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/obligation_tile.dart';
import '../../widgets/severity_badge.dart';
import '../interventions/intervention_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(financialSnapshotProvider);
    final interventionsAsync = ref.watch(interventionsProvider);
    final profile = ref.watch(userProfileProvider);
    final firstName =
        profile != null && profile.name.isNotEmpty ? profile.name.split(' ').first : 'there';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
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
              final weather = RiskEstimator.weatherFromRisk(risk);
              final topObligations = snapshot.upcomingObligations.take(3).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  _GreetingHeader(name: firstName, unreadAlerts: interventionsAsync.maybeWhen(
                    data: (list) => list.length,
                    orElse: () => 0,
                  )),
                  const SizedBox(height: 14),
                  _BalanceHero(snapshot: snapshot, weather: weather),
                  const SizedBox(height: 18),
                  _QuickActions(ref: ref),
                  _SectionHeader(title: 'Your forecast'),
                  _RiskCard(riskFraction: risk, weather: weather, explanation: _weatherExplanation(snapshot, risk)),
                  const SizedBox(height: 6),
                  interventionsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (interventions) => _LatestInterventionPreview(interventions: interventions),
                  ),
                  if (topObligations.isNotEmpty) ...[
                    _SectionHeader(title: 'Upcoming obligations'),
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
                  const SizedBox(height: 16),
                  _DemoControlPanel(),
                  const SizedBox(height: 16),
                  const _SmsIngestionCard(),
                ],
              );
            },
          ),
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

class _GreetingHeader extends StatelessWidget {
  final String name;
  final int unreadAlerts;

  const _GreetingHeader({required this.name, required this.unreadAlerts});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: const BoxDecoration(gradient: AppColors.accentGradient, shape: BoxShape.circle),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_greeting, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15.5, fontWeight: FontWeight.w700)),
          ],
        ),
        const Spacer(),
        Consumer(builder: (context, ref, _) {
          return _IconButtonBadge(
            icon: Icons.notifications_outlined,
            badgeCount: unreadAlerts,
            onTap: () => ref.read(rootTabIndexProvider.notifier).state = 3,
          );
        }),
      ],
    );
  }
}

class _IconButtonBadge extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final VoidCallback onTap;

  const _IconButtonBadge({required this.icon, required this.badgeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            if (badgeCount > 0)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.storm,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 2),
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BalanceHero extends StatelessWidget {
  final FinancialStateSnapshot snapshot;
  final FinancialWeather weather;

  const _BalanceHero({required this.snapshot, required this.weather});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: AppColors.heroGradient,
        boxShadow: [
          BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 16)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -30,
              child: _Blob(size: 150, color: const Color(0xFF9D8BFF)),
            ),
            Positioned(
              bottom: -50,
              left: -20,
              child: _Blob(size: 120, color: const Color(0xFF4A8DFF)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('Total balance',
                        style: TextStyle(color: Colors.white70, fontSize: 11.5, letterSpacing: 0.3)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: Color(0xFFFFD24D), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 7),
                          Text('Weather: ${weather.label}',
                              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  formatCurrency(snapshot.totalBalance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _HeroMini(label: 'Safe to spend', value: formatCurrency(snapshot.safeToSpend)),
                    const SizedBox(width: 20),
                    _HeroMini(label: 'Savings', value: formatCurrency(snapshot.currentBalances.savings)),
                    const SizedBox(width: 20),
                    _HeroMini(label: '30d income', value: formatCurrency(snapshot.projectedIncome30Days.estimatedAmount)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;

  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.35), shape: BoxShape.circle),
    );
  }
}

class _HeroMini extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMini({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final WidgetRef ref;

  const _QuickActions({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _QuickAction(
            key: const Key('homeQuickAddAction'),
            icon: Icons.add_rounded,
            color: AppColors.accent,
            label: 'Add',
            onTap: () => showAddEntrySheet(context),
          ),
          _QuickAction(
            icon: Icons.calculate_rounded,
            color: AppColors.stable,
            label: 'Simulate',
            onTap: () => ref.read(rootTabIndexProvider.notifier).state = 2,
          ),
          _QuickAction(
            icon: Icons.flag_rounded,
            color: AppColors.pressure,
            label: 'Goals',
            onTap: () => ref.read(rootTabIndexProvider.notifier).state = 4,
          ),
          _QuickAction(
            icon: Icons.auto_awesome_rounded,
            color: AppColors.accent2,
            label: 'Ask AI',
            onTap: () => ref.read(rootTabIndexProvider.notifier).state = 1,
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({super.key, required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 6)),
                ],
              ),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 12),
      child: Text(
        title,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  final double riskFraction;
  final FinancialWeather weather;
  final String explanation;

  const _RiskCard({required this.riskFraction, required this.weather, required this.explanation});

  @override
  Widget build(BuildContext context) {
    final color = switch (weather) {
      FinancialWeather.stable => AppColors.stable,
      FinancialWeather.pressure => AppColors.pressure,
      FinancialWeather.storm => AppColors.storm,
    };
    final title = switch (weather) {
      FinancialWeather.stable => 'Shortfall risk is low',
      FinancialWeather.pressure => 'Shortfall risk is building',
      FinancialWeather.storm => 'Shortfall risk is elevated',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CustomPaint(
                painter: _RiskRingPainter(riskFraction: riskFraction, color: color),
                child: Center(
                  child: Text(
                    formatPercent(riskFraction),
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(explanation, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskRingPainter extends CustomPainter {
  final double riskFraction;
  final Color color;

  _RiskRingPainter({required this.riskFraction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 7) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = const Color(0xFFECEFF5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final value = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false, track);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * riskFraction.clamp(0.0, 1.0), false, value);
  }

  @override
  bool shouldRepaint(covariant _RiskRingPainter oldDelegate) =>
      oldDelegate.riskFraction != riskFraction || oldDelegate.color != color;
}

class _LatestInterventionPreview extends StatelessWidget {
  final List<ContextualIntervention> interventions;

  const _LatestInterventionPreview({required this.interventions});

  @override
  Widget build(BuildContext context) {
    if (interventions.isEmpty) return const SizedBox.shrink();
    final top = interventions.first;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
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
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
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

/// Real bank SMS interception (Android only): toggling this on requests
/// SMS permission, then forwards any incoming message from a recognized
/// bank sender to Skandan's real ingestion service, and — once turned into
/// a structured event — pushes it into Sanjani's Financial State, so the
/// balance/projections shown above update from real incoming money without
/// the user doing anything. This is the point of the feature: someone with
/// variable/informal income sees their actual, current safe-to-spend
/// number as money arrives, not a stale manually-entered figure.
class _SmsIngestionCard extends ConsumerWidget {
  const _SmsIngestionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }

    final state = ref.watch(smsIngestionControllerProvider);
    final controller = ref.read(smsIngestionControllerProvider.notifier);

    return Card(
      color: AppColors.surfaceRaised,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sms_outlined, color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Auto-detect bank SMS',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                  ),
                ),
                Switch(
                  value: state.enabled,
                  onChanged: (value) {
                    if (value) {
                      controller.enable();
                    } else {
                      controller.disable();
                    }
                  },
                ),
              ],
            ),
            const Text(
              'Detects incoming bank SMS while the app is open and updates '
              'your balance above automatically — no manual entry needed.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
            ),
            if (state.enabled) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => controller.simulateIncomingSms(
                    'HDFCBK',
                    'Dear Customer, your A/c XX1234 is credited by Rs.1.00 on 28-08-26 '
                        'by UPI from FRIEND. Ref No 999888777. -HDFC Bank',
                  ),
                  icon: const Icon(Icons.bolt_rounded, size: 16),
                  label: const Text('Simulate test SMS'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
            ],
            if (state.permissionDenied) ...[
              const SizedBox(height: 10),
              const Text(
                'SMS permission was denied. Enable it in system settings to use this.',
                style: TextStyle(color: AppColors.storm, fontSize: 12),
              ),
            ],
            if (state.lastError != null) ...[
              const SizedBox(height: 10),
              Text(
                state.lastError!,
                style: const TextStyle(color: AppColors.storm, fontSize: 12),
              ),
            ],
            if (state.recentEvents.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              const Text(
                'RECENTLY DETECTED',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              for (final event in state.recentEvents)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        event.type == 'income' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        size: 14,
                        color: event.type == 'income' ? AppColors.stable : AppColors.pressure,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${event.vendor} — ${event.currency} ${event.amount.toStringAsFixed(0)}',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
