import json
import logging
import uuid
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional
import httpx

from app.core.config import settings
from app.schemas.financial import FinancialStateSnapshot, ContextualIntervention, SuggestedAction
from app.services.brain.risk_engine import DetectedIssue
from app.services.brain.goal_arbitration import ArbitrationResult

logger = logging.getLogger(__name__)


class GroqReasoner:
    def __init__(self, api_key: Optional[str] = None):
        # Fall back to config settings if no key is provided
        self.api_key = api_key or settings.GROQ_API_KEY
        self.api_url = "https://api.groq.com/openai/v1/chat/completions"
        self.model = "openai/gpt-oss-20b"

    def _map_severity(self, gate_severity: str) -> str:
        """Map gate internal severity to Contract 3 expected values: info, medium, high."""
        mapping = {
            "CRITICAL": "high",
            "NOTIFY": "high",
            "MONITOR": "medium",
            "IGNORE": "info"
        }
        return mapping.get(gate_severity, "info")

    def _generate_fallback(
        self,
        snapshot: FinancialStateSnapshot,
        issues: List[DetectedIssue],
        arbitration: ArbitrationResult,
        gate_severity: str
    ) -> ContextualIntervention:
        """Generate a valid, structured intervention using deterministic local templates."""
        logger.info("Using deterministic fallback engine for intervention generation.")
        
        severity_out = self._map_severity(gate_severity)
        
        if issues:
            primary_issue = max(issues, key=lambda x: x.severity_score)
            title = primary_issue.title
            summary = primary_issue.description
        else:
            title = "Financial Portfolio Stable"
            summary = "No immediate cash flow or obligation risks detected."
            
        # Combine arbitration facts into a structured explanation paragraph
        explanation_parts = []
        explanation_parts.append("DECISION TRACE:")
        for fact in arbitration.reasoning_facts:
            explanation_parts.append(f"- {fact}")
        
        # Rule 1: Flag if information has low confidence
        confidence = snapshot.confidence_score if snapshot.confidence_score is not None else 1.0
        if confidence < 0.70:
            explanation_parts.append(
                "WARNING: This intervention was generated with low-confidence data due to potential delays in receipt or SMS updates. "
                "Please verify transaction details in your banking portal."
            )
            
        explanation = "\n".join(explanation_parts)
        
        # Determine if approval is required
        requires_approval = any(a.requires_user_approval for a in arbitration.actions)
        
        return ContextualIntervention(
            intervention_id=f"int_{uuid.uuid4().hex[:8]}",
            user_id=snapshot.user_id,
            timestamp=datetime.now(timezone.utc),
            severity=severity_out,
            title=title,
            summary=summary,
            explanation=explanation,
            suggested_actions=arbitration.actions,
            requires_user_approval=requires_approval
        )

    def generate_intervention(
        self,
        snapshot: FinancialStateSnapshot,
        issues: List[DetectedIssue],
        arbitration: ArbitrationResult,
        gate_severity: str
    ) -> ContextualIntervention:
        """
        Generate contextual intervention using Groq API.
        If key is missing, or API call fails/returns malformed output, fall back gracefully to deterministic templates.
        """
        if not self.api_key:
            logger.warning("Groq API key is missing. Using local fallback explainer.")
            return self._generate_fallback(snapshot, issues, arbitration, gate_severity)
            
        # Format the pre-computed facts, arbitration output, and gate decisions
        facts_payload = {
            "user_id": snapshot.user_id,
            "current_balances": snapshot.current_balances,
            "projected_income": snapshot.projected_income_30_days.model_dump(),
            "safe_to_spend": snapshot.safe_to_spend,
            "gate_severity": gate_severity,
            "detected_issues": [issue.to_dict() for issue in issues],
            "arbitrated_actions": [a.model_dump() for a in arbitration.actions],
            "decision_trace_facts": arbitration.reasoning_facts,
            "confidence_score": snapshot.confidence_score if snapshot.confidence_score is not None else 1.0
        }
        
        prompt = f"""
You are the AI Reasoning Brain for the FinSentinel proactive personal financial assistant.
You are given a JSON containing deterministic financial truth computed by our Python backend:
{json.dumps(facts_payload, indent=2)}

Generate a Contextual Intervention JSON payload that matches the schema:
{{
  "intervention_id": "string (unique ID starting with int_)",
  "user_id": "string",
  "timestamp": "ISO-8601 string",
  "severity": "string (MUST be one of: 'info', 'medium', 'high')",
  "title": "string (actionable title)",
  "summary": "string (one-line summary of the issue)",
  "explanation": "string (detailed explanation matching the DECISION TRACE and facts)",
  "suggested_actions": [
    {{
      "action_type": "string",
      "description": "string",
      "requires_user_approval": boolean
    }}
  ],
  "requires_user_approval": boolean (true if any action requires approval)
}}

CRITICAL SAFETY RULES:
1. NEVER invent any financial facts, numbers, dates, or balances.
2. Rely ONLY on the pre-computed values provided.
3. The explanation MUST explain the "WHY" behind the recommendations, incorporating the observations, constraints, and decisions from the decision trace facts.
4. If confidence_score is less than 0.7, you MUST include a cautionary disclaimer warning the user that this advice is based on incomplete or unconfirmed data.
5. Return ONLY a raw JSON object. No Markdown blocks, no preamble, no explanation outside the JSON.
"""

        try:
            # Call Groq API completions endpoint synchronously via httpx
            with httpx.Client(timeout=10.0) as client:
                response = client.post(
                    self.api_url,
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": self.model,
                        "messages": [
                            {"role": "system", "content": "You are a precise API backend that outputs strict JSON conforming to schemas without comment."},
                            {"role": "user", "content": prompt}
                        ],
                        "response_format": {"type": "json_object"},
                        "temperature": 0.0
                    }
                )
                
                if response.status_code != 200:
                    logger.error(f"Groq API returned error status {response.status_code}: {response.text}")
                    return self._generate_fallback(snapshot, issues, arbitration, gate_severity)
                    
                data = response.json()
                content = data["choices"][0]["message"]["content"]
                
                # Parse and validate the response
                intervention_dict = json.loads(content)
                
                # Check fields and parse with Pydantic for validation
                # Ensure we don't allow Groq to modify key details or invent values
                # We overwrite the user_id, timestamp, severity, and suggested_actions to match Python's deterministic outputs
                # if the model outputs them incorrectly.
                return ContextualIntervention(
                    intervention_id=intervention_dict.get("intervention_id") or f"int_{uuid.uuid4().hex[:8]}",
                    user_id=snapshot.user_id,
                    timestamp=datetime.now(timezone.utc),
                    severity=self._map_severity(gate_severity),
                    title=intervention_dict.get("title") or (issues[0].title if issues else "Financial Portfolio"),
                    summary=intervention_dict.get("summary") or (issues[0].description if issues else "Finances stable."),
                    explanation=intervention_dict.get("explanation", ""),
                    suggested_actions=arbitration.actions,  # Enforce Python's actions
                    requires_user_approval=any(a.requires_user_approval for a in arbitration.actions)
                )
                
        except Exception as exc:
            logger.error(f"Failed to generate intervention via Groq: {exc}")
            return self._generate_fallback(snapshot, issues, arbitration, gate_severity)
