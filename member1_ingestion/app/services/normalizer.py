import uuid
from typing import Dict, Any, Optional
from datetime import datetime, timezone

from app.models.event import NormalizedFinancialEvent
from app.parsers.sms_parser import SMSParser
from app.parsers.gemini_parser import GeminiReceiptParser
from app.services.deduplication import DeduplicationEngine

class NormalizationService:
    """
    Orchestrates the ingestion pipeline:
    Raw Input -> Parser -> Deduplication -> Validation -> Normalized Event
    """
    def __init__(self):
        self.sms_parser = SMSParser()
        self.gemini_parser = GeminiReceiptParser()
        self.deduplicator = DeduplicationEngine()

    def process_raw_input(self, user_id: str, raw_text: str, source: str) -> Optional[NormalizedFinancialEvent]:
        """
        Takes raw text and returns a strictly validated Pydantic model.
        Returns None if parsing fails or if it's a duplicate.
        """
        extracted_data = None
        
        # 1. Extraction
        if source == "sms":
            extracted_data = self.sms_parser.parse(raw_text)
        elif source == "receipt":
            extracted_data = self.gemini_parser.parse_text(raw_text)
            
        if not extracted_data:
            return None # Parsing failed
            
        # 2. Deduplication / Conflict Detection
        # The prompt requires handling duplicates.
        if self.deduplicator.is_duplicate(extracted_data):
            print(f"Duplicate detected and dropped: {extracted_data}")
            return None
            
        # 3. Finalize Data (Add required fields missing from parsers)
        extracted_data["event_id"] = f"evt_{uuid.uuid4().hex[:12]}"
        extracted_data["user_id"] = user_id
        
        if "timestamp" not in extracted_data:
            extracted_data["timestamp"] = datetime.now(timezone.utc)
            
        if "is_recurring" not in extracted_data:
            extracted_data["is_recurring"] = False
            
        # 4. Strict Validation (Pydantic)
        try:
            validated_event = NormalizedFinancialEvent(**extracted_data)
            return validated_event
        except Exception as e:
            print(f"Validation failed against contract: {e}")
            return None
