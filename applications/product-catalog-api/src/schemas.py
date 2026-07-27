"""
schemas.py — Pydantic request/response models (DTO layer).

Keeping schemas separate from ORM models follows the single-responsibility
principle: ORM models own persistence logic, schemas own serialization and
validation. This also prevents accidental exposure of internal DB fields.
"""

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


# ---------------------------------------------------------------------------
# Request schemas (input validation)
# ---------------------------------------------------------------------------

class ProductCreate(BaseModel):
    """Payload for POST /products."""

    name: str = Field(..., min_length=1, max_length=255, examples=["Wireless Keyboard"])
    description: str | None = Field(None, examples=["Compact tenkeyless mechanical keyboard"])
    price: Decimal = Field(..., gt=0, decimal_places=2, examples=[49.99])
    category: str | None = Field(None, max_length=100, examples=["Electronics"])
    stock: int = Field(0, ge=0, examples=[100])


class ProductUpdate(BaseModel):
    """Payload for PATCH /products/{id}. All fields are optional."""

    name: str | None = Field(None, min_length=1, max_length=255)
    description: str | None = None
    price: Decimal | None = Field(None, gt=0, decimal_places=2)
    category: str | None = Field(None, max_length=100)
    stock: int | None = Field(None, ge=0)


# ---------------------------------------------------------------------------
# Response schemas (output serialization)
# ---------------------------------------------------------------------------

class ProductResponse(BaseModel):
    """Full product representation returned from the API."""

    model_config = ConfigDict(from_attributes=True)  # replaces orm_mode=True

    id: uuid.UUID
    name: str
    description: str | None
    price: Decimal
    category: str | None
    stock: int
    created_at: datetime
    updated_at: datetime


class ProductListResponse(BaseModel):
    """Paginated list response."""

    items: list[ProductResponse]
    total: int
    page: int
    page_size: int


# ---------------------------------------------------------------------------
# Health / utility schemas
# ---------------------------------------------------------------------------

class HealthResponse(BaseModel):
    status: str
    db_connected: bool
    version: str
