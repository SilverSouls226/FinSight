from typing import List, Dict, Any
from app.schemas.financial import FinancialStateSnapshot, UserProfile
from app.services.brain.risk_engine import DetectedIssue

class InterventionGate:
    def evaluate(self, snapshot: FinancialStateSnapshot, issues: List[DetectedIssue]) -> str:
        """
        Evaluate the detected issues against deterministic thresholds and user profile settings.
        Returns one of: "IGNORE", "MONITOR", "NOTIFY", "CRITICAL".
        """
        if not issues:
            return "IGNORE"

        # Find the highest severity issue
        primary_issue = max(issues, key=lambda x: x.severity_score)
        
        # Rule 1: Ingestion confidence check
        confidence = snapshot.confidence_score if snapshot.confidence_score is not None else 1.0
        
        # User Profile & Risk Tolerance
        profile = snapshot.user_profile or UserProfile()
        risk_tolerance = profile.risk_tolerance
        
        # Notification Fatigue: minor impact checks
        checking = snapshot.current_balances.get("checking", 0.0)
        savings = snapshot.current_balances.get("savings", 0.0)
        total_balance = checking + savings
        
        # If the financial impact is negligible relative to assets, filter it out (Ignore)
        if total_balance > 0 and (primary_issue.financial_impact / total_balance) < 0.01:
            if primary_issue.financial_impact < 20.0:  # small absolute amount
                return "IGNORE"

        # Urgency & Probability thresholds adjusted by Risk Tolerance
        urgency_threshold_critical = 5
        urgency_threshold_notify = 15
        prob_threshold_critical = 0.70
        prob_threshold_notify = 0.35
        
        if risk_tolerance == "conservative":
            # Conservative users want alerts earlier and for lower probabilities
            urgency_threshold_critical = 8
            urgency_threshold_notify = 20
            prob_threshold_critical = 0.50
            prob_threshold_notify = 0.20
        elif risk_tolerance == "aggressive":
            # Aggressive users only want alerts when it's very close or highly probable
            urgency_threshold_critical = 3
            urgency_threshold_notify = 10
            prob_threshold_critical = 0.80
            prob_threshold_notify = 0.50

        # Determine decision based on primary issue parameters
        is_critical = (
            primary_issue.urgency_days <= urgency_threshold_critical and 
            primary_issue.probability >= prob_threshold_critical
        )
        
        is_notify = (
            primary_issue.urgency_days <= urgency_threshold_notify and 
            primary_issue.probability >= prob_threshold_notify
        )

        # Rule 1: Low Ingestion Confidence degrades notifications to avoid fatigue/false alerts
        if confidence < 0.70:
            if is_critical:
                return "MONITOR"  # Downgrade from CRITICAL to MONITOR
            else:
                return "IGNORE"   # Downgrade from NOTIFY/MONITOR to IGNORE
                
        if is_critical:
            return "CRITICAL"
        elif is_notify:
            return "NOTIFY"
        elif primary_issue.probability > 0.10:
            return "MONITOR"
        else:
            return "IGNORE"
