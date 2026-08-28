import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_profile.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  final _nameController = TextEditingController();
  final _goalNameController = TextEditingController();
  final _goalTargetController = TextEditingController();
  RiskTolerance _riskTolerance = RiskTolerance.moderate;
  final Set<FinancialPriority> _priorities = {};

  static const _totalPages = 4;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _goalNameController.dispose();
    _goalTargetController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == 0 && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name to continue.')),
      );
      return;
    }
    if (_page < _totalPages - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_page > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _finish() {
    final profile = UserProfile(
      name: _nameController.text.trim(),
      riskTolerance: _riskTolerance,
      priorities: _priorities.toList(),
      primaryGoalName: _goalNameController.text.trim().isEmpty ? null : _goalNameController.text.trim(),
      primaryGoalTarget: double.tryParse(_goalTargetController.text.trim()),
    );
    ref.read(userProfileProvider.notifier).complete(profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _ProgressDots(current: _page, total: _totalPages),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _NamePage(controller: _nameController),
                  _RiskPage(
                    selected: _riskTolerance,
                    onChanged: (v) => setState(() => _riskTolerance = v),
                  ),
                  _PrioritiesPage(
                    selected: _priorities,
                    onToggle: (p) => setState(
                      () => _priorities.contains(p) ? _priorities.remove(p) : _priorities.add(p),
                    ),
                  ),
                  _GoalPage(
                    nameController: _goalNameController,
                    targetController: _goalTargetController,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  if (_page > 0)
                    Expanded(
                      child: OutlinedButton(onPressed: _back, child: const Text('Back')),
                    ),
                  if (_page > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _next,
                      child: Text(_page == _totalPages - 1 ? 'Get started' : 'Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppColors.accent : AppColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _OnboardingHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;

  const _OnboardingHeading({required this.eyebrow, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
      ],
    );
  }
}

class _NamePage extends StatelessWidget {
  final TextEditingController controller;

  const _NamePage({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _OnboardingHeading(
            eyebrow: 'Welcome to FinSentinel',
            title: 'Your Financial Digital Twin',
            subtitle:
                'FinSentinel continuously models your finances and proactively warns you before problems happen — not just after. Let\'s set you up.',
          ),
          const SizedBox(height: 32),
          TextField(
            controller: controller,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: "What's your name?"),
          ),
        ],
      ),
    );
  }
}

class _RiskPage extends StatelessWidget {
  final RiskTolerance selected;
  final ValueChanged<RiskTolerance> onChanged;

  const _RiskPage({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _OnboardingHeading(
            eyebrow: 'Step 2',
            title: 'Risk tolerance',
            subtitle: 'This tunes how early and how often FinSentinel intervenes.',
          ),
          const SizedBox(height: 24),
          ...RiskTolerance.values.map((r) => _SelectableCard(
                title: r.label,
                subtitle: r.description,
                selected: r == selected,
                onTap: () => onChanged(r),
              )),
        ],
      ),
    );
  }
}

class _PrioritiesPage extends StatelessWidget {
  final Set<FinancialPriority> selected;
  final ValueChanged<FinancialPriority> onToggle;

  const _PrioritiesPage({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _OnboardingHeading(
            eyebrow: 'Step 3',
            title: 'Financial priorities',
            subtitle: 'Pick what matters most right now (choose any number).',
          ),
          const SizedBox(height: 24),
          ...FinancialPriority.values.map((p) => _SelectableCard(
                title: p.label,
                selected: selected.contains(p),
                onTap: () => onToggle(p),
              )),
        ],
      ),
    );
  }
}

class _GoalPage extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController targetController;

  const _GoalPage({required this.nameController, required this.targetController});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _OnboardingHeading(
            eyebrow: 'Step 4 (optional)',
            title: 'A goal to work toward',
            subtitle: 'You can add or edit goals anytime from the Goals tab.',
          ),
          const SizedBox(height: 24),
          TextField(
            controller: nameController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Goal name (e.g. Emergency Fund)'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: targetController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Target amount (₹)'),
          ),
        ],
      ),
    );
  }
}

class _SelectableCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableCard({
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentSoft : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppColors.accent : AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.accent : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
