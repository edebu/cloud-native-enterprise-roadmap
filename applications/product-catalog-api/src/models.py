"""
models.py — SQLAlchemy ORM models for the Product Catalog API.
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Numeric, String, Text, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column

from .database import Base


class Product(Base):
    """
    Represents a product in the catalog.

    Fields
    ------
    id          : UUID primary key — avoids sequential ID guessing.
    name        : Product display name (max 255 chars, required).
    description : Optional long-form description.
    price       : NUMERIC(10, 2) — avoids floating-point rounding errors
                  for monetary values (a common production gotcha).
    category    : Free-form category string for basic filtering.
    stock       : Available inventory count.
    created_at  : Server-side timestamp set on INSERT.
    updated_at  : Server-side timestamp updated on every UPDATE.
    """

    __tablename__ = "products"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    price: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    category: Mapped[str | None] = mapped_column(String(100), nullable=True, index=True)
    stock: Mapped[int] = mapped_column(default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
