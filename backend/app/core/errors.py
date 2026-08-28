"""
app/core/errors.py

Custom exception hierarchy and FastAPI exception handlers.
All error responses follow the frozen contract envelope:
    {"error": {"code": "...", "message": "..."}}
"""
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


# ── Domain exceptions ────────────────────────────────────────────────────────

class FinSentinelError(Exception):
    """Base class for all FinSentinel application errors."""
    code: str = "INTERNAL_ERROR"
    http_status: int = 500

    def __init__(self, message: str) -> None:
        self.message = message
        super().__init__(message)


class InvalidInputError(FinSentinelError):
    """Raised when a request carries invalid or missing input."""
    code = "INVALID_INPUT"
    http_status = 422


class NotFoundError(FinSentinelError):
    """Raised when a requested resource does not exist."""
    code = "NOT_FOUND"
    http_status = 404


class AnalysisFailedError(FinSentinelError):
    """
    Raised when the analysis engine (AI stub or real) fails to produce a result.
    Per the frozen contract, analysis failure is returned as an error — NOT a
    LOW-risk ThreatResult.
    """
    code = "ANALYSIS_FAILED"
    http_status = 502


class CallNotFoundError(NotFoundError):
    """Raised when a call_id does not exist in the database."""
    code = "CALL_NOT_FOUND"


# ── Response helper ──────────────────────────────────────────────────────────

def _error_body(code: str, message: str) -> dict:
    return {"error": {"code": code, "message": message}}


# ── FastAPI exception handlers ────────────────────────────────────────────────

def register_exception_handlers(app: FastAPI) -> None:
    """Attach all custom exception handlers to the FastAPI app."""

    @app.exception_handler(FinSentinelError)
    async def finsentinel_error_handler(
        request: Request, exc: FinSentinelError
    ) -> JSONResponse:
        return JSONResponse(
            status_code=exc.http_status,
            content=_error_body(exc.code, exc.message),
        )

    @app.exception_handler(404)
    async def not_found_handler(
        request: Request, exc: Exception
    ) -> JSONResponse:
        return JSONResponse(
            status_code=404,
            content=_error_body("NOT_FOUND", "The requested resource was not found."),
        )
