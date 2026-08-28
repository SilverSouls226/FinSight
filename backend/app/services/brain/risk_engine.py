from datetime import datetime, timezone
from typing import List, Dict, Any
from app.schemas.financial import FinancialStateSnapshot, Obligation, Goal

class DetectedIssue:
    def __init__(
        self,
        issue_type: str,
        title: str,
        description: str,
        severity_score: float,      # 0.0 to 1.0
        probability: float,         # 0.0 to 1.0
        urgency_days: int,          # Days until critical threshold
        financial_impact: float,    # Dollar amount impact
        metadata: Dict[str, Any]
    ):
        self.issue_type = issue_type
        self.title = title
        self.description = description
        self.severity_score = severity_score
        self.probability = probability
        self.urgency_days = urgency_days
        self.financial_impact = financial_impact
        self.metadata = metadata

    def to_dict(self) -> Dict[str, Any]:
        return {
            "issue_type": self.issue_type,
            "title": self.title,
            "description": self.description,
            "severity_score": self.severity_score,
            "probability": self.probability,
            "urgency_days": self.urgency_days,
            "financial_impact": self.financial_impact,
            "metadata": self.metadata,
        }


class RiskEngine:
    def detect_issues(self, snapshot: FinancialStateSnapshot) -> List[DetectedIssue]:
        issues: List[DetectedIssue] = []
        
        checking = snapshot.current_balances.get("checking", 0.0)
        savings = snapshot.current_balances.get("savings", 0.0)
        total_balance = checking + savings
        
        est_income = snapshot.projected_income_30_days.estimated_amount
        income_var = snapshot.projected_income_30_days.variance
        
        currency = snapshot.currency or "INR"
        symbol = "₹" if currency == "INR" else ("$" if currency == "USD" else f"{currency} ")
        
        # 1. Rule 3: Fixed Obligations vs Discretionary & Checking Collision
        essential_obligations = [o for o in snapshot.upcoming_obligations if o.category == "fixed_essential"]
        total_essential_due = sum(o.amount for o in essential_obligations)
        
        for obligation in essential_obligations:
            days_to_due = (obligation.due_date.replace(tzinfo=timezone.utc) - snapshot.last_updated.replace(tzinfo=timezone.utc)).days
            days_to_due = max(0, days_to_due)
            
            # If current checking balance cannot cover the upcoming bill
            if checking < obligation.amount:
                shortfall_amount = obligation.amount - checking
                # Check if projected income can cover the gap before due date
                # Simple rule: if days_to_due is short and checking is low
                urgency = days_to_due
                severity = min(1.0, shortfall_amount / max(1.0, checking))
                
                issues.append(DetectedIssue(
                    issue_type="obligation_conflict",
                    title=f"Insufficient Checking for {obligation.name}",
                    description=f"Your checking balance is {symbol}{checking:.2f}, but {obligation.name} of {symbol}{obligation.amount:.2f} is due in {days_to_due} days.",
                    severity_score=severity,
                    probability=1.0,
                    urgency_days=urgency,
                    financial_impact=shortfall_amount,
                    metadata={"obligation_name": obligation.name, "due_date": obligation.due_date.isoformat(), "amount": obligation.amount}
                ))

        # 2. Rule 2: Probabilistic Cash Shortfall (income variability)
        # Check worst-case scenario: est_income - variance
        worst_case_income = max(0.0, est_income - income_var)
        projected_shortfall = total_essential_due - (total_balance + worst_case_income)
        if projected_shortfall > 0:
            # We have a shortfall risk
            prob = 0.5 if income_var > 0 else 1.0
            if total_essential_due > (total_balance + est_income):
                # Shortfall even with expected income
                prob = 1.0
                severity = 0.9
            else:
                # Shortfall only in the low-income variance case
                # Probabilistic risk: estimated probability based on variance
                prob = 0.38  # Default custom probability as requested in trace examples
                severity = 0.5
                
            issues.append(DetectedIssue(
                issue_type="cash_shortfall",
                title="Projected Cash Flow Shortfall",
                description=f"Based on your upcoming obligations of {symbol}{total_essential_due:.2f} and variable income projections, there is a risk of a {symbol}{projected_shortfall:.2f} shortfall over the next 30 days.",
                severity_score=severity,
                probability=prob,
                urgency_days=15,  # Medium horizon
                financial_impact=projected_shortfall,
                metadata={"total_essential_due": total_essential_due, "worst_case_income": worst_case_income}
            ))

        # 3. Rule 2: Income Volatility Risk
        if est_income > 0 and (income_var / est_income) >= 0.25:
            issues.append(DetectedIssue(
                issue_type="income_drop",
                title="High Income Volatility Detected",
                description=f"Your projected income variance ({symbol}{income_var:.2f}) is {(income_var/est_income)*100:.1f}% of your estimated earnings ({symbol}{est_income:.2f}).",
                severity_score=0.4,
                probability=0.8,
                urgency_days=30,
                financial_impact=income_var,
                metadata={"variance": income_var, "estimated_amount": est_income}
            ))

        # 4. Rule 4: Savings Goal Risk
        for goal in snapshot.active_goals:
            if goal.current_amount < goal.target_amount:
                gap = goal.target_amount - goal.current_amount
                # If we have a shortfall risk, high priority goals are impacted
                if total_essential_due > total_balance:
                    severity = 0.7 if goal.priority == "high" else 0.3
                    issues.append(DetectedIssue(
                        issue_type="goal_risk",
                        title=f"Savings Goal Risk: {goal.name}",
                        description=f"Due to impending obligations, your progress toward the {goal.name} goal (current: {symbol}{goal.current_amount:.2f}/target: {symbol}{goal.target_amount:.2f}) is at risk.",
                        severity_score=severity,
                        probability=0.7,
                        urgency_days=30,
                        financial_impact=gap,
                        metadata={"goal_name": goal.name, "target_amount": goal.target_amount, "current_amount": goal.current_amount, "priority": goal.priority}
                    ))

        return issues
