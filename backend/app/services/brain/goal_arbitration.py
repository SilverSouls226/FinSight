from typing import List, Dict, Any
from app.schemas.financial import FinancialStateSnapshot, Goal, SuggestedAction
from app.services.brain.risk_engine import DetectedIssue

class ArbitrationResult:
    def __init__(self, actions: List[SuggestedAction], reasoning_facts: List[str]):
        self.actions = actions
        self.reasoning_facts = reasoning_facts

class GoalArbitration:
    def arbitrate(self, snapshot: FinancialStateSnapshot, issues: List[DetectedIssue]) -> ArbitrationResult:
        actions: List[SuggestedAction] = []
        reasoning_facts: List[str] = []
        
        checking = snapshot.current_balances.get("checking", 0.0)
        savings = snapshot.current_balances.get("savings", 0.0)
        
        currency = snapshot.currency or "INR"
        symbol = "₹" if currency == "INR" else ("$" if currency == "USD" else f"{currency} ")
        
        # Check if there is an obligation conflict or shortfall issue
        conflict = next((i for i in issues if i.issue_type == "obligation_conflict"), None)
        shortfall = next((i for i in issues if i.issue_type == "cash_shortfall"), None)
        
        if conflict:
            # Checking is low. Let's see if savings has enough to cover it
            gap = conflict.financial_impact
            obligation_name = conflict.metadata.get("obligation_name", "your bill")
            
            # User Preference Priority Rule: Mandatory obligations first. Rent due in 5 days is a constraint.
            reasoning_facts.append(f"CONSTRAINT: {obligation_name} of {symbol}{conflict.metadata.get('amount'):.2f} due soon.")
            reasoning_facts.append(f"OBSERVATION: Checking balance ({symbol}{checking:.2f}) is insufficient.")
            
            if savings >= gap:
                # Suggest transfer from savings
                # Check if savings is emergency fund
                emergency_goal = next((g for g in snapshot.active_goals if "emergency" in g.name.lower()), None)
                if emergency_goal and savings >= gap:
                    reasoning_facts.append("USER PREFERENCE: Liquidity and mandatory obligations have higher priority than preserving emergency fund targets.")
                    actions.append(SuggestedAction(
                        action_type="transfer",
                        description=f"Transfer {symbol}{gap:.2f} from your Emergency Fund to Checking to cover the gap for {obligation_name}.",
                        requires_user_approval=True
                    ))
                    reasoning_facts.append(f"DECISION: Recommend transfer of {symbol}{gap:.2f} from Emergency Fund to Checking.")
                    reasoning_facts.append("EXPECTED EFFECT: Shortfall risk decreases; obligation is covered.")
                else:
                    actions.append(SuggestedAction(
                        action_type="transfer",
                        description=f"Transfer {symbol}{gap:.2f} from Savings to Checking to cover the gap for {obligation_name}.",
                        requires_user_approval=True
                    ))
                    reasoning_facts.append(f"DECISION: Recommend transfer of {symbol}{gap:.2f} from Savings to Checking.")
                    reasoning_facts.append("EXPECTED EFFECT: Obligation covered without overdraft.")
            else:
                # Savings is also insufficient. Let's cut discretionary spending or pause goals.
                reasoning_facts.append("OBSERVATION: Total savings is insufficient to cover the gap.")
                
        # Cut discretionary spending if safe-to-spend is positive
        if snapshot.safe_to_spend > 0 and (conflict or shortfall):
            actions.append(SuggestedAction(
                action_type="budget_cut",
                description=f"Reduce discretionary spending (safe-to-spend) by {symbol}{snapshot.safe_to_spend:.2f} to conserve cash."
            ))
            reasoning_facts.append(f"DECISION: Reduce discretionary safe-to-spend to $0.00.")
            reasoning_facts.append("EXPECTED EFFECT: Cash outflow rate decreases.")
            
        # Pause low priority goals if there is a shortfall
        if shortfall or conflict:
            for goal in snapshot.active_goals:
                if goal.priority in ("low", "medium") and goal.current_amount < goal.target_amount:
                    actions.append(SuggestedAction(
                        action_type="pause_goal",
                        description=f"Pause monthly savings contributions to '{goal.name}' until cash flow stabilizes."
                    ))
                    reasoning_facts.append(f"DECISION: Pause lower-priority savings goal contributions for '{goal.name}'.")
                    reasoning_facts.append(f"EXPECTED EFFECT: Diverted funds reduce shortfall probability.")

        # Default action if no issues detected
        if not actions:
            reasoning_facts.append("OBSERVATION: No cash flow or obligation issues detected.")
            reasoning_facts.append("USER PREFERENCE: Maintain current savings and discretionary levels.")
            reasoning_facts.append("DECISION: No immediate budget adjustments or transfers needed.")
            reasoning_facts.append("EXPECTED EFFECT: Stable state.")

        return ArbitrationResult(actions=actions, reasoning_facts=reasoning_facts)
