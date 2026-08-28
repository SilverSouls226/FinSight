from app.services.financial_engine import calculate_safe_to_spend, project_variable_income, run_monte_carlo_simulation

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
