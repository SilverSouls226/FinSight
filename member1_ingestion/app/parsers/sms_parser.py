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
        r"(?i)(?:rs\.?|inr)\s*([\d,]+(?:\.\d{1,2})?)\s*(?:is\s*)?(?:debited|spent|deducted)[\s\S]*?(?:to|at|info[:\s]*)\s*([^\n(]+?)(?:\s*\(|\.|\son\s|$)"
    )

    # A debit with no named merchant at all, e.g. an ATM withdrawal or a
    # generic "A/c debited" alert -- EXPENSE_PATTERN above requires a
    # "to|at|info" vendor phrase and won't match these; still worth
    # recording the outgoing amount even without a vendor name.
    EXPENSE_PATTERN_NO_VENDOR = re.compile(
        r"(?i)(?:rs\.?|inr)\s*([\d,]+(?:\.\d{1,2})?)\s*(?:is\s*)?(?:debited|spent|deducted|withdrawn)"
    )

    # Some UPI debit confirmations use "Sent" instead of "debited" entirely,
    # e.g. "Sent Rs.1.00\nFrom HDFC Bank A/c XX2525\nTo VPA name@bank\n...".
    EXPENSE_PATTERN_SENT = re.compile(
        r"(?i)sent\s*(?:rs\.?|inr)\s*([\d,]+(?:\.\d{1,2})?)\b[\s\S]*?\bto\s+([^\n(]+?)(?:\s*\(|\.|\son\s|\n|$)"
    )
    
    INCOME_PATTERN = re.compile(
        r"(?i)(?:credited|deposited).+?(?:rs\.?|inr)\s*([\d,]+(?:\.\d{1,2})?).*?(?:from|by)\s*([a-zA-Z0-9\s]+?)(?:\.|\s)"
    )

    # Real bank alerts often lead with the amount before "credited", e.g.
    # "Rs.1.00 credited to HDFC Bank A/c XX2525 ... from VPA name@bank (UPI 123)"
    # -- INCOME_PATTERN above requires "credited" before the amount and won't
    # match this word order, so it's tried as a fallback.
    INCOME_PATTERN_AMOUNT_FIRST = re.compile(
        r"(?i)(?:rs\.?|inr)\s*([\d,]+(?:\.\d{1,2})?)\s*(?:is\s*)?(?:credited|deposited)[\s\S]*?(?:from|by)\s*([^\n(]+?)(?:\s*\(|\.|$)"
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

        sent_match = self.EXPENSE_PATTERN_SENT.search(sms_text)
        if sent_match:
            amount_str = sent_match.group(1).replace(",", "")
            vendor = sent_match.group(2).strip()

            return {
                "source": "sms",
                "type": "expense",
                "amount": float(amount_str),
                "currency": "INR",
                "vendor": vendor,
                "confidence_score": 0.9,
                "is_recurring": False,
                "timestamp": datetime.now(timezone.utc)
            }

        no_vendor_match = self.EXPENSE_PATTERN_NO_VENDOR.search(sms_text)
        if no_vendor_match:
            amount_str = no_vendor_match.group(1).replace(",", "")

            return {
                "source": "sms",
                "type": "expense",
                "amount": float(amount_str),
                "currency": "INR",
                "vendor": "Bank debit",
                "confidence_score": 0.75, # Lower confidence -- no merchant name extracted
                "is_recurring": False,
                "timestamp": datetime.now(timezone.utc)
            }


        # Try income
        income_match = self.INCOME_PATTERN.search(sms_text) or self.INCOME_PATTERN_AMOUNT_FIRST.search(sms_text)
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
