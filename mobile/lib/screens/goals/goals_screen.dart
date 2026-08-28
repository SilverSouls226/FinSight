import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_profile.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/error_view.dart';
import '../../widgets/goal_progress_bar.dart';
import '../../widgets/loading_view.dart';

/// Screen 7: Goals / Risk Profile.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(financialSnapshotProvider);
    final profile = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Goals & Risk Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _Label('ACTIVE GOALS'),
          snapshotAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(financialSnapshotProvider)),
            data: (snapshot) {
              if (snapshot.activeGoals.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No goals yet.', style: TextStyle(color: AppColors.textSecondary)),
                );
              }
              return Card(
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
              );
            },
          ),
          const SizedBox(height: 28),
          const _Label('RISK PROFILE'),
          if (profile != null) _RiskProfileEditor(profile: profile),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1),
      ),
    );
  }
}

class _RiskProfileEditor extends ConsumerStatefulWidget {
  final UserProfile profile;

  const _RiskProfileEditor({required this.profile});

  @override
  ConsumerState<_RiskProfileEditor> createState() => _RiskProfileEditorState();
}

class _RiskProfileEditorState extends ConsumerState<_RiskProfileEditor> {
  late RiskTolerance _riskTolerance = widget.profile.riskTolerance;
  late final Set<FinancialPriority> _priorities = widget.profile.priorities.toSet();

  void _save() {
    ref.read(userProfileProvider.notifier).complete(
          widget.profile.copyWith(riskTolerance: _riskTolerance, priorities: _priorities.toList()),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Risk profile updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Risk tolerance', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: RiskTolerance.values
                  .map((r) => ChoiceChip(
                        label: Text(r.label),
                        selected: _riskTolerance == r,
                        onSelected: (_) => setState(() => _riskTolerance = r),
                        labelStyle: TextStyle(
                          color: _riskTolerance == r ? Colors.white : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        selectedColor: AppColors.accent,
                        backgroundColor: AppColors.surfaceRaised,
                        side: const BorderSide(color: AppColors.border),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Text('Priorities', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: FinancialPriority.values
                  .map((p) => FilterChip(
                        label: Text(p.label),
                        selected: _priorities.contains(p),
                        onSelected: (sel) => setState(() => sel ? _priorities.add(p) : _priorities.remove(p)),
                        labelStyle: TextStyle(
                          color: _priorities.contains(p) ? Colors.white : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        selectedColor: AppColors.accent,
                        backgroundColor: AppColors.surfaceRaised,
                        side: const BorderSide(color: AppColors.border),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _save, child: const Text('Save changes')),
            ),
          ],
        ),
      ),
    );
  }
}
