import re
from datetime import datetime, timezone
import uuid
from typing import Optional, Dict, Any

class SMSParser:
    """
    Parses typical Indian bank SMS formats using Regex.
    Returns a dictionary matching the core fields of NormalizedFinancialEvent,
    but without user_id and event_id which are assigned later.
    """
    
    # Regex patterns for common SMS formats
    # Example: "Rs 500.00 debited from a/c **1234 on 28-08-26 to Zomato."
    # Example: "Credited INR 1,000.50 to a/c **1234 on 28-08-26 from Employer."
    
    EXPENSE_PATTERN = re.compile(
        r"(?i)(?:rs\.?|inr)\s*([\d,]+(?:\.\d{1,2})?)\s*(?:is\s*)?(?:debited|spent|deducted).*?(?:to|at|info[:\s]*)\s*([a-zA-Z0-9\s]+?)(?:\.|\son\s)"
    )
    
    INCOME_PATTERN = re.compile(
        r"(?i)(?:credited|deposited).+?(?:rs\.?|inr)\s*([\d,]+(?:\.\d{1,2})?).*?(?:from|by)\s*([a-zA-Z0-9\s]+?)(?:\.|\s)"
    )

    def parse(self, sms_text: str) -> Optional[Dict[str, Any]]:
        """
        Extracts amount, vendor, and type from SMS text.
        Returns a dict of extracted fields or None if parsing fails.
        """
        # Try expense first
        expense_match = self.EXPENSE_PATTERN.search(sms_text)
        if expense_match:
            amount_str = expense_match.group(1).replace(",", "")
            vendor = expense_match.group(2).strip()
            
            return {
                "source": "sms",
                "type": "expense",
                "amount": float(amount_str),
                "currency": "INR", # Assuming INR for this regex set
                "vendor": vendor,
                "confidence_score": 0.9, # High confidence for regex match, but not 1.0 (Bank API is 1.0)
                "is_recurring": False, # Cannot determine from a single SMS reliably
                "timestamp": datetime.now(timezone.utc) # Fallback, should ideally extract date
            }
            
        # Try income
        income_match = self.INCOME_PATTERN.search(sms_text)
        if income_match:
            amount_str = income_match.group(1).replace(",", "")
            vendor = income_match.group(2).strip()
            
            return {
                "source": "sms",
                "type": "income",
                "amount": float(amount_str),
                "currency": "INR",
                "vendor": vendor,
                "confidence_score": 0.9,
                "is_recurring": False,
                "timestamp": datetime.now(timezone.utc)
            }
            
        # If no match, return a low confidence partial match or None.
        # For simplicity in this hackathon, we return None for failed parsing.
        return None
