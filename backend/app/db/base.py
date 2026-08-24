"""
app/db/base.py

SQLAlchemy engine, session factory, and declarative Base.
All ORM models must inherit from Base defined here.
"""
from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.core.config import settings

engine = create_engine(
    settings.DATABASE_URL,
    # Required for SQLite when used with multi-threaded FastAPI workers.
    connect_args={"check_same_thread": False}
    if settings.DATABASE_URL.startswith("sqlite")
    else {},
    echo=settings.DEBUG,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    """Shared declarative base — import and subclass in every ORM model."""
    pass
