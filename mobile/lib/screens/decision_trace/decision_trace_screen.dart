import 'package:flutter/material.dart';

import '../../models/intervention.dart';
import '../../theme/app_colors.dart';

/// Screen 6: Decision Trace.
/// Shows WHY FinSentinel intervened as a chain: contributing factors
/// leading to the final recommendation.
class DecisionTraceScreen extends StatelessWidget {
  final ContextualIntervention intervention;

  const DecisionTraceScreen({super.key, required this.intervention});

  @override
  Widget build(BuildContext context) {
    final trace = intervention.effectiveDecisionTrace;

    return Scaffold(
      appBar: AppBar(title: const Text('Decision Trace')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(intervention.title,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('How FinSentinel reached this recommendation',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          for (int i = 0; i < trace.length; i++)
            _TraceStep(
              index: i + 1,
              factor: trace[i].factor,
              detail: trace[i].detail,
              isLast: false,
            ),
          _TraceStep(
            index: trace.length + 1,
            factor: 'Recommendation',
            detail: intervention.summary,
            isLast: true,
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _TraceStep extends StatelessWidget {
  final int index;
  final String factor;
  final String detail;
  final bool isLast;
  final bool highlight;

  const _TraceStep({
    required this.index,
    required this.factor,
    required this.detail,
    required this.isLast,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.accent : AppColors.textMuted;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: highlight ? AppColors.accent : AppColors.surfaceRaised,
                  shape: BoxShape.circle,
                  border: Border.all(color: color),
                ),
                child: Center(
                  child: highlight
                      ? const Icon(Icons.flag_rounded, color: Colors.white, size: 14)
                      : Text('$index',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: AppColors.border, margin: const EdgeInsets.symmetric(vertical: 4)),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(factor,
                      style: TextStyle(
                        color: highlight ? AppColors.accent : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      )),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(detail, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
