"""
app/services/analysis.py

AnalysisService — the integration seam between the backend and Skandan's
AI pipeline (Groq/Whisper-based scam detection).

Architecture:

    API route
      ↓
    AnalysisService.analyze()          ← backend always calls this
      ↓
    AnalysisProvider.analyze()         ← swappable implementation
      ↓
    ThreatResult                       ← frozen contract §1 shape

Skandan's integration path:
    1. Implement AnalysisProvider (the Protocol below).
    2. Pass your provider to AnalysisService(provider=your_provider).
    3. The backend wires it in — you do not need to import any ORM or DB code.

Per contract §5.2: analysis failure MUST raise AnalysisFailedError.
NEVER return a ThreatResult with risk_level=LOW when analysis did not happen.

DO NOT import Groq or Whisper in this file until Skandan is ready.
"""
import re
import uuid
from datetime import datetime, timezone
from typing import Protocol, runtime_checkable

from app.core.errors import AnalysisFailedError
from app.schemas.common import RiskLevel, Source
from app.schemas.threat import ThreatResult


# ── AnalysisProvider Protocol ─────────────────────────────────────────────────
# This is the ONLY interface the backend cares about.
# Skandan: implement this Protocol in your AI module.
# You do NOT need to inherit from it — Python structural subtyping handles it.

@runtime_checkable
class AnalysisProvider(Protocol):
    """
    Protocol (interface) that any analysis implementation must satisfy.

    Implementation contract:
      - analyze() MUST return a ThreatResult on success.
      - analyze() MUST raise AnalysisFailedError on any failure.
      - analyze() MUST NEVER return a ThreatResult with risk_level=LOW
        when analysis did not actually run.
      - The returned ThreatResult MUST have all fields from contract §1.

    Skandan's AI provider example:
        class GroqAnalysisProvider:
            def analyze(self, source, content, metadata) -> ThreatResult:
                # call Groq API, run STT, score, return ThreatResult
                ...

        # Wire it into the backend:
        from app.services.analysis import AnalysisService
        ai_service = AnalysisService(provider=GroqAnalysisProvider())
    """

    def analyze(
        self,
        source: Source,
        content: str,
        metadata: dict,
    ) -> ThreatResult:
        ...


# ── Keyword heuristics (stub — replaced by Skandan's provider) ───────────────

_BANKING_SCAM_PATTERNS = [
    r"\botp\b",
    r"\bverif(y|ication)\b",
    r"\bkyc\b",
    r"\baccount.*(suspend|block|freez)",
    r"\bbank\b",
    r"\bcredit.card\b",
    r"\bdebit.card\b",
    r"\burgent\b",
    r"\bimmediately\b",
    r"\blast.chance\b",
]

_PHISHING_PATTERNS = [
    r"http[s]?://(?!(?:www\.)?(?:google|microsoft|apple|amazon)\b)\S+",
    r"\bclick.here\b",
    r"\bsecure.your.account\b",
    r"\blogin.to.confirm\b",
    r"\bverify.your.identity\b",
    r"\bpassword\b",
]

_QR_MALICIOUS_PATTERNS = [
    r"http[s]?://\S+",   # Any URL in a QR is suspicious unless whitelisted
]


def _count_matches(text: str, patterns: list[str]) -> list[str]:
    """Return the patterns that matched (for scoring; not shown to users)."""
    text_lower = text.lower()
    return [p for p in patterns if re.search(p, text_lower)]


def _derive_risk(score: int) -> RiskLevel:
    if score >= 80:
        return RiskLevel.CRITICAL
    if score >= 55:
        return RiskLevel.HIGH
    if score >= 30:
        return RiskLevel.MEDIUM
    return RiskLevel.LOW


def _make_id(source: Source) -> str:
    return f"thr_{source.value.lower()}_{uuid.uuid4().hex[:8]}"


# ── Stub provider ─────────────────────────────────────────────────────────────

class StubAnalysisProvider:
    """
    Keyword-based stub that satisfies the AnalysisProvider Protocol.

    Used in development and testing when Skandan's real AI is not available.
    NEVER returns a fake-safe LOW result for a call — raises AnalysisFailedError
    if called with source=CALL (the real path is Skandan's AI, not this stub).

    To replace: implement AnalysisProvider and pass it to AnalysisService().
    """

    def analyze(
        self,
        source: Source,
        content: str,
        metadata: dict,
    ) -> ThreatResult:
        indicators: list[str] = []
        base_score = 0

        if source == Source.SMS:
            banking_hits = _count_matches(content, _BANKING_SCAM_PATTERNS)
            phishing_hits = _count_matches(content, _PHISHING_PATTERNS)

            if banking_hits:
                indicators.append(
                    "Bank impersonation" if "bank" in content.lower() else "Financial urgency"
                )
            if any("otp" in h for h in banking_hits):
                indicators.append("OTP request")
            if any(k in h for h in banking_hits for k in ("urgency", "urgent", "immediately")):
                indicators.append("Urgency")
            if any("kyc" in h for h in banking_hits):
                indicators.append("KYC verification request")
            if phishing_hits:
                indicators.append("Suspicious URL")

            base_score = min(100, (len(banking_hits) * 15) + (len(phishing_hits) * 20))
            threat_type = (
                "Banking Scam" if banking_hits
                else ("Phishing" if phishing_hits else "Suspicious Message")
            )
            recommendation = (
                "Do not share your OTP or personal details. Contact your bank directly."
                if "OTP request" in indicators
                else "Do not click links from unknown senders."
            )

        elif source == Source.QR:
            url_hits = _count_matches(content, _QR_MALICIOUS_PATTERNS)
            if url_hits:
                indicators.append("Embedded URL")
                if not re.search(r"https://", content):
                    indicators.append("Non-HTTPS URL")
                    base_score = 65
                else:
                    base_score = 30
            threat_type = "Malicious QR Code" if base_score > 30 else "QR Code"
            recommendation = "Verify the destination URL before visiting."

        elif source == Source.LINK:
            phishing_hits = _count_matches(content, _PHISHING_PATTERNS)
            indicators = ["Suspicious URL structure"] if phishing_hits else []
            base_score = min(100, len(phishing_hits) * 25)
            threat_type = "Phishing Link" if base_score > 0 else "URL"
            recommendation = "Do not visit this link. Report to your security team."

        elif source == Source.CALL:
            # CALL analysis belongs to Skandan's AI pipeline.
            # The stub cannot meaningfully analyse call audio.
            # Per contract §5.2: raise an error — never fake LOW.
            raise AnalysisFailedError(
                "CALL source requires the AI analysis pipeline (not the stub provider). "
                "Use finalize_call() after Skandan's AI produces a ThreatResult."
            )

        else:
            raise AnalysisFailedError(f"Unknown source type: {source}")

        # Deduplicate while preserving insertion order
        indicators = list(dict.fromkeys(indicators))

        if not indicators and base_score == 0:
            base_score = 5
            threat_type = "No Threat Detected"
            recommendation = "No immediate action required."

        return ThreatResult(
            id=_make_id(source),
            source=source,
            risk_score=base_score,
            risk_level=_derive_risk(base_score),
            threat_type=threat_type,
            indicators=indicators,
            recommendation=recommendation,
            timestamp=datetime.now(timezone.utc),
            analyzed_content=content,
        )


# ── AnalysisService — the public boundary ────────────────────────────────────

class AnalysisService:
    """
    Public analysis boundary.  Routes always call this — never the provider directly.

    The provider is injected so the real AI can be swapped in without touching
    any route or test code:

        from app.services.analysis import AnalysisService
        from my_ai_module import GroqAnalysisProvider
        analysis_service = AnalysisService(provider=GroqAnalysisProvider())

    Default provider is StubAnalysisProvider (keyword heuristics).
    """

    def __init__(self, provider: AnalysisProvider | None = None) -> None:
        self._provider: AnalysisProvider = provider or StubAnalysisProvider()

    def analyze(
        self,
        source: Source,
        content: str,
        metadata: dict,
    ) -> ThreatResult:
        """
        Analyse content and return a ThreatResult.

        Raises:
            AnalysisFailedError: on any failure. Per contract §5.2, NEVER
                                 return a LOW-risk result on failure.
        """
        try:
            return self._provider.analyze(source, content, metadata)
        except AnalysisFailedError:
            raise
        except Exception as exc:
            raise AnalysisFailedError(
                f"Analysis engine encountered an unexpected error: {exc}"
            ) from exc


# Shared singleton — import this in the API layer.
# To swap in Skandan's real AI: reassign this or use dependency injection.
analysis_service = AnalysisService()
