from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime
from .database import Base
from datetime import datetime, timezone

class TransactionEvent(Base):
    __tablename__ = "transaction_events"

    id = Column(Integer, primary_key=True, index=True)
    event_id = Column(String, unique=True, index=True)
    user_id = Column(String, index=True)
    timestamp = Column(DateTime)
    source = Column(String)
    type = Column(String)
    amount = Column(Float)
    currency = Column(String)
    vendor = Column(String)
    confidence_score = Column(Float)
    is_recurring = Column(Boolean)

class UserState(Base):
    __tablename__ = "user_states"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, unique=True, index=True)
    checking_balance = Column(Float, default=0.0)
    savings_balance = Column(Float, default=0.0)
    last_updated = Column(DateTime, default=lambda: datetime.now(timezone.utc))

class Obligation(Base):
    __tablename__ = "obligations"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, index=True)
    name = Column(String)
    amount = Column(Float)
    due_date = Column(DateTime)
    category = Column(String)
    # Internal only -- never exposed on the FinancialStateSnapshot contract's
    # UpcomingObligation. Used to roll due_date forward once it's passed.
    # One of: once | weekly | monthly | quarterly | yearly.
    recurrence = Column(String, default="monthly")
    is_active = Column(Boolean, default=True)

class Goal(Base):
    __tablename__ = "goals"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, index=True)
    name = Column(String)
    target_amount = Column(Float)
    current_amount = Column(Float, default=0.0)
    priority = Column(String)
    # Internal only -- not part of the locked ActiveGoal contract.
    deadline = Column(DateTime, nullable=True)
    is_active = Column(Boolean, default=True)

class UserProfile(Base):
    """
    Combines the spec's "users" + "user_preferences" concepts into one
    table for simplicity -- purely additive, not part of any locked
    contract (FinancialStateSnapshot/ContextualIntervention untouched).
    """
    __tablename__ = "user_profiles"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, unique=True, index=True)
    name = Column(String, nullable=True)
    risk_tolerance = Column(String, default="moderate")
    # Minimum cash reserve calculate_safe_to_spend must protect.
    safety_buffer = Column(Float, default=100.0)
    # Comma-separated FinancialPriority values, e.g. "stabilize_cash_flow,build_emergency_fund".
    priorities = Column(String, default="")
    preferred_currency = Column(String, default="INR")
