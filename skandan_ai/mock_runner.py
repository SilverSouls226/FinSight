import asyncio
import json
from datetime import datetime
from .models import TranscriptEvent
from .pipeline import AIPipeline

async def simulated_stt_stream():
    """
    Simulates a WebSocket or STT engine yielding transcript segments.
    In the final state, this async generator would read from a Twilio WS stream
    and pipe it through `faster-whisper`.
    """
    mock_events = [
        {"speaker": "Caller", "text": "Hello, is this Sameer?", "delay": 1.0},
        {"speaker": "Sameer", "text": "Yes, speaking.", "delay": 1.5},
        {"speaker": "Caller", "text": "I'm calling from your bank.", "delay": 1.5},
        {"speaker": "Caller", "text": "We have detected suspicious activity on your account.", "delay": 2.0},
        {"speaker": "Sameer", "text": "Oh really? What happened?", "delay": 1.5},
        {"speaker": "Caller", "text": "Yes, to verify your identity and freeze the account...", "delay": 2.0},
        {"speaker": "Caller", "text": "Please tell me the OTP sent to your phone urgently.", "delay": 2.0},
        {"speaker": "Sameer", "text": "Wait, I shouldn't share my OTP.", "delay": 2.0}
    ]

    for item in mock_events:
        await asyncio.sleep(item["delay"])
        yield TranscriptEvent(
            call_id="mock-call-123",
            speaker=item["speaker"],
            text=item["text"],
            is_final=True
        )

async def process_stream():
    pipeline = AIPipeline(call_id="mock-call-123")
    print("Starting simulated call stream...\n")
    print("Note: Set GROQ_API_KEY environment variable for real LLM output, otherwise uses mock LLM.\n")
    
    async for event in simulated_stt_stream():
        print(f"[{event.timestamp.time()}] {event.speaker}: {event.text}")
        print("--- AI Analysis Update ---")
        
        # In a real WS server, this process would be triggered on incoming chunks
        # and the result JSON would be `await websocket.send(json_result)`
        json_result = pipeline.process_transcript_event(event)
        print(json_result)
        print("==================================================\n")

if __name__ == "__main__":
    asyncio.run(process_stream())
