import 'package:flutter/material.dart';

import '../../models/intervention.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/severity_badge.dart';
import '../decision_trace/decision_trace_screen.dart';

class InterventionDetailScreen extends StatelessWidget {
  final ContextualIntervention intervention;

  const InterventionDetailScreen({super.key, required this.intervention});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.severityColor(intervention.severity.name);

    return Scaffold(
      appBar: AppBar(title: const Text('Intervention')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              SeverityBadge(severity: intervention.severity),
              const Spacer(),
              Text(formatDateTime(intervention.timestamp),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
          Text(intervention.title,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(intervention.summary,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
          const SizedBox(height: 20),
          Card(
            color: color.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.psychology_alt_outlined, color: color, size: 18),
                      const SizedBox(width: 8),
                      Text('WHY THIS MATTERS',
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(intervention.explanation,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => DecisionTraceScreen(intervention: intervention)),
            ),
            icon: const Icon(Icons.account_tree_outlined),
            label: const Text('See full decision trace'),
          ),
          const SizedBox(height: 24),
          const Text('SUGGESTED ACTIONS',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
          const SizedBox(height: 10),
          ...intervention.suggestedActions.map((a) => _ActionCard(action: a)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final SuggestedAction action;

  const _ActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_iconFor(action.actionType), color: AppColors.accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(action.description,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, height: 1.4)),
                  if (action.requiresUserApproval) ...[
                    const SizedBox(height: 6),
                    const Text('Requires your approval',
                        style: TextStyle(color: AppColors.pressure, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String actionType) {
    switch (actionType) {
      case 'transfer':
        return Icons.sync_alt_rounded;
      case 'budget_cut':
        return Icons.content_cut_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }
}
