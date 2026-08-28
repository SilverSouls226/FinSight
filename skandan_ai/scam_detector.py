import os
import json
from groq import Groq
from typing import Dict, Any, List
from .models import TranscriptEvent

class ScamDetector:
    def __init__(self):
        # Requires GROQ_API_KEY environment variable
        self.client = Groq(api_key=os.environ.get("GROQ_API_KEY", "mock_key"))
        self.conversation_history: List[str] = []
        
    def add_transcript(self, event: TranscriptEvent):
        self.conversation_history.append(f"{event.speaker}: {event.text}")
        
    def analyze_conversation(self) -> Dict[str, Any]:
        """
        Calls Groq LLM to analyze the conversation so far.
        Returns a dict with semantic threat analysis.
        """
        if not self.conversation_history:
            return {
                "threat_type": "NONE",
                "recommendation": "No conversation yet.",
                "explanation": "Waiting for audio."
            }

        # If testing without an API key, return a mock response
        if self.client.api_key == "mock_key":
            return {
                "threat_type": "MOCK_SCAM",
                "recommendation": "Do not share personal info.",
                "explanation": "Detected suspicious keywords in mock mode."
            }
            
        prompt = f"""
You are a financial security AI analyzing a phone call transcript for scams.
Here is the conversation so far:
{chr(10).join(self.conversation_history)}

Analyze the conversation and return a JSON object with the following keys:
- "threat_type": A short uppercase string like "OTP_SCAM", "BANK_IMPERSONATION", "SAFE", etc.
- "recommendation": A short sentence advising the victim what to do right now.
- "explanation": Evidence-backed explanation of why this was flagged.

Return ONLY valid JSON. No markdown formatting, backticks, or extra text.
"""
        
        try:
            chat_completion = self.client.chat.completions.create(
                messages=[
                    {
                        "role": "system",
                        "content": "You are a specialized AI designed to output raw JSON based on financial scam analysis."
                    },
                    {
                        "role": "user",
                        "content": prompt,
                    }
                ],
                model="llama3-8b-8192",
                temperature=0.0,
            )
            
            result_text = chat_completion.choices[0].message.content.strip()
            # Handle potential markdown code block wrapping
            if result_text.startswith("```json"):
                result_text = result_text[7:-3].strip()
            elif result_text.startswith("```"):
                result_text = result_text[3:-3].strip()
                
            return json.loads(result_text)
        except Exception as e:
            return {
                "threat_type": "ERROR",
                "recommendation": "Error analyzing conversation.",
                "explanation": str(e)
            }
