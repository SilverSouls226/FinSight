from fastapi import APIRouter, Depends, HTTPException
from app.schemas.financial import FinancialStateSnapshot, ContextualIntervention
from app.services.brain.risk_engine import RiskEngine
from app.services.brain.goal_arbitration import GoalArbitration
from app.services.brain.intervention_gate import InterventionGate
from app.services.brain.groq_reasoner import GroqReasoner

router = APIRouter()

@router.post(
    "/evaluate/{user_id}",
    response_model=ContextualIntervention,
    summary="Evaluate user financial state snapshot and generate contextual interventions",
    description=(
        "Consumes a Financial State Snapshot, detects risks and opportunities deterministically, "
        "arbitrates competing goals, applies the Intervention Gate decision logic, "
        "and generates a contextual intervention explanation using Groq."
    )
)
def evaluate_financial_state(user_id: str, snapshot: FinancialStateSnapshot) -> ContextualIntervention:
    # Validate user ID consistency
    if snapshot.user_id != user_id:
        raise HTTPException(status_code=400, detail="User ID mismatch between path and snapshot body.")

    # 1. Deterministic Risk Engine
    risk_engine = RiskEngine()
    issues = risk_engine.detect_issues(snapshot)

    # 2. Goal Arbitration
    arbitration_engine = GoalArbitration()
    arbitration = arbitration_engine.arbitrate(snapshot, issues)

    # 3. Intervention Gate Python Decision Layer
    gate = InterventionGate()
    gate_severity = gate.evaluate(snapshot, issues)

    # 4. Groq Reasoning Layer (with local fallback if IGNORE or if Groq is unavailable)
    reasoner = GroqReasoner()
    
    # If the gate decides to IGNORE, we bypass Groq to prevent notification fatigue and save latency
    if gate_severity == "IGNORE":
        # Create a simple safe intervention that requires no action
        return reasoner._generate_fallback(snapshot, [], arbitration, gate_severity)

    # Otherwise, invoke the reasoning pipeline (which will call Groq or use the fallback if key is missing/failed)
    intervention = reasoner.generate_intervention(snapshot, issues, arbitration, gate_severity)
    return intervention
