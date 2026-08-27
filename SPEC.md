# FIN SENTINEL - Skandan AI Subsystem

## Goal
Build the AI pipeline for real-time financial scam interception.
Input: Audio chunks from Twilio (mocked initially).
Output: Standardized JSON ThreatResult.

## Requirements
- **Latency**: 1 second max for STT and incremental updates.
- **Independence**: Develop using mock audio streams first.
- **Output Mode**: Structure assuming WebSockets final state, but verify via console first.
- **Scam Detection**: Hybrid (Deterministic + LLM via Groq).

## Schema
`TranscriptEvent`: { call_id, speaker, text, timestamp, is_final }
`ThreatResult`: { source, risk_score, risk_level, threat_type, indicators, recommendation, call_id, timestamp }

## Tech Stack
- STT: Local or fast API streaming (target <1s)
- LLM: Groq API
- Python, async pipeline (WebSockets readiness)
