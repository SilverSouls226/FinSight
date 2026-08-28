from datetime import datetime, timedelta, timezone
from app.services.financial_engine import (
    calculate_safe_to_spend,
    project_variable_income,
    run_monte_carlo_simulation,
    next_occurrence,
)

def test_calculate_safe_to_spend():
    balance = 1500.0
    obligations = 1000.0
    buffer = 100.0
    
    # 1500 - 1000 - 100 = 400
    safe = calculate_safe_to_spend(balance, obligations, buffer)
    assert safe == 400.0

def test_calculate_safe_to_spend_negative():
    # If obligations are higher than balance, safe to spend should be 0, not negative
    safe = calculate_safe_to_spend(500.0, 1000.0, 100.0)
    assert safe == 0.0

def test_project_variable_income():
    # Mean of 1000, 2000, 1500 is 1500
    history = [1000.0, 2000.0, 1500.0]
    projection = project_variable_income(history)
    assert projection["estimated_amount"] == 1500.0
    assert projection["variance"] > 0

def test_monte_carlo():
    risk = run_monte_carlo_simulation(1000, 1500, 200, 2000, num_simulations=100)
    # Risk should be a probability between 0 and 1
    assert 0.0 <= risk <= 1.0

def test_next_occurrence_future_date_unchanged():
    now = datetime(2026, 1, 1, tzinfo=timezone.utc)
    future = now + timedelta(days=10)
    assert next_occurrence(future, "monthly", now) == future

def test_next_occurrence_once_never_rolls_forward():
    now = datetime(2026, 1, 1, tzinfo=timezone.utc)
    overdue = now - timedelta(days=40)
    assert next_occurrence(overdue, "once", now) == overdue

def test_next_occurrence_monthly_rolls_to_next_cycle():
    now = datetime(2026, 1, 1, tzinfo=timezone.utc)
    overdue = now - timedelta(days=5)  # one 30-day cycle ago would still be in the past
    rolled = next_occurrence(overdue, "monthly", now)
    assert rolled >= now
    assert rolled == overdue + timedelta(days=30)

def test_next_occurrence_weekly_rolls_past_multiple_cycles():
    now = datetime(2026, 1, 1, tzinfo=timezone.utc)
    overdue = now - timedelta(days=20)  # 2+ weeks overdue
    rolled = next_occurrence(overdue, "weekly", now)
    assert rolled >= now
    assert (rolled - overdue).days % 7 == 0
