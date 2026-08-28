from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import List, Optional

from app.models.event import NormalizedFinancialEvent
from app.services.normalizer import NormalizationService

app = FastAPI(
    title="FinSentinel Ingestion API (Member 1)",
    description="Turns messy financial inputs into strictly validated JSON contracts.",
    version="1.0.0"
)

# Global service instance
normalizer = NormalizationService()

class IngestRequest(BaseModel):
    user_id: str
    source: str = Field(..., description="'sms' or 'receipt'")
    raw_text: str = Field(..., description="The raw SMS text or OCR receipt text")

@app.post("/ingest", response_model=NormalizedFinancialEvent)
async def ingest_financial_data(request: IngestRequest):
    """
    Accepts raw text (SMS or Receipt), parses it, checks for duplicates,
    and returns a strictly validated Normalized Financial Event.
    """
    if request.source not in ["sms", "receipt"]:
        raise HTTPException(status_code=400, detail="Invalid source. Must be 'sms' or 'receipt'.")
        
    event = normalizer.process_raw_input(request.user_id, request.raw_text, request.source)
    
    if not event:
        raise HTTPException(status_code=422, detail="Could not parse data or duplicate detected.")
        
    return event

@app.post("/ingest/batch", response_model=List[NormalizedFinancialEvent])
async def ingest_batch(requests: List[IngestRequest]):
    """
    Batch endpoint for processing multiple SMS/receipts at once.
    """
    results = []
    for req in requests:
        event = normalizer.process_raw_input(req.user_id, req.raw_text, req.source)
        if event:
            results.append(event)
    return results

@app.get("/health")
async def health_check():
    return {"status": "ok", "module": "member1_ingestion"}
