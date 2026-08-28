/// Dart models for the "Contextual Intervention" contract.
///
/// Source of truth: docs/api_contracts.md, Contract 3
/// (Sameer's AI Brain -> Kalyan's Flutter app).
///
/// `decisionTrace` is an OPTIONAL, additive field (nullable list) not yet
/// part of the locked contract, used to power the Decision Trace screen.
/// When the backend doesn't send it, [DecisionTrace.fallback] derives a
/// best-effort trace from `explanation` so the screen still renders.
library;

enum InterventionSeverity { info, medium, high }

InterventionSeverity _severityFromString(String? value) {
  switch (value) {
    case 'high':
      return InterventionSeverity.high;
    case 'medium':
      return InterventionSeverity.medium;
    case 'info':
    default:
      return InterventionSeverity.info;
  }
}

String _severityToString(InterventionSeverity severity) => severity.name;

class ContextualIntervention {
  final String interventionId;
  final String userId;
  final DateTime timestamp;
  final InterventionSeverity severity;
  final String title;
  final String summary;
  final String explanation;
  final List<SuggestedAction> suggestedActions;

  /// Optional forward-compatible field. Falls back to a derived trace.
  final List<DecisionFactor>? decisionTrace;

  const ContextualIntervention({
    required this.interventionId,
    required this.userId,
    required this.timestamp,
    required this.severity,
    required this.title,
    required this.summary,
    required this.explanation,
    required this.suggestedActions,
    this.decisionTrace,
  });

  factory ContextualIntervention.fromJson(Map<String, dynamic> json) {
    return ContextualIntervention(
      interventionId: json['intervention_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      severity: _severityFromString(json['severity'] as String?),
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      suggestedActions: ((json['suggested_actions'] as List?) ?? const [])
          .map((e) => SuggestedAction.fromJson(e as Map<String, dynamic>))
          .toList(),
      decisionTrace: json['decision_trace'] == null
          ? null
          : ((json['decision_trace'] as List)
              .map((e) => DecisionFactor.fromJson(e as Map<String, dynamic>))
              .toList()),
    );
  }

  Map<String, dynamic> toJson() => {
        'intervention_id': interventionId,
        'user_id': userId,
        'timestamp': timestamp.toIso8601String(),
        'severity': _severityToString(severity),
        'title': title,
        'summary': summary,
        'explanation': explanation,
        'suggested_actions': suggestedActions.map((e) => e.toJson()).toList(),
        if (decisionTrace != null)
          'decision_trace': decisionTrace!.map((e) => e.toJson()).toList(),
      };

  /// Returns the backend-provided trace, or derives a fallback from the
  /// explanation text so the Decision Trace screen always has content.
  List<DecisionFactor> get effectiveDecisionTrace =>
      decisionTrace ?? DecisionFactor.fallbackFromExplanation(explanation);
}

class SuggestedAction {
  final String actionType;
  final String description;
  final bool requiresUserApproval;

  const SuggestedAction({
    required this.actionType,
    required this.description,
    this.requiresUserApproval = false,
  });

  factory SuggestedAction.fromJson(Map<String, dynamic> json) {
    return SuggestedAction(
      actionType: json['action_type'] as String? ?? 'info',
      description: json['description'] as String? ?? '',
      requiresUserApproval: json['requires_user_approval'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'action_type': actionType,
        'description': description,
        'requires_user_approval': requiresUserApproval,
      };
}

class DecisionFactor {
  final String factor;
  final String detail;

  const DecisionFactor({required this.factor, required this.detail});

  factory DecisionFactor.fromJson(Map<String, dynamic> json) {
    return DecisionFactor(
      factor: json['factor'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'factor': factor, 'detail': detail};

  static List<DecisionFactor> fallbackFromExplanation(String explanation) {
    final sentences = explanation
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (sentences.isEmpty) {
      return const [
        DecisionFactor(factor: 'No explanation available', detail: '')
      ];
    }
    return sentences
        .map((s) => DecisionFactor(factor: 'Contributing factor', detail: s))
        .toList();
  }
}
