"""
tests/conftest.py

Shared pytest fixtures.
- Uses in-memory SQLite so tests never touch the real database.
- Patches the app's DB engine to point to the in-memory test engine.
- Overrides the get_db dependency so route handlers use the test session.
- All mock/seed data lives here — never in app startup code.
"""
import uuid
from datetime import datetime, timezone
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session

from app.api.deps import get_db
from app.db.base import Base
from app.main import app
from app.models.call import Call, CallEvent  # noqa: F401 — ensures tables registered
from app.models.threat import Threat  # noqa: F401 — ensures tables registered

from sqlalchemy.pool import StaticPool

# ── In-memory test engine ─────────────────────────────────────────────────────
#
# StaticPool ensures every call to connect() returns the SAME underlying
# connection — so create_all(), the test session, and the overridden app
# session all operate on the same in-memory SQLite database.

TEST_DATABASE_URL = "sqlite://"  # bare in-memory URL

test_engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)


# ── DB fixtures ───────────────────────────────────────────────────────────────

@pytest.fixture(autouse=True)
def reset_db():
    """
    Create all tables on the in-memory test engine before each test,
    then drop them after.  autouse=True means this runs for every test
    automatically — no need to request it explicitly.

    Tables are created here (not in the app lifespan) so that tests are
    fully isolated from the production SQLite file.
    """
    Base.metadata.create_all(bind=test_engine)
    yield
    Base.metadata.drop_all(bind=test_engine)


@pytest.fixture
def db() -> Session:
    """Yields a test database session bound to the in-memory test engine."""
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def client(db: Session) -> TestClient:
    """
    TestClient with:
    1. get_db dependency overridden → always yields the test-engine session.
    2. app.db.init_db.init_db patched → no-op so lifespan doesn't touch
       the production engine.

    The test DB is already set up by reset_db (autouse).
    """

    def override_get_db():
        try:
            yield db
        finally:
            pass  # Session lifecycle managed by the `db` fixture

    app.dependency_overrides[get_db] = override_get_db

    # Patch init_db so the FastAPI lifespan doesn't run create_all on the
    # production engine when TestClient starts the app.
    with patch("app.db.init_db.init_db", return_value=None):
        with TestClient(app, raise_server_exceptions=True) as c:
            yield c

    app.dependency_overrides.clear()


# ── Helper constants ──────────────────────────────────────────────────────────

DEVICE_A = "device-test-aaaabbbbcccc"
DEVICE_B = "device-test-xxxx1111yyyy"

HEADERS_A = {"X-Device-Id": DEVICE_A}
HEADERS_B = {"X-Device-Id": DEVICE_B}


# ── Seed fixtures (test-only — never called at app startup) ──────────────────

@pytest.fixture
def seed_threat(db: Session) -> Threat:
    """Insert one Threat row for DEVICE_A into the test DB."""
    row = Threat(
        id=f"thr_sms_{uuid.uuid4().hex[:8]}",
        device_id=DEVICE_A,
        source="SMS",
        risk_score=85,
        risk_level="HIGH",
        threat_type="Banking Scam",
        recommendation="Do not share your OTP.",
        analyzed_content="Your KYC has expired.",
        timestamp=datetime.now(timezone.utc),
    )
    row.indicators = ["Bank impersonation", "Urgency"]
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@pytest.fixture
def seed_active_call(db: Session) -> Call:
    """
    Insert one active Call + two sample CallEvents into the test DB.
    TEST-ONLY — the real application never seeds call data at startup.
    """
    call = Call(
        id="CA_test_active_001",
        status="IN_PROGRESS",
        scammer_number="+15550001111",
        victim_number="+15550002222",
        started_at=datetime.now(timezone.utc),
    )
    db.add(call)
    db.flush()

    e1 = CallEvent(
        call_id=call.id,
        seq=1,
        type="STATUS",
        timestamp=datetime.now(timezone.utc),
    )
    e2 = CallEvent(
        call_id=call.id,
        seq=2,
        type="TRANSCRIPT",
        timestamp=datetime.now(timezone.utc),
        speaker="SCAMMER",
        text="Hello, I'm calling from your bank.",
    )
    db.add_all([e1, e2])
    db.commit()
    db.refresh(call)
    return call


@pytest.fixture
def seed_completed_call(db: Session) -> tuple[Call, Threat]:
    """Insert a completed Call with a linked ThreatResult (test only)."""
    threat_row = Threat(
        id="thr_call_testfinal1",
        device_id=DEVICE_A,
        source="CALL",
        risk_score=97,
        risk_level="CRITICAL",
        threat_type="Banking Scam",
        recommendation="Do not share your OTP.",
        analyzed_content="Full call transcript.",
        timestamp=datetime.now(timezone.utc),
    )
    threat_row.indicators = ["Bank impersonation", "OTP request", "Urgency"]
    db.add(threat_row)
    db.flush()

    call = Call(
        id="CA_test_completed_001",
        status="COMPLETED",
        scammer_number="+15550001111",
        victim_number="+15550002222",
        started_at=datetime.now(timezone.utc),
        ended_at=datetime.now(timezone.utc),
        threat_id=threat_row.id,
    )
    db.add(call)
    db.commit()
    db.refresh(call)
    return call, threat_row
