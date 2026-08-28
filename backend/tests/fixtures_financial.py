from datetime import datetime, timezone, timedelta
from typing import Dict, Any

# Baseline dates
now = datetime.now(timezone.utc)
future_5_days = now + timedelta(days=5)
future_20_days = now + timedelta(days=20)
future_3_days = now + timedelta(days=3)

# 1. Low-risk state
low_risk_state = {
    "user_id": "usr_123",
    "last_updated": now.isoformat(),
    "current_balances": {
        "checking": 2500.00,
        "savings": 8000.00
    },
    "projected_income_30_days": {
        "estimated_amount": 4000.00,
        "variance": 100.00
    },
    "upcoming_obligations": [
        {
            "name": "Subscription",
            "amount": 15.00,
            "due_date": future_20_days.isoformat(),
            "category": "fixed_essential"
        }
    ],
    "active_goals": [
        {
            "name": "Emergency Fund",
            "target_amount": 10000.00,
            "current_amount": 8000.00,
            "priority": "high"
        }
    ],
    "safe_to_spend": 800.00,
    "confidence_score": 1.0,
    "user_profile": {
        "risk_tolerance": "moderate",
        "minimum_liquidity_threshold": 500.00
    }
}

# 2. High shortfall risk
high_shortfall_risk = {
    "user_id": "usr_123",
    "last_updated": now.isoformat(),
    "current_balances": {
        "checking": 200.00,
        "savings": 100.00
    },
    "projected_income_30_days": {
        "estimated_amount": 1000.00,
        "variance": 500.00
    },
    "upcoming_obligations": [
        {
            "name": "Apartment Rent",
            "amount": 1100.00,
            "due_date": future_5_days.isoformat(),
            "category": "fixed_essential"
        }
    ],
    "active_goals": [
        {
            "name": "Emergency Fund",
            "target_amount": 10000.00,
            "current_amount": 100.00,
            "priority": "high"
        }
    ],
    "safe_to_spend": 0.00,
    "confidence_score": 1.0,
    "user_profile": {
        "risk_tolerance": "moderate",
        "minimum_liquidity_threshold": 500.00
    }
}

# 3. Income drop (high variance)
income_drop = {
    "user_id": "usr_123",
    "last_updated": now.isoformat(),
    "current_balances": {
        "checking": 1000.00,
        "savings": 2000.00
    },
    "projected_income_30_days": {
        "estimated_amount": 1500.00,
        "variance": 600.00  # variance is 40% of estimated amount (high volatility)
    },
    "upcoming_obligations": [
        {
            "name": "Utility Bill",
            "amount": 100.00,
            "due_date": future_20_days.isoformat(),
            "category": "fixed_essential"
        }
    ],
    "active_goals": [],
    "safe_to_spend": 100.00,
    "confidence_score": 1.0,
    "user_profile": {
        "risk_tolerance": "moderate",
        "minimum_liquidity_threshold": 500.00
    }
}

# 4. Upcoming rent collision
rent_collision = {
    "user_id": "usr_123",
    "last_updated": now.isoformat(),
    "current_balances": {
        "checking": 150.00,
        "savings": 5000.00
    },
    "projected_income_30_days": {
        "estimated_amount": 800.00,
        "variance": 100.00
    },
    "upcoming_obligations": [
        {
            "name": "Apartment Rent",
            "amount": 1100.00,
            "due_date": future_5_days.isoformat(),
            "category": "fixed_essential"
        }
    ],
    "active_goals": [
        {
            "name": "Emergency Fund",
            "target_amount": 10000.00,
            "current_amount": 5000.00,
            "priority": "high"
        }
    ],
    "safe_to_spend": 0.00,
    "confidence_score": 1.0,
    "user_profile": {
        "risk_tolerance": "moderate",
        "minimum_liquidity_threshold": 500.00
    }
}

# 5. Multiple competing goals
competing_goals = {
    "user_id": "usr_123",
    "last_updated": now.isoformat(),
    "current_balances": {
        "checking": 150.00,
        "savings": 2000.00
    },
    "projected_income_30_days": {
        "estimated_amount": 1200.00,
        "variance": 300.00
    },
    "upcoming_obligations": [
        {
            "name": "Apartment Rent",
            "amount": 1100.00,
            "due_date": future_5_days.isoformat(),
            "category": "fixed_essential"
        }
    ],
    "active_goals": [
        {
            "name": "Emergency Fund",
            "target_amount": 10000.00,
            "current_amount": 2000.00,
            "priority": "high"
        },
        {
            "name": "Vacation Trip",
            "target_amount": 1500.00,
            "current_amount": 500.00,
            "priority": "low"
        }
    ],
    "safe_to_spend": 100.00,
    "confidence_score": 1.0,
    "user_profile": {
        "risk_tolerance": "moderate",
        "minimum_liquidity_threshold": 500.00
    }
}

# 6. Low confidence information
low_confidence_state = {
    "user_id": "usr_123",
    "last_updated": now.isoformat(),
    "current_balances": {
        "checking": 150.00,
        "savings": 5000.00
    },
    "projected_income_30_days": {
        "estimated_amount": 800.00,
        "variance": 100.00
    },
    "upcoming_obligations": [
        {
            "name": "Apartment Rent",
            "amount": 1100.00,
            "due_date": future_5_days.isoformat(),
            "category": "fixed_essential"
        }
    ],
    "active_goals": [],
    "safe_to_spend": 0.00,
    "confidence_score": 0.5,  # Low confidence should degrade alert severity
    "user_profile": {
        "risk_tolerance": "moderate",
        "minimum_liquidity_threshold": 500.00
    }
}

# 7. Notification fatigue (low impact)
low_impact_state = {
    "user_id": "usr_123",
    "last_updated": now.isoformat(),
    "current_balances": {
        "checking": 5000.00,
        "savings": 10000.00
    },
    "projected_income_30_days": {
        "estimated_amount": 3000.00,
        "variance": 100.00
    },
    "upcoming_obligations": [
        {
            "name": "Minor Bill",
            "amount": 15.00,  # small absolute amount
            "due_date": future_5_days.isoformat(),
            "category": "fixed_essential"
        }
    ],
    "active_goals": [],
    "safe_to_spend": 500.00,
    "confidence_score": 1.0,
    "user_profile": {
        "risk_tolerance": "moderate",
        "minimum_liquidity_threshold": 500.00
    }
}

# 8. Critical case
critical_case = {
    "user_id": "usr_123",
    "last_updated": now.isoformat(),
    "current_balances": {
        "checking": 50.00,
        "savings": 100.00
    },
    "projected_income_30_days": {
        "estimated_amount": 200.00,
        "variance": 50.00
    },
    "upcoming_obligations": [
        {
            "name": "Apartment Rent",
            "amount": 1100.00,
            "due_date": future_3_days.isoformat(),  # 3 days (highly urgent)
            "category": "fixed_essential"
        }
    ],
    "active_goals": [],
    "safe_to_spend": 0.00,
    "confidence_score": 1.0,
    "user_profile": {
        "risk_tolerance": "moderate",
        "minimum_liquidity_threshold": 500.00
    }
}
