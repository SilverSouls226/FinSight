/// Local onboarding profile captured on-device.
///
/// This is NOT part of the locked API contracts in docs/api_contracts.md.
/// It exists purely to drive the mobile onboarding UX (risk tolerance,
/// priorities, and starter goals). When the backend exposes a user-profile
/// endpoint, this model's `toJson()` output is the payload to send — no UI
/// rewrite needed, only wiring inside a future `ApiUserProfileService`.
library;

enum RiskTolerance { conservative, moderate, aggressive }

extension RiskToleranceLabel on RiskTolerance {
  String get label {
    switch (this) {
      case RiskTolerance.conservative:
        return 'Conservative';
      case RiskTolerance.moderate:
        return 'Moderate';
      case RiskTolerance.aggressive:
        return 'Aggressive';
    }
  }

  String get description {
    switch (this) {
      case RiskTolerance.conservative:
        return 'Warn me early. I prefer a large safety buffer.';
      case RiskTolerance.moderate:
        return 'Balance safety and flexibility.';
      case RiskTolerance.aggressive:
        return 'Only warn me when risk is significant.';
    }
  }
}

enum FinancialPriority {
  buildEmergencyFund,
  payDownDebt,
  saveForGoal,
  stabilizeCashFlow,
  growInvestments,
}

extension FinancialPriorityLabel on FinancialPriority {
  String get label {
    switch (this) {
      case FinancialPriority.buildEmergencyFund:
        return 'Build an emergency fund';
      case FinancialPriority.payDownDebt:
        return 'Pay down debt';
      case FinancialPriority.saveForGoal:
        return 'Save for a specific goal';
      case FinancialPriority.stabilizeCashFlow:
        return 'Stabilize month-to-month cash flow';
      case FinancialPriority.growInvestments:
        return 'Grow investments';
    }
  }
}

class UserProfile {
  final String name;
  final RiskTolerance riskTolerance;
  final List<FinancialPriority> priorities;
  final String? primaryGoalName;
  final double? primaryGoalTarget;

  const UserProfile({
    required this.name,
    required this.riskTolerance,
    required this.priorities,
    this.primaryGoalName,
    this.primaryGoalTarget,
  });

  UserProfile copyWith({
    String? name,
    RiskTolerance? riskTolerance,
    List<FinancialPriority>? priorities,
    String? primaryGoalName,
    double? primaryGoalTarget,
  }) {
    return UserProfile(
      name: name ?? this.name,
      riskTolerance: riskTolerance ?? this.riskTolerance,
      priorities: priorities ?? this.priorities,
      primaryGoalName: primaryGoalName ?? this.primaryGoalName,
      primaryGoalTarget: primaryGoalTarget ?? this.primaryGoalTarget,
    );
  }

  static const empty = UserProfile(
    name: '',
    riskTolerance: RiskTolerance.moderate,
    priorities: [],
  );

  Map<String, dynamic> toJson() => {
        'name': name,
        'risk_tolerance': riskTolerance.name,
        'priorities': priorities.map((p) => p.name).toList(),
        if (primaryGoalName != null) 'primary_goal_name': primaryGoalName,
        if (primaryGoalTarget != null) 'primary_goal_target': primaryGoalTarget,
      };

  /// Inverse of [toJson] — used to restore the profile saved on-device
  /// (see lib/services/user_profile_storage.dart) so onboarding doesn't
  /// re-run on every app restart.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String? ?? '',
      riskTolerance: RiskTolerance.values.firstWhere(
        (r) => r.name == json['risk_tolerance'],
        orElse: () => RiskTolerance.moderate,
      ),
      priorities: ((json['priorities'] as List?) ?? const [])
          .expand((p) => FinancialPriority.values.where((fp) => fp.name == p))
          .toList(),
      primaryGoalName: json['primary_goal_name'] as String?,
      primaryGoalTarget: (json['primary_goal_target'] as num?)?.toDouble(),
    );
  }
}
