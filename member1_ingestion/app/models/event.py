from pydantic import BaseModel, Field
from typing import Literal
from datetime import datetime

class NormalizedFinancialEvent(BaseModel):
    """
    The exact API contract agreed upon with the team.
    DO NOT change these fields.
    """
    event_id: str = Field(..., description="Unique identifier for the event")
    user_id: str = Field(..., description="Identifier for the user")
    timestamp: datetime = Field(..., description="ISO 8601 timestamp of the event")
    source: Literal["sms", "receipt", "bank_api", "user_input"] = Field(..., description="Source of the data")
    type: Literal["income", "expense", "bill_due"] = Field(..., description="Type of financial event")
    amount: float = Field(..., description="Absolute monetary amount")
    currency: str = Field(..., description="3-letter currency code (e.g., USD, INR)")
    vendor: str = Field(..., description="Name of the vendor, sender, or receiver")
    confidence_score: float = Field(..., ge=0.0, le=1.0, description="Confidence in the extracted data (0.0 to 1.0)")
    is_recurring: bool = Field(..., description="Whether this event is identified as recurring")

    class Config:
        json_schema_extra = {
            "example": {
                "event_id": "evt_987654321",
                "user_id": "usr_123",
                "timestamp": "2026-08-28T10:00:00Z",
                "source": "sms",
                "type": "expense",
                "amount": 45.50,
                "currency": "USD",
                "vendor": "Uber Eats",
                "confidence_score": 0.95,
                "is_recurring": False
            }
        }
