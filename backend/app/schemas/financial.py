from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class ProjectedIncome(BaseModel):
    estimated_amount: float
    variance: float


class Obligation(BaseModel):
    name: str
    amount: float
    due_date: datetime
    category: str  # e.g., "fixed_essential", "discretionary"


class Goal(BaseModel):
    name: str
    target_amount: float
    current_amount: float
    priority: str  # e.g., "high", "medium", "low"


class UserProfile(BaseModel):
    risk_tolerance: str = "moderate"  # "conservative", "moderate", "aggressive"
    minimum_liquidity_threshold: float = 500.00


class FinancialStateSnapshot(BaseModel):
    user_id: str
    last_updated: datetime
    current_balances: Dict[str, float]
    projected_income_30_days: ProjectedIncome
    upcoming_obligations: List[Obligation]
    active_goals: List[Goal]
    safe_to_spend: float
    currency: Optional[str] = "INR"
    user_profile: Optional[UserProfile] = Field(default_factory=UserProfile)
    confidence_score: Optional[float] = 1.0  # Rule 1: Confidence scoring


class SuggestedAction(BaseModel):
    action_type: str  # e.g., "transfer", "budget_cut", "pause_goal"
    description: str
    requires_user_approval: Optional[bool] = False


class ContextualIntervention(BaseModel):
    intervention_id: str
    user_id: str
    timestamp: datetime
    severity: str  # "info", "medium", "high" or "ignore", "monitor", "notify", "critical"
    title: str
    summary: str
    explanation: str
    suggested_actions: List[SuggestedAction]
    requires_user_approval: bool
