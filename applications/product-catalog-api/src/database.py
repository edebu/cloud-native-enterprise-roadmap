"""
database.py — Async PostgreSQL connection management.

Configuration is driven entirely by environment variables so the same
image runs identically in local, dev, and prod environments.
"""

import os

from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

# ---------------------------------------------------------------------------
# Connection URL — assembled from individual env vars to avoid embedding
# credentials in connection strings or source code.
# ---------------------------------------------------------------------------
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "productdb")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASS = os.getenv("DB_PASS", "postgres")

DATABASE_URL = (
    f"postgresql+asyncpg://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

# ---------------------------------------------------------------------------
# Engine — pool_pre_ping keeps connections healthy across Cloud SQL proxy
# restarts and network blips.
# ---------------------------------------------------------------------------
engine = create_async_engine(
    DATABASE_URL,
    echo=False,        # Set to True for SQL query logging during debugging
    pool_pre_ping=True,
    pool_size=5,
    max_overflow=10,
)

AsyncSessionLocal = sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    """Shared declarative base for all ORM models."""
    pass


# ---------------------------------------------------------------------------
# Dependency — used by FastAPI route handlers via `Depends(get_db)`.
# ---------------------------------------------------------------------------
async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()
