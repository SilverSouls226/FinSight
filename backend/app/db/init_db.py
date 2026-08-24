"""
app/db/init_db.py

Creates all tables on application startup.
Called once inside the FastAPI lifespan context manager.
"""
# Import all models here so SQLAlchemy's metadata is populated before create_all.
from app.db.base import Base, engine
import app.models.threat  # noqa: F401
import app.models.call    # noqa: F401


def init_db() -> None:
    """Create all tables if they do not already exist."""
    Base.metadata.create_all(bind=engine)
