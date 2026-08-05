# applications/product-catalog-api/src/tests/test_products.py
#
# Tests for CRUD endpoints: POST, GET (list + single), PATCH, DELETE /products.
#
# Design:
#   - Each test uses the in-memory SQLite DB from conftest.py
#   - Tests are independent (rollback after each via db_session fixture)
#   - Covers: happy paths, 404, pagination, partial update, validation errors

import pytest
from httpx import AsyncClient


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

VALID_PRODUCT = {
    "name": "Wireless Keyboard",
    "description": "Compact tenkeyless mechanical keyboard",
    "price": "49.99",
    "category": "Electronics",
    "stock": 100,
}


async def _create_product(client: AsyncClient, overrides: dict | None = None) -> dict:
    """Helper: POST a product and return the response JSON."""
    payload = {**VALID_PRODUCT, **(overrides or {})}
    response = await client.post("/products", json=payload)
    assert response.status_code == 201, f"Unexpected status: {response.text}"
    return response.json()


# ---------------------------------------------------------------------------
# POST /products
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_create_product_returns_201(client: AsyncClient):
    """Creating a valid product should return HTTP 201."""
    response = await client.post("/products", json=VALID_PRODUCT)
    assert response.status_code == 201


@pytest.mark.asyncio
async def test_create_product_response_schema(client: AsyncClient):
    """Created product must include all required fields with correct types."""
    product = await _create_product(client)

    assert "id" in product
    assert product["name"] == "Wireless Keyboard"
    assert product["price"] == "49.99"
    assert product["category"] == "Electronics"
    assert product["stock"] == 100
    assert "created_at" in product
    assert "updated_at" in product


@pytest.mark.asyncio
async def test_create_product_no_optional_fields(client: AsyncClient):
    """Product creation should succeed with only required fields (name + price)."""
    minimal = {"name": "Basic Widget", "price": "9.99"}
    response = await client.post("/products", json=minimal)
    assert response.status_code == 201
    body = response.json()
    assert body["stock"] == 0
    assert body["description"] is None
    assert body["category"] is None


@pytest.mark.asyncio
async def test_create_product_invalid_price_zero(client: AsyncClient):
    """Price must be > 0. Sending 0 should return HTTP 422."""
    payload = {**VALID_PRODUCT, "price": "0.00"}
    response = await client.post("/products", json=payload)
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_create_product_invalid_price_negative(client: AsyncClient):
    """Negative price must return HTTP 422."""
    payload = {**VALID_PRODUCT, "price": "-5.00"}
    response = await client.post("/products", json=payload)
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_create_product_empty_name_fails(client: AsyncClient):
    """Name cannot be empty (min_length=1). Should return HTTP 422."""
    payload = {**VALID_PRODUCT, "name": ""}
    response = await client.post("/products", json=payload)
    assert response.status_code == 422


# ---------------------------------------------------------------------------
# GET /products (list)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_list_products_empty(client: AsyncClient):
    """GET /products on empty DB returns empty items list with total=0."""
    response = await client.get("/products")
    assert response.status_code == 200
    body = response.json()
    assert body["items"] == []
    assert body["total"] == 0
    assert body["page"] == 1
    assert body["page_size"] == 20


@pytest.mark.asyncio
async def test_list_products_returns_created(client: AsyncClient):
    """Products created in this test should appear in the list."""
    await _create_product(client)
    response = await client.get("/products")
    assert response.status_code == 200
    body = response.json()
    assert body["total"] >= 1


@pytest.mark.asyncio
async def test_list_products_category_filter(client: AsyncClient):
    """Category filter should return only matching products."""
    await _create_product(client, {"name": "Laptop", "category": "Electronics"})
    await _create_product(client, {"name": "Desk", "category": "Furniture"})

    response = await client.get("/products?category=Furniture")
    assert response.status_code == 200
    body = response.json()
    # All returned items must be Furniture
    for item in body["items"]:
        assert item["category"] == "Furniture"


@pytest.mark.asyncio
async def test_list_products_pagination(client: AsyncClient):
    """page_size parameter must limit returned items."""
    for i in range(5):
        await _create_product(client, {"name": f"Product {i}", "price": "10.00"})

    response = await client.get("/products?page_size=2")
    assert response.status_code == 200
    body = response.json()
    assert len(body["items"]) <= 2
    assert body["page_size"] == 2


# ---------------------------------------------------------------------------
# GET /products/{id}
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_get_product_by_id(client: AsyncClient):
    """GET /products/{id} should return the specific product."""
    created = await _create_product(client)
    product_id = created["id"]

    response = await client.get(f"/products/{product_id}")
    assert response.status_code == 200
    body = response.json()
    assert body["id"] == product_id
    assert body["name"] == created["name"]


@pytest.mark.asyncio
async def test_get_product_not_found(client: AsyncClient):
    """GET /products/{non-existent-id} should return HTTP 404."""
    fake_id = "00000000-0000-0000-0000-000000000000"
    response = await client.get(f"/products/{fake_id}")
    assert response.status_code == 404
    assert "not found" in response.json()["detail"].lower()


# ---------------------------------------------------------------------------
# PATCH /products/{id}
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_update_product_name(client: AsyncClient):
    """PATCH /products/{id} should update only the provided fields."""
    created = await _create_product(client)
    product_id = created["id"]

    response = await client.patch(f"/products/{product_id}", json={"name": "Updated Name"})
    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "Updated Name"
    # Other fields unchanged
    assert body["price"] == created["price"]
    assert body["category"] == created["category"]


@pytest.mark.asyncio
async def test_update_product_stock(client: AsyncClient):
    """Stock update should persist correctly."""
    created = await _create_product(client)
    response = await client.patch(f"/products/{created['id']}", json={"stock": 999})
    assert response.status_code == 200
    assert response.json()["stock"] == 999


@pytest.mark.asyncio
async def test_update_product_not_found(client: AsyncClient):
    """PATCH on non-existent product should return HTTP 404."""
    fake_id = "00000000-0000-0000-0000-000000000000"
    response = await client.patch(f"/products/{fake_id}", json={"name": "X"})
    assert response.status_code == 404


# ---------------------------------------------------------------------------
# DELETE /products/{id}
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_delete_product_returns_204(client: AsyncClient):
    """DELETE /products/{id} should return HTTP 204 No Content."""
    created = await _create_product(client)
    response = await client.delete(f"/products/{created['id']}")
    assert response.status_code == 204


@pytest.mark.asyncio
async def test_delete_product_then_get_404(client: AsyncClient):
    """After deletion, GET should return 404."""
    created = await _create_product(client)
    product_id = created["id"]

    await client.delete(f"/products/{product_id}")
    response = await client.get(f"/products/{product_id}")
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_delete_product_not_found(client: AsyncClient):
    """DELETE on non-existent product should return HTTP 404."""
    fake_id = "00000000-0000-0000-0000-000000000000"
    response = await client.delete(f"/products/{fake_id}")
    assert response.status_code == 404


# ---------------------------------------------------------------------------
# Pydantic schema validation — ProductCreate
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_create_product_stock_negative_fails(client: AsyncClient):
    """stock must be >= 0. Negative stock returns 422."""
    payload = {**VALID_PRODUCT, "stock": -1}
    response = await client.post("/products", json=payload)
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_create_product_name_too_long_fails(client: AsyncClient):
    """name max_length=255. Longer name returns 422."""
    payload = {**VALID_PRODUCT, "name": "A" * 256}
    response = await client.post("/products", json=payload)
    assert response.status_code == 422
