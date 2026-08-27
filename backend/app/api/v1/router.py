"""
app/api/v1/router.py

Mounts all v1 sub-routers under the /api prefix.
"""
from fastapi import APIRouter

from app.api.v1 import analyze, calls, threats
from app.core.config import settings

api_router = APIRouter(prefix="/api")

api_router.include_router(analyze.router, tags=["Analysis"])
api_router.include_router(threats.router, tags=["Threats"])
api_router.include_router(calls.router, tags=["Calls"])

if settings.APP_ENV == "development":
    from app.api.v1 import devtools
    api_router.include_router(devtools.router)
