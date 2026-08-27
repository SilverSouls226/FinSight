import re
from typing import List, Tuple
from .models import TranscriptEvent

class RiskEngine:
    def __init__(self):
        self.risk_score = 0
        self.indicators = set()
        
        # Rule sets mapped to risk score increases and indicators
        self.rules = [
            (re.compile(r'\b(otp|one time password|code)\b', re.IGNORECASE), 40, "OTP_REQUEST"),
            (re.compile(r'\b(bank|account|credit card)\b', re.IGNORECASE), 15, "BANK_IMPERSONATION"),
            (re.compile(r'\b(urgent|immediately|suspend|block|freeze)\b', re.IGNORECASE), 20, "URGENCY"),
            (re.compile(r'\b(verify|identity|ssn|social security)\b', re.IGNORECASE), 30, "IDENTITY_VERIFICATION"),
            (re.compile(r'\b(suspicious activity|unauthorized|fraud)\b', re.IGNORECASE), 25, "SUSPICIOUS_ACTIVITY_CLAIM"),
            (re.compile(r'\b(transfer|send money|wire|zelle|venmo)\b', re.IGNORECASE), 30, "MONEY_TRANSFER_REQUEST"),
        ]

    def analyze(self, event: TranscriptEvent) -> Tuple[int, List[str]]:
        """
        Analyzes a single transcript event and updates the running risk score.
        Returns the current risk score and a list of indicators.
        """
        text = event.text
        
        for pattern, score_bump, indicator in self.rules:
            if pattern.search(text) and indicator not in self.indicators:
                self.indicators.add(indicator)
                self.risk_score = min(100, self.risk_score + score_bump)
                
        return self.risk_score, list(self.indicators)
        
    def reset(self):
        self.risk_score = 0
        self.indicators = set()
