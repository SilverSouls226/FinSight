"""
app/main.py

FastAPI application factory.
- DB is initialized on startup via lifespan context manager.
- CORS is wide-open (hackathon — tighten for production).
- Swagger UI available at /docs.
- ReDoc available at /redoc.
- Health check at /health.
"""
from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.errors import register_exception_handlers
from app.db.init_db import init_db


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Run startup/shutdown logic."""
    # Startup: create DB tables if they don't exist.
    init_db()
    yield
    # Shutdown: nothing to clean up for SQLite.


app = FastAPI(
    title="FinSentinel API",
    description=(
        "AI-Powered Real-Time Financial Scam Interceptor — Backend API\n\n"
        "All endpoints are defined in the frozen **Backend Contract v1.0**. "
        "Do not modify endpoint names, field names, or enum values without a team contract update."
    ),
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# ── CORS ──────────────────────────────────────────────────────────────────────
# Wide-open for hackathon — Flutter emulator, web console, and judges all need access.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Exception handlers ────────────────────────────────────────────────────────
register_exception_handlers(app)

# ── Routes ────────────────────────────────────────────────────────────────────
app.include_router(api_router)


# ── Health check ──────────────────────────────────────────────────────────────
@app.get("/health", tags=["Health"], summary="Health check")
def health() -> dict:
    return {"status": "ok", "service": "finsentinel-backend", "env": settings.APP_ENV}
