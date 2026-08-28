import os
import json
import google.generativeai as genai
from typing import Optional, Dict, Any
from datetime import datetime, timezone

class GeminiReceiptParser:
    """
    Uses Gemini API to extract structured financial data from messy text or images (receipts/bills).
    """
    def __init__(self):
        # Assumes GEMINI_API_KEY is set in the environment
        genai.configure(api_key=os.environ.get("GEMINI_API_KEY", "dummy_key_for_testing"))
        # Using a fast model for text extraction
        self.model = genai.GenerativeModel('gemini-1.5-flash')

    def parse_text(self, messy_text: str) -> Optional[Dict[str, Any]]:
        """
        Parses messy OCR or email text into a structured dictionary.
        """
        prompt = f"""
        Extract the following financial information from the text below. 
        Return ONLY a valid JSON object with the following keys and correct data types:
        - "type" (string): either "expense", "income", or "bill_due"
        - "amount" (float): the absolute total monetary amount
        - "currency" (string): 3-letter currency code (e.g., INR, USD)
        - "vendor" (string): the name of the merchant, sender, or receiver
        - "is_recurring" (boolean): true if it looks like a subscription or recurring bill, false otherwise

        Text:
        '''
        {messy_text}
        '''
        """
        try:
            # We enforce JSON response via instructions, though in production we'd use response_schema
            response = self.model.generate_content(prompt)
            raw_text = response.text.strip()
            
            # Clean up markdown if present
            if raw_text.startswith("```json"):
                raw_text = raw_text[7:-3]
            elif raw_text.startswith("```"):
                raw_text = raw_text[3:-3]
                
            data = json.loads(raw_text.strip())
            
            # Add metadata required by our contract
            data["source"] = "receipt"
            data["confidence_score"] = 0.75 # Lower confidence than SMS or Bank API due to LLM hallucination risk
            data["timestamp"] = datetime.now(timezone.utc)
            
            return data
            
        except Exception as e:
            print(f"Gemini parsing failed: {e}")
            return None
