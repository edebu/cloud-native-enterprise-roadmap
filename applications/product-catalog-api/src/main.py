"""
main.py — Product Catalog API entry point.

Design decisions documented in:
  docs/decision-records/002-multi-stage-docker-build.md (Phase 2, PR 2.2)

Endpoints
---------
GET  /health                   — Liveness + readiness probe
GET  /metrics                  — Prometheus metrics (Phase 5 observability hook)
POST /simulate-load            — CPU-bound load simulation (Phase 5 load testing hook)

GET    /products               — List products (pagination)
POST   /products               — Create product
GET    /products/{id}          — Get single product
PATCH  /products/{id}          — Update product
DELETE /products/{id}          — Delete product
"""

import os
import time
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Query, status
from prometheus_client import Counter, Gauge, Histogram, generate_latest, CONTENT_TYPE_LATEST
from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.responses import Response

from .database import Base, engine, get_db
from .models import Product
from .schemas import (
    HealthResponse,
    ProductCreate,
    ProductListResponse,
    ProductResponse,
    ProductUpdate,
)

# ---------------------------------------------------------------------------
# App metadata
# ---------------------------------------------------------------------------
APP_VERSION = os.getenv("APP_VERSION", "0.1.0")

# ---------------------------------------------------------------------------
# Prometheus metrics (Phase 5 hook — already defined here so the app emits
# useful signals from day one without instrumentation refactors later).
# ---------------------------------------------------------------------------
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP request count",
    ["method", "endpoint", "status_code"],
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency",
    ["method", "endpoint"],
)
ACTIVE_REQUESTS = Gauge(
    "http_active_requests",
    "Number of active HTTP requests",
)
DB_POOL_SIZE = Gauge(
    "db_pool_size",
    "SQLAlchemy connection pool size",
)


# ---------------------------------------------------------------------------
# Lifespan — creates DB tables on startup (idempotent via checkfirst=True).
# In production use Alembic migrations instead.
# ---------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all, checkfirst=True)
    DB_POOL_SIZE.set(engine.pool.size())
    yield
    await engine.dispose()


app = FastAPI(
    title="Product Catalog API",
    description=(
        "Enterprise-grade Product Catalog API built with FastAPI and PostgreSQL. "
        "Part of the Cloud Native Enterprise Roadmap (CN-ER) project."
    ),
    version=APP_VERSION,
    lifespan=lifespan,
)


# ---------------------------------------------------------------------------
# Middleware — simple request instrumentation
# ---------------------------------------------------------------------------
@app.middleware("http")
async def metrics_middleware(request, call_next):
    ACTIVE_REQUESTS.inc()
    start = time.perf_counter()
    response = await call_next(request)
    duration = time.perf_counter() - start
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.url.path,
        status_code=response.status_code,
    ).inc()
    REQUEST_LATENCY.labels(
        method=request.method,
        endpoint=request.url.path,
    ).observe(duration)
    ACTIVE_REQUESTS.dec()
    return response


# ---------------------------------------------------------------------------
# Utility & observability endpoints
# ---------------------------------------------------------------------------

@app.get("/health", response_model=HealthResponse, tags=["Observability"])
async def health_check(db: AsyncSession = Depends(get_db)):
    """
    Liveness + readiness probe.

    Returns 200 when the application is running and can reach the database.
    Returns 503 when the database is unreachable (Kubernetes will restart the pod).
    """
    db_ok = False
    try:
        await db.execute(text("SELECT 1"))
        db_ok = True
    except Exception:
        pass

    if not db_ok:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connection failed",
        )

    return HealthResponse(status="healthy", db_connected=db_ok, version=APP_VERSION)


@app.get("/metrics", tags=["Observability"])
async def prometheus_metrics():
    """
    Prometheus metrics endpoint.

    Scraped by Prometheus every 15s in Phase 5.
    Returns metrics in the Prometheus text exposition format.
    """
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.post("/simulate-load", tags=["Observability"])
async def simulate_load(duration_seconds: int = Query(default=5, ge=1, le=60)):
    """
    CPU-bound load simulator for Phase 5 load testing with k6/Locust.

    Runs a tight loop for `duration_seconds` and returns the iteration count.
    This lets you trigger measurable CPU spikes visible in Grafana dashboards.
    """
    deadline = time.perf_counter() + duration_seconds
    iterations = 0
    while time.perf_counter() < deadline:
        iterations += 1
    return {"iterations": iterations, "duration_seconds": duration_seconds}


# ---------------------------------------------------------------------------
# Product CRUD endpoints
# ---------------------------------------------------------------------------

@app.post("/products", response_model=ProductResponse, status_code=status.HTTP_201_CREATED, tags=["Products"])
async def create_product(payload: ProductCreate, db: AsyncSession = Depends(get_db)):
    """Create a new product in the catalog."""
    product = Product(**payload.model_dump())
    db.add(product)
    await db.commit()
    await db.refresh(product)
    return product


@app.get("/products", response_model=ProductListResponse, tags=["Products"])
async def list_products(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    category: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
):
    """
    List products with optional category filter and pagination.

    Example: GET /products?category=Electronics&page=1&page_size=10
    """
    offset = (page - 1) * page_size

    query = select(Product)
    count_query = select(func.count()).select_from(Product)

    if category:
        query = query.where(Product.category == category)
        count_query = count_query.where(Product.category == category)

    total_result = await db.execute(count_query)
    total = total_result.scalar_one()

    result = await db.execute(query.offset(offset).limit(page_size).order_by(Product.created_at.desc()))
    products = result.scalars().all()

    return ProductListResponse(items=products, total=total, page=page, page_size=page_size)


@app.get("/products/{product_id}", response_model=ProductResponse, tags=["Products"])
async def get_product(product_id: str, db: AsyncSession = Depends(get_db)):
    """Fetch a single product by UUID."""
    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    return product


@app.patch("/products/{product_id}", response_model=ProductResponse, tags=["Products"])
async def update_product(product_id: str, payload: ProductUpdate, db: AsyncSession = Depends(get_db)):
    """Partially update a product. Only provided fields are changed."""
    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    update_data = payload.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(product, field, value)

    await db.commit()
    await db.refresh(product)
    return product


@app.delete("/products/{product_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Products"])
async def delete_product(product_id: str, db: AsyncSession = Depends(get_db)):
    """Delete a product from the catalog."""
    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    await db.delete(product)
    await db.commit()
