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

---

## Docker (Phase 2, PR 2.2)

### Build

```bash
# Run from the applications/product-catalog-api directory
docker build -t product-catalog-api:local .
```

### Run

```bash
docker run -d \
  --name product-catalog-api \
  -p 8080:8080 \
  -e DB_HOST=host.docker.internal \
  -e DB_PORT=5432 \
  -e DB_NAME=productdb \
  -e DB_USER=postgres \
  -e DB_PASS=postgres \
  product-catalog-api:local
```

> **Note:** `host.docker.internal` resolves to your host machine from inside the container (works on Docker Desktop for Mac/Windows). On Linux use `--network host` instead.

---

## ✅ Verification Checklist (PR 2.2)

### Step 1 — Build the image

```bash
docker build -t product-catalog-api:local .
```

**Beklenen çıktı:** Build tamamlanmalı, iki ayrı stage (`builder`, `runtime`) görünmeli.

```
[+] Building ...
 => [builder 1/4] FROM python:3.12-slim
 => [builder 4/4] RUN pip install ...
 => [runtime 1/4] FROM python:3.12-slim
 => [runtime 4/4] COPY --from=builder /install /install
 => exporting to image
```

---

### Step 2 — Image boyutu karşılaştırması

```bash
docker images product-catalog-api
```

**Beklenen çıktı:** Image boyutu ~200-250 MB civarında olmalı. Single-stage build (~350 MB+) ile karşılaştırın.

| Build tipi | Boyut |
|---|---|
| Single-stage (`python:3.12-slim`) | ~350 MB |
| Multi-stage (bu Dockerfile) | ~220 MB |

---

### Step 3 — Konteyner içi user kontrolü

```bash
docker run --rm product-catalog-api:local whoami
```

**Beklenen çıktı:** `appuser` — root değil!

---

### Step 4 — Health endpoint (konteyner üzerinden)

```bash
# Konteyneri başlat (lokal PostgreSQL olmadan sadece endpoint'i test etmek için)
docker run -d --name api-test -p 8080:8080 product-catalog-api:local

# Health endpoint'i test et
curl http://localhost:8080/health

# Konteyner loglarını incele
docker logs api-test

# Temizlik
docker rm -f api-test
```

**Beklenen çıktı:** DB bağlantısı olmadan 503 döner — bu **beklenen** davranış.
```json
{"detail": "Database connection failed"}
```
Bu, `/health` endpoint'inin DB liveness probe olarak doğru çalıştığını kanıtlar.

---

### Step 5 — SIGTERM graceful shutdown

```bash
docker run -d --name api-test -p 8080:8080 product-catalog-api:local
docker stop api-test   # SIGTERM gönderir
docker logs api-test   # "Shutting down" mesajını ara
```

**Beklenen çıktı:** Uvicorn "Shutting down" logu — process killed değil, graceful shutdown.

---

## 🎯 Mülakat Sorusu (PR 2.2)

**S: Docker image boyutunu küçültmek ve güvenlik açıklarını kapatmak için hangi stratejileri izlersin?**

**C:**
1. **Multi-stage build** — builder stage'de derleme araçları kullanılır, runtime stage'e sadece compiled artifacts kopyalanır.
2. **`slim` veya `alpine` base image** — tam OS olmadan minimal yüzey.
3. **Non-root user** — UID 1001 ile çalıştırmak, container escape senaryolarında host root erişimini engeller.
4. **`.dockerignore`** — build context'e gereksiz dosya girişi engellenir; yanlışlıkla `.env` veya credential dosyası imaja karışmaz.
5. **Layer caching** — `COPY requirements.txt` önce, `COPY src/` sonra: kod değişikliklerinde `pip install` tekrar çalışmaz.
6. **Trivy ile tarama** (Phase 3'te CI'a entegre edilecek): `trivy image product-catalog-api:local`

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
├── Dockerfile          # Multi-stage build (PR 2.2)
├── .dockerignore       # Build context exclusions
└── k8s/                # Kubernetes manifests (Phase 2, PR 2.6)
```
