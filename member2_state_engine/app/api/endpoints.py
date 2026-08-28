import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime, timezone
import numpy as np

from ..database.database import get_db
from ..database import models as db_models
from ..models import schemas
from ..services.financial_engine import (
    calculate_safe_to_spend,
    project_variable_income,
    run_monte_carlo_simulation,
    next_occurrence,
)

router = APIRouter()


def _as_utc(dt, now: datetime):
    """SQLite stores naive datetimes; treat them as UTC to compare with `now`."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def _ingest_normalized_event(event: schemas.NormalizedFinancialEvent, db: Session) -> dict:
    """
    Shared by POST /events (external ingestion, e.g. SMS parsing) and
    POST /entries (manual "Add" flow) -- both ultimately produce the same
    NormalizedFinancialEvent and must update the balance identically.
    """
    existing = db.query(db_models.TransactionEvent).filter(db_models.TransactionEvent.event_id == event.event_id).first()
    if existing:
        return {"status": "ignored", "message": "Event already processed"}

    db_event = db_models.TransactionEvent(**event.model_dump())
    db.add(db_event)

    user_state = db.query(db_models.UserState).filter(db_models.UserState.user_id == event.user_id).first()
    if not user_state:
        user_state = db_models.UserState(user_id=event.user_id, checking_balance=0.0, savings_balance=0.0)
        db.add(user_state)

    if event.type == "income":
        user_state.checking_balance += event.amount
    elif event.type in ["expense", "bill_due"]:
        user_state.checking_balance -= event.amount

    user_state.last_updated = datetime.now(timezone.utc)
    db.commit()
    return {"status": "success", "message": "Event processed successfully"}


@router.post("/events", status_code=201)
def ingest_event(event: schemas.NormalizedFinancialEvent, db: Session = Depends(get_db)):
    return _ingest_normalized_event(event, db)


@router.post("/entries", status_code=201, response_model=schemas.NormalizedFinancialEvent)
def add_manual_entry(entry: schemas.ManualEntryCreate, db: Session = Depends(get_db)):
    """
    Manual "Add" flow for Income / Expense / Opening balance. Builds a
    NormalizedFinancialEvent server-side (auto event_id, source and
    confidence_score fixed per the manual-entry contract) so the client
    never generates an event_id itself, then ingests it exactly like any
    other event.
    """
    event = schemas.NormalizedFinancialEvent(
        event_id=f"evt_manual_{uuid.uuid4().hex[:16]}",
        user_id=entry.user_id,
        timestamp=entry.date or datetime.now(timezone.utc),
        source="user_input",
        type=entry.type,
        amount=entry.amount,
        currency=entry.currency,
        vendor=entry.vendor,
        confidence_score=1.0,
        is_recurring=entry.is_recurring,
    )
    _ingest_normalized_event(event, db)
    return event


@router.get("/financial-state/{user_id}", response_model=schemas.FinancialStateSnapshot)
def get_financial_state(user_id: str, db: Session = Depends(get_db)):
    now = datetime.now(timezone.utc)

    user_state = db.query(db_models.UserState).filter(db_models.UserState.user_id == user_id).first()
    if not user_state:
        user_state = db_models.UserState(user_id=user_id, checking_balance=0.0, savings_balance=0.0, last_updated=now)

    income_events = db.query(db_models.TransactionEvent).filter(
        db_models.TransactionEvent.user_id == user_id,
        db_models.TransactionEvent.type == "income"
    ).all()

    income_amounts = [e.amount for e in income_events]
    projection = project_variable_income(income_amounts)

    obligations = db.query(db_models.Obligation).filter(
        db_models.Obligation.user_id == user_id,
        db_models.Obligation.is_active == True,  # noqa: E712
    ).all()
    upcoming_obs = []
    for o in obligations:
        due_date_utc = _as_utc(o.due_date, now)
        rolled_due_date = next_occurrence(due_date_utc, o.recurrence or "monthly", now)
        upcoming_obs.append(schemas.UpcomingObligation(name=o.name, amount=o.amount, due_date=rolled_due_date, category=o.category))
    obs_total = sum(o.amount for o in upcoming_obs)

    goals = db.query(db_models.Goal).filter(
        db_models.Goal.user_id == user_id,
        db_models.Goal.is_active == True,  # noqa: E712
    ).all()
    active_goals = [schemas.ActiveGoal(name=g.name, target_amount=g.target_amount, current_amount=g.current_amount, priority=g.priority) for g in goals]

    profile = db.query(db_models.UserProfile).filter(db_models.UserProfile.user_id == user_id).first()
    safety_buffer = profile.safety_buffer if profile else 100.0

    safe_spend = calculate_safe_to_spend(user_state.checking_balance, obs_total, safety_buffer)

    return schemas.FinancialStateSnapshot(
        user_id=user_id,
        last_updated=user_state.last_updated,
        current_balances=schemas.CurrentBalances(checking=user_state.checking_balance, savings=user_state.savings_balance),
        projected_income_30_days=schemas.ProjectedIncome(estimated_amount=projection["estimated_amount"], variance=projection["variance"]),
        upcoming_obligations=upcoming_obs,
        active_goals=active_goals,
        safe_to_spend=safe_spend
    )


@router.post("/simulate/{user_id}")
def simulate_scenario(user_id: str, proposed_expense: float, db: Session = Depends(get_db)):
    user_state = db.query(db_models.UserState).filter(db_models.UserState.user_id == user_id).first()
    current_balance = user_state.checking_balance if user_state else 0.0

    income_events = db.query(db_models.TransactionEvent).filter(
        db_models.TransactionEvent.user_id == user_id,
        db_models.TransactionEvent.type == "income"
    ).all()

    income_amounts = [e.amount for e in income_events]
    if not income_amounts:
        mean_inc, std_inc = 0.0, 0.0
    else:
        mean_inc = float(np.mean(income_amounts))
        std_inc = float(np.std(income_amounts)) if len(income_amounts) > 1 else 0.0

    obligations = db.query(db_models.Obligation).filter(db_models.Obligation.user_id == user_id).all()
    obs_total = sum(o.amount for o in obligations)

    base_risk = run_monte_carlo_simulation(current_balance, mean_inc, std_inc, obs_total)
    new_risk = run_monte_carlo_simulation(current_balance - proposed_expense, mean_inc, std_inc, obs_total)

    return {
        "user_id": user_id,
        "proposed_expense": proposed_expense,
        "base_shortfall_risk_percent": round(base_risk * 100, 2),
        "new_shortfall_risk_percent": round(new_risk * 100, 2),
        "is_safe": new_risk < 0.20
    }

@router.post("/goals", status_code=201)
def add_goal(goal: schemas.GoalCreate, db: Session = Depends(get_db)):
    db_goal = db_models.Goal(**goal.model_dump())
    db.add(db_goal)
    db.commit()
    return {"status": "success", "message": "Goal added"}

@router.post("/obligations", status_code=201)
def add_obligation(obligation: schemas.ObligationCreate, db: Session = Depends(get_db)):
    db_ob = db_models.Obligation(**obligation.model_dump())
    db.add(db_ob)
    db.commit()
    return {"status": "success", "message": "Obligation added"}


@router.post("/users", status_code=200, response_model=schemas.UserProfileOut)
def upsert_user_profile(profile: schemas.UserProfileUpsert, db: Session = Depends(get_db)):
    """
    Create or update the "Profile & Preferences" record used for the Add
    sheet's profile form. `safety_buffer` feeds directly into
    calculate_safe_to_spend on the next GET /financial-state call.
    """
    db_profile = db.query(db_models.UserProfile).filter(db_models.UserProfile.user_id == profile.user_id).first()
    if not db_profile:
        db_profile = db_models.UserProfile(user_id=profile.user_id)
        db.add(db_profile)

    db_profile.name = profile.name
    db_profile.risk_tolerance = profile.risk_tolerance
    db_profile.safety_buffer = profile.safety_buffer
    db_profile.priorities = ",".join(profile.priorities)
    db_profile.preferred_currency = profile.preferred_currency
    db.commit()
    db.refresh(db_profile)

    return _profile_to_out(db_profile)


@router.get("/users/{user_id}", response_model=schemas.UserProfileOut)
def get_user_profile(user_id: str, db: Session = Depends(get_db)):
    db_profile = db.query(db_models.UserProfile).filter(db_models.UserProfile.user_id == user_id).first()
    if not db_profile:
        raise HTTPException(status_code=404, detail="No profile set for this user yet.")
    return _profile_to_out(db_profile)


def _profile_to_out(db_profile: db_models.UserProfile) -> schemas.UserProfileOut:
    return schemas.UserProfileOut(
        user_id=db_profile.user_id,
        name=db_profile.name,
        risk_tolerance=db_profile.risk_tolerance,
        safety_buffer=db_profile.safety_buffer,
        priorities=[p for p in (db_profile.priorities or "").split(",") if p],
        preferred_currency=db_profile.preferred_currency,
    )
