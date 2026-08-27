import uuid
from datetime import datetime
from .models import TranscriptEvent, ThreatResult
from .risk_engine import RiskEngine
from .scam_detector import ScamDetector

class AIPipeline:
    def __init__(self, call_id: str = None):
        self.call_id = call_id or str(uuid.uuid4())
        self.risk_engine = RiskEngine()
        self.scam_detector = ScamDetector()
        
    def get_risk_level(self, score: int) -> str:
        if score < 20: return "LOW"
        if score < 50: return "MEDIUM"
        if score < 80: return "HIGH"
        return "CRITICAL"
        
    def process_transcript_event(self, event: TranscriptEvent) -> str:
        """
        Process a new transcript event, update engines, and return JSON threat result.
        """
        # 1. Fast deterministic check
        score, indicators = self.risk_engine.analyze(event)
        risk_level = self.get_risk_level(score)
        
        # 2. Update LLM context
        self.scam_detector.add_transcript(event)
        
        # 3. LLM semantic check 
        # (Run on 'is_final' or if risk is already elevated to save API calls in real environment)
        llm_analysis = {"threat_type": "UNKNOWN", "recommendation": "Evaluating...", "explanation": ""}
        if event.is_final or score >= 50:
             llm_analysis = self.scam_detector.analyze_conversation()
             
        threat_type = llm_analysis.get("threat_type", "UNKNOWN")
        if threat_type in ("UNKNOWN", "NONE", "MOCK_SCAM") and score > 0:
            if "OTP_REQUEST" in indicators:
                threat_type = "OTP_SCAM"
            elif "BANK_IMPERSONATION" in indicators:
                threat_type = "BANK_IMPERSONATION_SCAM"
            elif "MONEY_TRANSFER_REQUEST" in indicators:
                threat_type = "MONEY_TRANSFER_SCAM"
            else:
                threat_type = "GENERAL_SUSPICIOUS"
                
        # 4. Construct standardized output
        result = ThreatResult(
            source="CALL",
            risk_score=score,
            risk_level=risk_level,
            threat_type=threat_type,
            indicators=indicators,
            recommendation=llm_analysis.get("recommendation", "Stay alert."),
            call_id=self.call_id,
            timestamp=datetime.utcnow()
        )
        
        return result.model_dump_json(indent=2)
