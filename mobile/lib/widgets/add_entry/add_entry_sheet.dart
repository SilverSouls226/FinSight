import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'add_expense_form.dart';
import 'add_goal_form.dart';
import 'add_income_form.dart';
import 'add_obligation_form.dart';
import 'add_opening_balance_form.dart';
import 'add_profile_form.dart';

/// Entry point for the manual "Add" flow -- opens a bottom sheet: step 1
/// picks WHAT to add, step 2 is that type's short form. Reachable from a
/// single FAB on the root nav shell (visible from every tab).
Future<void> showAddEntrySheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddEntrySheet(),
  );
}

enum _AddType { income, expense, obligation, goal, openingBalance, profile }

class _AddEntrySheet extends StatefulWidget {
  const _AddEntrySheet();

  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> {
  _AddType? _selected;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _selected == null
                      ? _TypePicker(
                          scrollController: scrollController,
                          onSelect: (t) => setState(() => _selected = t),
                        )
                      : _buildForm(_selected!),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm(_AddType type) {
    void onBack() => setState(() => _selected = null);
    void onDone() => Navigator.of(context).pop();

    switch (type) {
      case _AddType.income:
        return AddIncomeForm(onBack: onBack, onDone: onDone);
      case _AddType.expense:
        return AddExpenseForm(onBack: onBack, onDone: onDone);
      case _AddType.obligation:
        return AddObligationForm(onBack: onBack, onDone: onDone);
      case _AddType.goal:
        return AddGoalForm(onBack: onBack, onDone: onDone);
      case _AddType.openingBalance:
        return AddOpeningBalanceForm(onBack: onBack, onDone: onDone);
      case _AddType.profile:
        return AddProfileForm(onBack: onBack, onDone: onDone);
    }
  }
}

class _TypePicker extends StatelessWidget {
  final ScrollController scrollController;
  final void Function(_AddType) onSelect;

  const _TypePicker({required this.scrollController, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const Text('Add', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(
          'What would you like to add?',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 18),
        _TypeTile(
          icon: Icons.arrow_downward_rounded,
          iconColor: AppColors.stable,
          title: 'Income',
          subtitle: 'Money coming in — salary, freelance, gifts',
          onTap: () => onSelect(_AddType.income),
        ),
        _TypeTile(
          icon: Icons.arrow_upward_rounded,
          iconColor: AppColors.storm,
          title: 'Expense',
          subtitle: 'A one-time purchase or payment',
          onTap: () => onSelect(_AddType.expense),
        ),
        _TypeTile(
          icon: Icons.event_repeat_rounded,
          iconColor: AppColors.pressure,
          title: 'Obligation',
          subtitle: 'Rent, EMI, subscription, utility bill',
          onTap: () => onSelect(_AddType.obligation),
        ),
        _TypeTile(
          icon: Icons.flag_rounded,
          iconColor: AppColors.accent,
          title: 'Goal',
          subtitle: 'A savings target to work toward',
          onTap: () => onSelect(_AddType.goal),
        ),
        _TypeTile(
          icon: Icons.account_balance_wallet_rounded,
          iconColor: AppColors.textSecondary,
          title: 'Current balance',
          subtitle: 'Set your starting balance so you\'re not stuck at ₹0',
          onTap: () => onSelect(_AddType.openingBalance),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => onSelect(_AddType.profile),
            child: const Text('Set up profile & preferences'),
          ),
        ),
      ],
    );
  }
}

class _TypeTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TypeTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
