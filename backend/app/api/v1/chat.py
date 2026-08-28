from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.schemas.financial import FinancialStateSnapshot
from app.services.brain.chat_reasoner import ChatReasoner

router = APIRouter()


class ChatRequest(BaseModel):
    question: str
    snapshot: FinancialStateSnapshot


class ChatResponse(BaseModel):
    answer: str


@router.post(
    "/chat/{user_id}",
    response_model=ChatResponse,
    summary="Ask the Twin Assistant a freeform question about a Financial State Snapshot",
    description=(
        "Answers an open-ended question using only the facts in the provided "
        "snapshot, via Groq (falls back to a small deterministic answer set "
        "if the API key is missing or the call fails)."
    ),
)
def chat_with_twin(user_id: str, request: ChatRequest) -> ChatResponse:
    if request.snapshot.user_id != user_id:
        raise HTTPException(status_code=400, detail="User ID mismatch between path and snapshot body.")

    reasoner = ChatReasoner()
    answer = reasoner.answer(request.question, request.snapshot)
    return ChatResponse(answer=answer)
