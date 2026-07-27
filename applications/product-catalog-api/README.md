# Product Catalog API

Enterprise-grade RESTful API built with **FastAPI** and **PostgreSQL**, serving as the sample microservice for the [Cloud Native Enterprise Roadmap (CN-ER)](../../README.md).

This application is intentionally designed to grow across phases:

| Phase | What this app gains |
|---|---|
| **Phase 2 (PR 2.1)** | Core CRUD + DB connection (this PR) |
| **Phase 2 (PR 2.2)** | Multi-stage Docker build |
| **Phase 2 (PR 2.6)** | Kubernetes Deployment manifests |
| **Phase 3** | Helm Chart packaging + ArgoCD GitOps |
| **Phase 5** | Prometheus `/metrics` scraping + Grafana dashboard |

---

## Architecture

```
FastAPI App (uvicorn)
├── /health         → DB ping — used as K8s liveness/readiness probe
├── /metrics        → Prometheus exposition format (Phase 5)
├── /simulate-load  → CPU-bound loop for load testing (Phase 5)
└── /products       → CRUD (PostgreSQL via SQLAlchemy async)
```

---

## Local Development

### Prerequisites

- Python 3.12+
- PostgreSQL running locally (or via Docker)

### 1. Set up a virtual environment

```bash
cd applications/product-catalog-api
python -m venv .venv
source .venv/bin/activate        # Linux/macOS
.venv\Scripts\activate           # Windows PowerShell
pip install -r requirements.txt
```

### 2. Start a local PostgreSQL (Docker shortcut)

```bash
docker run -d \
  --name local-postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=productdb \
  -p 5432:5432 \
  postgres:16-alpine
```

### 3. Configure environment variables

```bash
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=productdb
export DB_USER=postgres
export DB_PASS=postgres
export APP_VERSION=0.1.0
```

### 4. Run the application

```bash
uvicorn src.main:app --reload --host 0.0.0.0 --port 8080
```

---

## ✅ Verification Checklist (PR 2.1)

Aşağıdaki adımlar bu PR'ın kavramsal ve teknik doğrulamasıdır.  
Her adımı çalıştırın ve beklenen çıktıyı gözlemleyin.

### Step 1 — Health endpoint

```bash
curl http://localhost:8080/health
```

**Beklenen çıktı:**
```json
{
  "status": "healthy",
  "db_connected": true,
  "version": "0.1.0"
}
```

---

### Step 2 — Create a product

```bash
curl -X POST http://localhost:8080/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Mechanical Keyboard",
    "description": "Compact tenkeyless mechanical keyboard",
    "price": 89.99,
    "category": "Electronics",
    "stock": 150
  }'
```

**Beklenen çıktı:** UUID atanmış bir `ProductResponse` JSON nesnesi.

---

### Step 3 — List products

```bash
curl "http://localhost:8080/products?category=Electronics&page=1&page_size=5"
```

**Beklenen çıktı:** `items` array'i, `total`, `page`, `page_size` alanları olan paginated response.

---

### Step 4 — Interactive docs

Tarayıcıda aç: **http://localhost:8080/docs**

Swagger UI açılıyor ve tüm endpoint'ler görünüyor olmalı.

---

### Step 5 — Metrics endpoint (Phase 5 hazırlığı)

```bash
curl http://localhost:8080/metrics
```

**Beklenen çıktı:** Prometheus text format — `http_requests_total`, `http_request_duration_seconds`, `http_active_requests` metriklerini içermeli.

---

## 🎯 Mülakat Sorusu

**S: FastAPI'de async/await neden önemli? Sync bir framework'ten farkı nedir?**

**C:** FastAPI, Python'un `asyncio` event loop'unu kullanır. Bir DB sorgusu veya HTTP isteği beklenirken event loop başka request'leri işlemeye devam edebilir. Sync (WSGI) bir framework'te ise her request bir thread'i blokladığından, yüksek concurrent request sayılarında thread pool tükenir ve latency artar. GKE'de aynı Pod kaynaklarıyla çok daha yüksek throughput elde edilir.

---

## File Structure

```
applications/product-catalog-api/
├── src/
│   ├── __init__.py     # Python package marker
│   ├── main.py         # FastAPI app, endpoints, middleware
│   ├── models.py       # SQLAlchemy ORM models
│   ├── schemas.py      # Pydantic request/response DTOs
│   └── database.py     # Async engine and session factory
├── requirements.txt    # Python dependencies (pinned to minor versions)
├── Dockerfile          # Multi-stage build (Phase 2, PR 2.2)
└── k8s/                # Kubernetes manifests (Phase 2, PR 2.6)
```
