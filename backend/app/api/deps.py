"""
app/api/deps.py

FastAPI dependency functions shared by all route modules.
Import these via Depends() in route functions.
"""
from typing import Generator

from fastapi import Header, HTTPException
from sqlalchemy.orm import Session

from app.db.base import SessionLocal


def get_db() -> Generator[Session, None, None]:
    """
    Yields a SQLAlchemy database session per request.
    Session is always closed after the request completes.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_device_id(x_device_id: str = Header(..., alias="X-Device-Id")) -> str:
    """
    Extracts the X-Device-Id header from the request.
    Returns 422 if the header is missing or blank.
    The client (Flutter app) generates a persistent UUID as its device identity.
    No authentication is required — this is scoped identity only.
    """
    device_id = x_device_id.strip()
    if not device_id:
        raise HTTPException(status_code=422, detail="X-Device-Id header must not be blank.")
    return device_id
