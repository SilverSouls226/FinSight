import 'package:flutter/material.dart';

import '../models/financial_state_snapshot.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';

class ObligationTile extends StatelessWidget {
  final UpcomingObligation obligation;

  const ObligationTile({super.key, required this.obligation});

  @override
  Widget build(BuildContext context) {
    final isFixed = obligation.category == ObligationCategory.fixedEssential;
    final tagColor = isFixed ? AppColors.pressure : AppColors.accent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isFixed ? Icons.home_work_rounded : Icons.shopping_bag_rounded,
              color: tagColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  obligation.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  daysUntil(obligation.dueDate),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            formatCurrency(obligation.amount),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
