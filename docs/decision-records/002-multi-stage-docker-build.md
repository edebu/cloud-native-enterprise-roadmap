# ADR 002: Multi-Stage Docker Build with Security Hardening

| Field | Value |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-07-28 |
| **Phase** | 2 — PR 2.2 |
| **Deciders** | @edebu |

---

## Context

The Product Catalog API needs to be containerised and pushed to GCP Artifact Registry (GAR) before it can be deployed to GKE. The build strategy directly impacts:

- **Image size** — larger images consume more GAR storage and slow down pod startup times (image pull latency in Kubernetes).
- **Security posture** — images with unnecessary tools (compilers, package managers) have a larger attack surface and more CVEs.
- **CI/CD build time** — poor layer ordering causes unnecessary cache busting on every code change.

---

## Decision

Use a **two-stage Docker build**:

1. **`builder` stage** — `python:3.12-slim` with full toolchain; installs all dependencies into an isolated prefix (`/install`).
2. **`runtime` stage** — `python:3.12-slim` with no build tools; copies only the compiled artifacts from `builder`.

Additionally apply the following security hardening:

- **Non-root user** (`appuser`, UID 1001) — process runs without elevated privileges.
- **`COPY requirements.txt` before `COPY src/`** — Docker layer caching ensures the slow `pip install` step only runs when dependencies change, not on every code commit.
- **Exec-form `CMD`** — `["python", "-m", "uvicorn", ...]` instead of shell form so `SIGTERM` propagates directly to uvicorn for graceful shutdown.
- **`HEALTHCHECK` instruction** — Docker and Kubernetes use this for liveness probes without extra sidecar containers.

---

## Consequences

### Positive

- **Smaller attack surface**: No `pip`, `gcc`, or build headers in the final image.
- **Faster CI loops**: Only changed layers are rebuilt. A code-only change skips the `pip install` layer entirely.
- **Kubernetes-ready**: Non-root UID satisfies GKE Autopilot's default PodSecurity requirements. Graceful `SIGTERM` handling prevents dropped requests during rolling updates.

### Negative / Trade-offs

- **Slightly more complex Dockerfile**: Two stages require understanding of `--from=builder` copy semantics. Mitigated by inline comments.
- **`PYTHONPATH` must be set explicitly**: Because we install to `/install` (not the system site-packages), the runtime stage must set `PYTHONPATH`. This is documented in the Dockerfile.

---

## Alternatives Considered

| Alternative | Why Rejected |
|---|---|
| Single-stage build | Image includes build tools, 2-3× larger, more CVEs |
| `python:3.12` (full image) | Even larger base; `slim` is the right default for microservices |
| Distroless base image | No shell makes debugging harder; good for prod, overkill for a learning roadmap |
| Poetry / pip-tools lock file | Good practice but adds complexity beyond what this phase teaches |

---

## Image Size Comparison

| Build type | Approximate size |
|---|---|
| Single-stage (`python:3.12`) | ~1.1 GB |
| Single-stage (`python:3.12-slim`) | ~350 MB |
| **Multi-stage (this ADR)** | **~220 MB** |

> Run `docker images product-catalog-api` after building to see the actual size on your machine.

---

## References

- [Docker multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
- [Python Docker best practices — PYTHONDONTWRITEBYTECODE](https://docs.python.org/3/using/cmdline.html#envvar-PYTHONDONTWRITEBYTECODE)
- [GKE Pod Security Standards](https://cloud.google.com/kubernetes-engine/docs/how-to/podsecurityadmission)
