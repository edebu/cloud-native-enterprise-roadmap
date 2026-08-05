# applications/product-catalog-api/src/tests/conftest.py
#
# Pytest fixtures shared across all test modules.
#
# Strategy: SQLite in-memory database
#   - No real PostgreSQL needed in CI
#   - aiosqlite driver used instead of asyncpg
#   - DB schema created fresh per test session
#   - Each test gets a clean DB via transaction rollback

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from src.database import Base, get_db
from src.main import app

# ---------------------------------------------------------------------------
# In-memory SQLite engine for tests
# SQLite doesn't support asyncpg — use aiosqlite instead.
# check_same_thread=False: needed for SQLite when multiple async tasks touch it.
# StaticPool: shares the same in-memory DB across all connections in one session.
# ---------------------------------------------------------------------------
TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

test_engine = create_async_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)

TestSessionLocal = async_sessionmaker(
    bind=test_engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


@pytest_asyncio.fixture(scope="session", autouse=True)
async def create_tables():
    """Create all DB tables once per test session."""
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest_asyncio.fixture
async def db_session():
    """Yields a clean DB session that is rolled back after each test."""
    async with TestSessionLocal() as session:
        yield session
        await session.rollback()


@pytest_asyncio.fixture
async def client(db_session: AsyncSession):
    """
    AsyncClient with the FastAPI app wired to the test DB.
    Overrides the get_db dependency so no real PostgreSQL is needed.
    """

    async def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db

    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://testserver",
    ) as ac:
        yield ac

    app.dependency_overrides.clear()
