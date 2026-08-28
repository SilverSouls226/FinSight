import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/intervention_card.dart';
import '../../widgets/loading_view.dart';
import 'intervention_detail_screen.dart';

/// Screen 4: Intervention Feed.
class InterventionFeedScreen extends ConsumerWidget {
  const InterventionFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interventionsAsync = ref.watch(interventionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Interventions')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(interventionsProvider),
        child: interventionsAsync.when(
          loading: () => const LoadingView(message: 'Checking for proactive alerts...'),
          error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(interventionsProvider)),
          data: (interventions) {
            if (interventions.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  EmptyStateView(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'No active interventions',
                    subtitle: 'FinSentinel is watching your finances and will notify you proactively if action is needed.',
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: interventions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final intervention = interventions[i];
                return InterventionCard(
                  intervention: intervention,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => InterventionDetailScreen(intervention: intervention)),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
