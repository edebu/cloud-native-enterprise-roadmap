# ADR 006: Kubernetes Deployment Manifests with Security Hardening

| Field | Value |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-08-01 |
| **Phase** | 2 — PR 2.6 |
| **Deciders** | @edebu |

---

## Context

We have the Product Catalog API container image (PR 2.2) and a private Cloud SQL instance (PR 2.5). Now we need to deploy the application onto GKE Autopilot (PR 2.4). The deployment configuration must satisfy:

1.  **Isolation** — resources should reside in a custom namespace, not `default`.
2.  **GKE Autopilot Resource Constraints** — Autopilot enforces minimum CPU/memory requests and limits.
3.  **Security Hardening** — the application must align with corporate security guidelines (non-root, read-only root FS, dropped capabilities).
4.  **Database Connection** — environmental parameters and secrets must be injected securely.

---

## Decisions

### 1. Dedicated Namespace (`cn-er-dev`)
Rather than deploying into `default`, we provision `cn-er-dev`. This isolates dev workloads from system services and future multi-tenant applications.

---

### 2. GKE Autopilot Minimum Sizing (250m CPU / 512Mi Memory)
GKE Autopilot requires specific minimum pod resource values. If request/limit values are too low or mismatch, Autopilot automatically overrides them.
- **Decision**: Set both `limits` and `requests` to equal values (`250m` CPU, `512Mi` memory) to guarantee stable scheduling without dynamic sizing overhead.

---

### 3. Container Runtime Hardening
To prevent container escape and privilege escalation, we implement:
-   `runAsNonRoot: true`, `runAsUser: 10001` (matches our PR 2.2 Dockerfile configuration).
-   `allowPrivilegeEscalation: false` (prevents child processes from gaining more privileges than parent).
-   `readOnlyRootFilesystem: true` (disables writing to container image layers).
-   `capabilities.drop: ["ALL"]` (removes all Linux capabilities).
-   `seccompProfile: {type: RuntimeDefault}`.

#### The Read-Only Root Filesystem Workaround
Python, FastAPI, and standard Linux libraries write logs, cache, or lock files to `/tmp`. When `readOnlyRootFilesystem` is set to `true`, writes fail, causing immediate application crash.
- **Decision**: Mount a temporary in-memory volume (`emptyDir: {}`) at `/tmp` inside the container. This allows the application to write transient files without writing to the disk image layer.

---

### 4. Database Secret Management (Temporary Base64)
- **Decision**: Inject `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PORT` via `ConfigMap`, and `DB_PASSWORD` via `Secret`.
- **Note**: This is a baseline setup. In Phase 4, we will transition to **External Secrets Operator (ESO)** which syncs GCS Secret Manager secrets directly into Kubernetes Secrets, removing the need for manual base64 YAML files in Git.

---

### 5. Service Type `ClusterIP`
- **Decision**: Expose the Deployment internally within GKE via a `ClusterIP` service (port 80 pointing to targetPort 8000). External ingress routing is deferred to PR 2.7 (Ingress Controller / LoadBalancer Service).

---

## Consequences

### Positive
-   **Secure by Default**: Container runs as unprivileged user with read-only root filesystem.
-   **Autopilot Ready**: Resource values fully conform to Autopilot scheduler limits.
-   **No Hardcoded Secrets in Code**: Database password decoupled into a Kubernetes Secret.

### Negative / Trade-offs
-   `emptyDir` uses node memory/storage capacity.
-   Direct psql or troubleshooting from inside the container is restricted due to dropped capabilities and read-only FS (standard for enterprise staging/prod).

---

## Interview Question

**Q: GKE Autopilot'ta `readOnlyRootFilesystem: true` yaptığımda pod crash ediyor (CrashLoopBackOff). Neden olabilir ve nasıl çözersin?**

**A:** Çoğu uygulama (örneğin python, nodejs, log kütüphaneleri) başlatılırken `/tmp`, `/var/run` veya `/opt` gibi dizinlere geçici dosya yazmaya çalışır. Root filesystem read-only yapıldığında bu yazma işlemleri I/O hatası (Read-only file system) verir ve uygulama çöker. 

**Çözüm:** Uygulamanın yazmak istediği geçici dizinlere Kubernetes `emptyDir` volumü mount edilir. Bizim manifestimizde yaptığımız gibi:
```yaml
volumeMounts:
- name: tmp-volume
  mountPath: /tmp
volumes:
- name: tmp-volume
  emptyDir: {}
```
Bu sayede uygulama disk imajı katmanına yazmaz, RAM tabanlı geçici disk alanını kullanır. Güvenlikten taviz verilmemiş olur.

---

## References
- [GKE Autopilot hardening guide](https://cloud.google.com/kubernetes-engine/docs/concepts/sandbox)
- [Kubernetes Security Context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
