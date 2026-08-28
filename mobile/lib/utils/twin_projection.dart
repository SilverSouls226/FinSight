import '../models/financial_state_snapshot.dart';

/// Shared client-side projection math used to *display* derived figures
/// (runway, net 30-day change) consistently across the Digital Twin chart,
/// stat tiles, and assistant. Presentation only — Sanjani's snapshot
/// remains the source of truth for every underlying number.
class TwinProjection {
  const TwinProjection._();

  /// Number of days until the projected balance first goes negative, or
  /// null if it stays non-negative through the full 30-day horizon.
  static int? runwayDays(FinancialStateSnapshot snapshot, {int horizonDays = 30}) {
    final startBalance = snapshot.currentBalances.checking;
    final income = snapshot.projectedIncome30Days.estimatedAmount;
    final obligations = [...snapshot.upcomingObligations]
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final now = snapshot.lastUpdated;

    for (int d = 0; d <= horizonDays; d++) {
      final t = d / horizonDays;
      final incomeSoFar = income * t;
      final cutoff = now.add(Duration(days: d));
      final paidSoFar = obligations
          .where((o) => !o.dueDate.isAfter(cutoff))
          .fold(0.0, (sum, o) => sum + o.amount);
      if (startBalance + incomeSoFar - paidSoFar < 0) return d;
    }
    return null;
  }

  /// Projected income minus total upcoming obligations over the horizon.
  static double netChange30Days(FinancialStateSnapshot snapshot) {
    return snapshot.projectedIncome30Days.estimatedAmount - snapshot.totalUpcomingObligations;
  }

  /// Projected income variance as a percentage of the estimate (0 if no income).
  static double incomeVariancePercent(FinancialStateSnapshot snapshot) {
    final income = snapshot.projectedIncome30Days;
    if (income.estimatedAmount <= 0) return 0;
    return (income.variance / income.estimatedAmount) * 100;
  }
}
