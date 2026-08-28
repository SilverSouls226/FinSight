from pydantic import BaseModel
from typing import List
from datetime import datetime

class NormalizedFinancialEvent(BaseModel):
    event_id: str
    user_id: str
    timestamp: datetime
    source: str
    type: str
    amount: float
    currency: str
    vendor: str
    confidence_score: float
    is_recurring: bool

class CurrentBalances(BaseModel):
    checking: float
    savings: float

class ProjectedIncome(BaseModel):
    estimated_amount: float
    variance: float

class UpcomingObligation(BaseModel):
    name: str
    amount: float
    due_date: datetime
    category: str

class ActiveGoal(BaseModel):
    name: str
    target_amount: float
    current_amount: float
    priority: str

class FinancialStateSnapshot(BaseModel):
    user_id: str
    last_updated: datetime
    current_balances: CurrentBalances
    projected_income_30_days: ProjectedIncome
    upcoming_obligations: List[UpcomingObligation]
    active_goals: List[ActiveGoal]
    safe_to_spend: float

class ObligationCreate(BaseModel):
    user_id: str
    name: str
    amount: float
    due_date: datetime
    category: str

class GoalCreate(BaseModel):
    user_id: str
    name: str
    target_amount: float
    current_amount: float = 0.0
    priority: str
