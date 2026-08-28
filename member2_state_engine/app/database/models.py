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

class Goal(Base):
    __tablename__ = "goals"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, index=True)
    name = Column(String)
    target_amount = Column(Float)
    current_amount = Column(Float, default=0.0)
    priority = Column(String)
