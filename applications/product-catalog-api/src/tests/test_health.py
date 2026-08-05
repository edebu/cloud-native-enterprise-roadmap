# applications/product-catalog-api/src/tests/test_health.py
#
# Tests for GET /health endpoint.
#
# The health endpoint checks DB connectivity. In tests, the DB session is
# the SQLite in-memory session from conftest.py — so it always responds healthy.

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health_returns_200(client: AsyncClient):
    """GET /health should return 200 when DB is reachable."""
    response = await client.get("/health")
    assert response.status_code == 200


@pytest.mark.asyncio
async def test_health_response_schema(client: AsyncClient):
    """Response body must match HealthResponse schema."""
    response = await client.get("/health")
    body = response.json()

    assert body["status"] == "healthy"
    assert body["db_connected"] is True
    assert "version" in body
    assert isinstance(body["version"], str)


@pytest.mark.asyncio
async def test_health_content_type(client: AsyncClient):
    """Response Content-Type must be application/json."""
    response = await client.get("/health")
    assert "application/json" in response.headers["content-type"]
