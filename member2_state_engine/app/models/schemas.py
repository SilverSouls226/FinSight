from pydantic import BaseModel, Field
from typing import List, Literal, Optional
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

Recurrence = Literal["once", "weekly", "monthly", "quarterly", "yearly"]

class ObligationCreate(BaseModel):
    user_id: str
    name: str = Field(..., min_length=1)
    amount: float = Field(..., gt=0)
    due_date: datetime
    category: str = "fixed_essential"
    # Internal only -- rolls due_date forward once passed. Not returned on
    # the FinancialStateSnapshot's UpcomingObligation.
    recurrence: Recurrence = "monthly"

class GoalCreate(BaseModel):
    user_id: str
    name: str = Field(..., min_length=1)
    target_amount: float = Field(..., gt=0)
    current_amount: float = Field(0.0, ge=0)
    priority: str = "medium"
    # Internal only -- not part of the locked ActiveGoal contract.
    deadline: Optional[datetime] = None

class ManualEntryCreate(BaseModel):
    """
    Request body for POST /entries -- the manual "Add" flow's Income /
    Expense / Opening-balance forms. Builds a NormalizedFinancialEvent
    server-side (event_id, source="user_input", confidence_score=1.0) so
    the client never has to generate an event_id.
    """
    user_id: str
    type: Literal["income", "expense"]
    amount: float = Field(..., gt=0)
    vendor: str = Field(..., min_length=1)
    date: Optional[datetime] = None
    is_recurring: bool = False
    currency: str = "INR"

class UserProfileUpsert(BaseModel):
    user_id: str
    name: Optional[str] = None
    risk_tolerance: Literal["conservative", "moderate", "aggressive"] = "moderate"
    safety_buffer: float = Field(100.0, ge=0)
    priorities: List[str] = Field(default_factory=list)
    preferred_currency: str = "INR"

class UserProfileOut(BaseModel):
    user_id: str
    name: Optional[str] = None
    risk_tolerance: str
    safety_buffer: float
    priorities: List[str]
    preferred_currency: str
