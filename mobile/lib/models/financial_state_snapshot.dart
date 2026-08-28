/// Dart models for the "Financial State Snapshot" contract.
///
/// Source of truth: docs/api_contracts.md, Contract 2
/// (Sanjani's State Engine -> Sameer's AI Brain & Kalyan's Flutter app).
///
/// Field names and nesting intentionally mirror the JSON contract exactly.
/// `shortfallProbability30d` is an OPTIONAL, additive field (nullable) not
/// yet part of the locked contract. It is read when present (forward
/// compatible with a future backend addition) and otherwise derived on
/// device by [RiskEstimator] so the UI never depends on an unlocked field.
library;

class FinancialStateSnapshot {
  final String userId;
  final DateTime lastUpdated;
  final CurrentBalances currentBalances;
  final ProjectedIncome projectedIncome30Days;
  final List<UpcomingObligation> upcomingObligations;
  final List<ActiveGoal> activeGoals;
  final double safeToSpend;

  /// Optional forward-compatible field. Null when the backend hasn't sent it.
  final double? shortfallProbability30d;

  const FinancialStateSnapshot({
    required this.userId,
    required this.lastUpdated,
    required this.currentBalances,
    required this.projectedIncome30Days,
    required this.upcomingObligations,
    required this.activeGoals,
    required this.safeToSpend,
    this.shortfallProbability30d,
  });

  factory FinancialStateSnapshot.fromJson(Map<String, dynamic> json) {
    return FinancialStateSnapshot(
      userId: json['user_id'] as String? ?? '',
      lastUpdated: DateTime.tryParse(json['last_updated'] as String? ?? '') ??
          DateTime.now(),
      currentBalances: CurrentBalances.fromJson(
        (json['current_balances'] as Map<String, dynamic>?) ?? const {},
      ),
      projectedIncome30Days: ProjectedIncome.fromJson(
        (json['projected_income_30_days'] as Map<String, dynamic>?) ??
            const {},
      ),
      upcomingObligations: ((json['upcoming_obligations'] as List?) ?? const [])
          .map((e) => UpcomingObligation.fromJson(e as Map<String, dynamic>))
          .toList(),
      activeGoals: ((json['active_goals'] as List?) ?? const [])
          .map((e) => ActiveGoal.fromJson(e as Map<String, dynamic>))
          .toList(),
      safeToSpend: _toDouble(json['safe_to_spend']) ?? 0.0,
      shortfallProbability30d: _toDouble(json['shortfall_probability_30d']),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'last_updated': lastUpdated.toIso8601String(),
        'current_balances': currentBalances.toJson(),
        'projected_income_30_days': projectedIncome30Days.toJson(),
        'upcoming_obligations':
            upcomingObligations.map((e) => e.toJson()).toList(),
        'active_goals': activeGoals.map((e) => e.toJson()).toList(),
        'safe_to_spend': safeToSpend,
        if (shortfallProbability30d != null)
          'shortfall_probability_30d': shortfallProbability30d,
      };

  double get totalBalance => currentBalances.checking + currentBalances.savings;

  double get totalUpcomingObligations =>
      upcomingObligations.fold(0.0, (sum, o) => sum + o.amount);
}

class CurrentBalances {
  final double checking;
  final double savings;

  /// Any additional account balances the backend sends beyond the two
  /// documented keys are preserved here without being dropped.
  final Map<String, double> other;

  const CurrentBalances({
    required this.checking,
    required this.savings,
    this.other = const {},
  });

  factory CurrentBalances.fromJson(Map<String, dynamic> json) {
    final other = <String, double>{};
    json.forEach((key, value) {
      if (key != 'checking' && key != 'savings') {
        final parsed = _toDouble(value);
        if (parsed != null) other[key] = parsed;
      }
    });
    return CurrentBalances(
      checking: _toDouble(json['checking']) ?? 0.0,
      savings: _toDouble(json['savings']) ?? 0.0,
      other: other,
    );
  }

  Map<String, dynamic> toJson() => {
        'checking': checking,
        'savings': savings,
        ...other,
      };

  double get total => checking + savings + other.values.fold(0.0, (a, b) => a + b);
}

class ProjectedIncome {
  final double estimatedAmount;
  final double variance;

  const ProjectedIncome({required this.estimatedAmount, required this.variance});

  factory ProjectedIncome.fromJson(Map<String, dynamic> json) {
    return ProjectedIncome(
      estimatedAmount: _toDouble(json['estimated_amount']) ?? 0.0,
      variance: _toDouble(json['variance']) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'estimated_amount': estimatedAmount,
        'variance': variance,
      };

  double get lowerBound => (estimatedAmount - variance).clamp(0, double.infinity);
  double get upperBound => estimatedAmount + variance;
}

enum ObligationCategory { fixedEssential, discretionary, unknown }

ObligationCategory _categoryFromString(String? value) {
  switch (value) {
    case 'fixed_essential':
      return ObligationCategory.fixedEssential;
    case 'discretionary':
      return ObligationCategory.discretionary;
    default:
      return ObligationCategory.unknown;
  }
}

String _categoryToString(ObligationCategory category) {
  switch (category) {
    case ObligationCategory.fixedEssential:
      return 'fixed_essential';
    case ObligationCategory.discretionary:
      return 'discretionary';
    case ObligationCategory.unknown:
      return 'unknown';
  }
}

class UpcomingObligation {
  final String name;
  final double amount;
  final DateTime dueDate;
  final ObligationCategory category;

  const UpcomingObligation({
    required this.name,
    required this.amount,
    required this.dueDate,
    required this.category,
  });

  factory UpcomingObligation.fromJson(Map<String, dynamic> json) {
    return UpcomingObligation(
      name: json['name'] as String? ?? 'Obligation',
      amount: _toDouble(json['amount']) ?? 0.0,
      dueDate: DateTime.tryParse(json['due_date'] as String? ?? '') ??
          DateTime.now(),
      category: _categoryFromString(json['category'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'due_date': dueDate.toIso8601String(),
        'category': _categoryToString(category),
      };
}

enum GoalPriority { high, medium, low }

GoalPriority _priorityFromString(String? value) {
  switch (value) {
    case 'high':
      return GoalPriority.high;
    case 'medium':
      return GoalPriority.medium;
    case 'low':
      return GoalPriority.low;
    default:
      return GoalPriority.medium;
  }
}

String _priorityToString(GoalPriority priority) => priority.name;

class ActiveGoal {
  final String name;
  final double targetAmount;
  final double currentAmount;
  final GoalPriority priority;

  const ActiveGoal({
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.priority,
  });

  factory ActiveGoal.fromJson(Map<String, dynamic> json) {
    return ActiveGoal(
      name: json['name'] as String? ?? 'Goal',
      targetAmount: _toDouble(json['target_amount']) ?? 0.0,
      currentAmount: _toDouble(json['current_amount']) ?? 0.0,
      priority: _priorityFromString(json['priority'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'target_amount': targetAmount,
        'current_amount': currentAmount,
        'priority': _priorityToString(priority),
      };

  double get progress =>
      targetAmount <= 0 ? 0.0 : (currentAmount / targetAmount).clamp(0.0, 1.0);
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
