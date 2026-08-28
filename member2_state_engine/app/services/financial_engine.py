import numpy as np
from datetime import datetime, timedelta
from typing import List

def next_occurrence(due_date: datetime, recurrence: str, now: datetime) -> datetime:
    """
    Rolls a recurring obligation's due_date forward to the next occurrence
    at or after `now`. A "once" obligation is never rolled forward -- a
    one-time bill stays on its original date even if it's overdue.

    Uses fixed-day intervals (not calendar-month arithmetic) to avoid a
    new dependency; close enough for a 30-day projection horizon.
    """
    if recurrence == "once" or due_date >= now:
        return due_date

    interval_days = {
        "weekly": 7,
        "monthly": 30,
        "quarterly": 91,
        "yearly": 365,
    }.get(recurrence)

    if interval_days is None:
        return due_date

    next_date = due_date
    while next_date < now:
        next_date += timedelta(days=interval_days)
    return next_date

def calculate_safe_to_spend(current_balance: float, upcoming_obligations_total: float, minimum_buffer: float = 100.0) -> float:
    """
    Calculates how much money is safe to spend today.
    Rule: Must protect mandatory obligations and a minimum safety buffer.
    """
    safe_amount = current_balance - upcoming_obligations_total - minimum_buffer
    return max(0.0, safe_amount)

def project_variable_income(historical_incomes: List[float]) -> dict:
    """
    Predicts future income based on past variability.
    Rule: Never assume income is fixed for gig workers.
    """
    if not historical_incomes:
        return {"estimated_amount": 0.0, "variance": 0.0}
    
    estimated = float(np.mean(historical_incomes))
    # If we only have 1 data point, variance is 0
    variance = float(np.var(historical_incomes)) if len(historical_incomes) > 1 else 0.0
    
    return {
        "estimated_amount": estimated,
        "variance": variance
    }

def run_monte_carlo_simulation(
    current_balance: float,
    mean_income: float,
    income_std_dev: float,
    upcoming_expenses: float,
    num_simulations: int = 5000
) -> float:
    """
    Runs thousands of 'What-if' scenarios to calculate the exact probability 
    of the user running out of money (cash shortfall).
    Returns a probability float between 0.0 and 1.0.
    """
    shortfall_count = 0
    
    for _ in range(num_simulations):
        # We simulate their variable income using a normal distribution
        simulated_income = max(0, np.random.normal(mean_income, income_std_dev))
        
        # What would their balance be after income arrives and bills are paid?
        simulated_balance = current_balance + simulated_income - upcoming_expenses
        
        # If it drops below zero, that's a shortfall
        if simulated_balance < 0:
            shortfall_count += 1
            
    # Calculate the percentage of simulations that resulted in going broke
    probability_of_shortfall = shortfall_count / num_simulations
    return float(probability_of_shortfall)
