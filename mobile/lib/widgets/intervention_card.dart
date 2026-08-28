import 'package:flutter/material.dart';

import '../models/intervention.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'severity_badge.dart';

class InterventionCard extends StatelessWidget {
  final ContextualIntervention intervention;
  final VoidCallback onTap;

  const InterventionCard({
    super.key,
    required this.intervention,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.severityColor(intervention.severity.name);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SeverityBadge(severity: intervention.severity),
                  const Spacer(),
                  Text(
                    formatDateTime(intervention.timestamp),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                intervention.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                intervention.summary,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.arrow_forward_rounded, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(
                    'View why & suggested actions',
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
