import 'package:flutter/material.dart';

import '../models/intervention.dart';
import '../theme/app_colors.dart';

class SeverityBadge extends StatelessWidget {
  final InterventionSeverity severity;

  const SeverityBadge({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.severityColor(severity.name);
    final label = switch (severity) {
      InterventionSeverity.high => 'HIGH',
      InterventionSeverity.medium => 'MEDIUM',
      InterventionSeverity.info => 'INFO',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            severity == InterventionSeverity.high
                ? Icons.priority_high_rounded
                : severity == InterventionSeverity.medium
                    ? Icons.warning_amber_rounded
                    : Icons.info_outline_rounded,
            color: color,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
