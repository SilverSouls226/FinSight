import json
import logging
from typing import Optional

import httpx

from app.core.config import settings
from app.schemas.financial import FinancialStateSnapshot

logger = logging.getLogger(__name__)


class ChatReasoner:
    """
    Answers a freeform question about a user's Financial State Snapshot.

    Reuses the same Groq setup as GroqReasoner (intervention generation) but
    for open-ended Q&A instead of a fixed intervention schema. Falls back to
    a small deterministic answer set if the API key is missing or the call
    fails, so the assistant is never completely silent.
    """

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or settings.GROQ_API_KEY
        self.api_url = "https://api.groq.com/openai/v1/chat/completions"
        self.model = "openai/gpt-oss-20b"

    def _fallback(self, question: str, snapshot: FinancialStateSnapshot) -> str:
        logger.info("Using deterministic fallback for chat (no Groq key or call failed).")
        q = question.lower()

        if "safe" in q or "afford" in q:
            return f"You have {snapshot.currency} {snapshot.safe_to_spend:,.0f} safe to spend right now."

        if "due" in q or "obligation" in q or "bill" in q:
            if not snapshot.upcoming_obligations:
                return "You have no upcoming obligations tracked right now."
            next_ob = min(snapshot.upcoming_obligations, key=lambda o: o.due_date)
            return f"{next_ob.name} is next, {snapshot.currency} {next_ob.amount:,.0f}, due {next_ob.due_date.date()}."

        if "goal" in q:
            if not snapshot.active_goals:
                return "You don't have any active goals set up yet."
            lines = [
                f"{g.name}: {g.current_amount:,.0f}/{g.target_amount:,.0f}"
                for g in snapshot.active_goals
            ]
            return " | ".join(lines)

        total = sum(snapshot.current_balances.values())
        return (
            f"Your total balance is {snapshot.currency} {total:,.0f} and your "
            f"safe-to-spend is {snapshot.currency} {snapshot.safe_to_spend:,.0f}. "
            "Ask me about obligations, goals, or your balance for more detail."
        )

    def answer(self, question: str, snapshot: FinancialStateSnapshot) -> str:
        if not self.api_key:
            return self._fallback(question, snapshot)

        facts_payload = {
            "current_balances": snapshot.current_balances,
            "projected_income_30_days": snapshot.projected_income_30_days.model_dump(),
            "upcoming_obligations": [o.model_dump() for o in snapshot.upcoming_obligations],
            "active_goals": [g.model_dump() for g in snapshot.active_goals],
            "safe_to_spend": snapshot.safe_to_spend,
            "currency": snapshot.currency,
        }

        prompt = f"""
You are the "Twin Assistant" inside FinSentinel's Financial Digital Twin screen.
A user is asking a question about their own finances. Here is the ONLY data you
are allowed to use, as JSON:
{json.dumps(facts_payload, indent=2, default=str)}

User's question: "{question}"

RULES:
1. NEVER invent any number, date, or fact not present in the JSON above.
2. If the question cannot be answered from this data, say so plainly and
   suggest what you CAN answer (balance, obligations, goals, safe-to-spend).
3. Answer in at most 2-3 short sentences, plain text, no markdown, no preamble.
4. Be warm but direct -- this is a financial control panel, not a chatbot toy.
"""

        try:
            with httpx.Client(timeout=10.0) as client:
                response = client.post(
                    self.api_url,
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": self.model,
                        "messages": [
                            {
                                "role": "system",
                                "content": "You are a precise, concise financial assistant. Never invent facts.",
                            },
                            {"role": "user", "content": prompt},
                        ],
                        "temperature": 0.2,
                    },
                )

                if response.status_code != 200:
                    logger.error(f"Groq API returned error status {response.status_code}: {response.text}")
                    return self._fallback(question, snapshot)

                data = response.json()
                content = data["choices"][0]["message"]["content"].strip()
                return content or self._fallback(question, snapshot)

        except Exception as exc:
            logger.error(f"Failed to answer chat via Groq: {exc}")
            return self._fallback(question, snapshot)
