# =============================================================================
# Stage 1: builder
# =============================================================================
# Use the full Python image for the build stage so we have gcc and other
# compilation tools needed by some packages (e.g. asyncpg C extensions).
# This stage is NEVER shipped to production — its only job is to produce
# a clean set of compiled dependencies in /install.
# =============================================================================
FROM python:3.12-slim AS builder

# Prevents Python from writing .pyc files and enables stdout/stderr flushing.
# Both are important in containerised environments.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /build

# Copy only the dependency manifest first.
# Docker layer caching means this layer is only invalidated when
# requirements.txt changes — not when application code changes.
# This is the most impactful optimisation for build times in CI.
COPY requirements.txt .

# Install dependencies into a dedicated prefix so we can COPY just this
# directory into the runtime stage, leaving no pip/setuptools/wheel residue.
RUN pip install --upgrade pip --no-cache-dir \
    && pip install --prefix=/install --no-cache-dir -r requirements.txt


# =============================================================================
# Stage 2: runtime
# =============================================================================
# Start from the same slim base to keep the final image small and reduce the
# attack surface (no build tools, no package manager cache).
# =============================================================================
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    # Prepend the custom install prefix to the Python path so imports work.
    PYTHONPATH="/install/lib/python3.12/site-packages:$PYTHONPATH" \
    # Default port — overridable via Kubernetes ConfigMap / Docker -e flag.
    PORT=8080 \
    APP_VERSION=0.1.0

# ---------------------------------------------------------------------------
# Security hardening — non-root user
#
# Running as root inside a container is a significant security risk:
# if an attacker escapes the container they have root on the host node.
# Creating a dedicated system user (UID 1001) follows the principle of
# least privilege. GKE PodSecurityStandards (restricted) enforce this.
# ---------------------------------------------------------------------------
RUN groupadd --system --gid 1001 appgroup \
    && useradd --system --uid 1001 --gid appgroup --no-create-home appuser

WORKDIR /app

# Copy compiled dependencies from the builder stage only.
COPY --from=builder /install /install

# Copy application source code.
COPY src/ ./src/

# Transfer ownership to the non-root user.
# Done in a single RUN layer to avoid intermediate layers with root-owned files.
RUN chown -R appuser:appgroup /app

# Switch to non-root user for all subsequent instructions and runtime.
USER appuser

EXPOSE 8080

# ---------------------------------------------------------------------------
# Health check
#
# Docker / Kubernetes uses this to determine container health.
# --interval: check every 30 seconds
# --timeout:  fail the check if no response within 5 seconds
# --retries:  mark unhealthy after 3 consecutive failures
# --start-period: give the app 10 seconds to initialise before checks begin
# ---------------------------------------------------------------------------
HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=10s \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')" \
    || exit 1

# Use exec form (not shell form) so signals (SIGTERM) are forwarded directly
# to the uvicorn process, enabling graceful shutdown in Kubernetes.
CMD ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "1"]
