"""
app/services/analysis.py

AnalysisService — the integration seam between the backend and Sub-team A's
AI pipeline (Skandan's Groq/Whisper analysis).

Day 1: Keyword-based stub that returns a plausible ThreatResult.
       The interface is frozen so Skandan can replace the implementation
       without touching any other backend file.

Integration contract for Sub-team A:
    Input:  source (Source), content (str), metadata (dict)
    Output: ThreatResult (from app.schemas.threat)
    Error:  raises AnalysisFailedError — never returns a fake LOW result.

DO NOT implement real AI here. DO NOT import Groq or Whisper here on Day 1.
"""
import re
import uuid
from datetime import datetime, timezone

from app.core.errors import AnalysisFailedError
from app.schemas.common import RiskLevel, Source
from app.schemas.threat import ThreatResult

# ── Keyword heuristics (stub only — replaced by Groq/LLM in Day 2+) ──────────

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
    """Return the human-readable names of matched patterns."""
    text_lower = text.lower()
    matched = []
    for p in patterns:
        if re.search(p, text_lower):
            matched.append(p)
    return matched


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


# ── Public interface ──────────────────────────────────────────────────────────

class AnalysisService:
    """
    Stub analysis engine.

    Replace the body of `analyze()` with a call to Skandan's real AI service.
    The method signature and return type must NOT change.
    """

    def analyze(
        self,
        source: Source,
        content: str,
        metadata: dict,
    ) -> ThreatResult:
        """
        Analyse content and return a ThreatResult.

        Raises:
            AnalysisFailedError: if analysis cannot produce a result.
                                 Do NOT return a LOW-risk result on failure.
        """
        try:
            return self._stub_analyze(source, content, metadata)
        except AnalysisFailedError:
            raise
        except Exception as exc:
            raise AnalysisFailedError(
                f"Analysis engine encountered an unexpected error: {exc}"
            ) from exc

    # ── Stub implementation (keyword-based) ──────────────────────────────

    def _stub_analyze(
        self, source: Source, content: str, metadata: dict
    ) -> ThreatResult:
        indicators: list[str] = []
        base_score = 0

        if source == Source.SMS:
            banking_hits = _count_matches(content, _BANKING_SCAM_PATTERNS)
            phishing_hits = _count_matches(content, _PHISHING_PATTERNS)

            if banking_hits:
                indicators.append("Bank impersonation" if "bank" in content.lower() else "Financial urgency")
            if any("otp" in h for h in banking_hits):
                indicators.append("OTP request")
            if any("urgency" in h or "urgent" in h or "immediately" in h for h in banking_hits):
                indicators.append("Urgency")
            if any("kyc" in h for h in banking_hits):
                indicators.append("KYC verification request")
            if phishing_hits:
                indicators.append("Suspicious URL")

            base_score = min(100, (len(banking_hits) * 15) + (len(phishing_hits) * 20))
            threat_type = "Banking Scam" if banking_hits else ("Phishing" if phishing_hits else "Suspicious Message")
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
            # CALL analysis is driven by the AI pipeline (Skandan).
            # This stub is only used if the call analysis pathway bypasses
            # the real AI service (e.g., in integration tests).
            base_score = 50
            indicators = ["Call analysis stub"]
            threat_type = "Suspicious Call"
            recommendation = "Hang up and call your bank on their official number."

        else:
            raise AnalysisFailedError(f"Unknown source type: {source}")

        # Deduplicate indicators
        indicators = list(dict.fromkeys(indicators))

        if not indicators and base_score == 0:
            base_score = 5
            threat_type = "No Threat Detected"
            recommendation = "No immediate action required."

        risk_level = _derive_risk(base_score)

        return ThreatResult(
            id=_make_id(source),
            source=source,
            risk_score=base_score,
            risk_level=risk_level,
            threat_type=threat_type,
            indicators=indicators,
            recommendation=recommendation,
            timestamp=datetime.now(timezone.utc),
            analyzed_content=content,
        )


# Shared singleton — import this in the API layer.
analysis_service = AnalysisService()
