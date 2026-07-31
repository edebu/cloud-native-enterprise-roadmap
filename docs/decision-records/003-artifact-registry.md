# ADR 003: GCP Artifact Registry as the Private Docker Registry

| Field | Value |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-07-31 |
| **Phase** | 2 — PR 2.3 |
| **Deciders** | @edebu |

---

## Context

The Product Catalog API Docker image (built in PR 2.2) needs to be stored in a private registry before GKE can pull it during deployment (PR 2.6). The registry choice affects:

- **Security** — public registries expose images; a private registry enforces IAM-based access.
- **Latency** — co-locating the registry in the same GCP region as GKE eliminates cross-region egress latency and charges.
- **IAM granularity** — we need CI/CD to push images and GKE nodes to pull them, with different permission levels.
- **Future-proofing** — the registry should support Helm charts (Phase 3) and potentially other artifact types (npm, Python) in later phases.

---

## Decision

Use **Google Artifact Registry (GAR)** provisioned via a reusable Terraform module (`modules/artifact-registry`).

Key design choices within the module:

| Design choice | Detail |
|---|---|
| **Format** | `DOCKER` — explicitly scoped, one registry per format |
| **Location** | Same region as GKE (`europe-west3`) — no cross-region egress |
| **API enablement** | `google_project_service` inside the module — self-contained, no manual console step |
| **IAM** | `for_each` over SA lists — idempotent, individual bindings, easy to add/remove |
| **Least privilege** | CI/CD SA gets `artifactregistry.writer`; GKE SA gets `artifactregistry.reader` (added in PR 2.4) |

---

## Consequences

### Positive

- **Private by default** — no anonymous pull possible; IAM required.
- **Regional co-location** — `europe-west3-docker.pkg.dev` keeps image pulls fast and free from GKE.
- **Modular and reusable** — `modules/artifact-registry` can provision a separate registry for `prod` by passing different variables.
- **Repository-level IAM** — unlike old GCR, GAR allows per-repository permissions, enabling multi-tenant setups.
- **Supports Helm OCI** — in Phase 3, Helm charts can be stored in the same registry using `oci://` protocol.

### Negative / Trade-offs

- **Additional GCP API** — `artifactregistry.googleapis.com` must be enabled (handled inside the module via `google_project_service`).
- **Storage cost** — ~$0.10/GB/month; negligible for dev-sized images but should be monitored in prod with lifecycle policies.

---

## Alternatives Considered

| Alternative | Why Rejected |
|---|---|
| **Docker Hub (public)** | No private repos on free tier; not enterprise-grade; images leave GCP network |
| **Google Container Registry (GCR)** | Deprecated — GCR is being shut down in 2025; migrating later would be disruptive |
| **Self-hosted Harbor** | Operationally complex (VM + HA + TLS); overkill when GCP provides a managed alternative |
| **GitHub Container Registry (GHCR)** | Reasonable for open-source; but adds cross-cloud network hop for every GKE image pull |

---

## Push / Pull Reference

After `terraform apply`, the `artifact_registry_url` output gives the base URL:

```bash
# Authenticate Docker to GAR
gcloud auth configure-docker europe-west3-docker.pkg.dev

# Tag and push
REPO_URL=$(terraform output -raw artifact_registry_url)
docker tag product-catalog-api:local ${REPO_URL}/product-catalog-api:v0.1.0
docker push ${REPO_URL}/product-catalog-api:v0.1.0

# GKE deployment image reference (PR 2.6):
# image: europe-west3-docker.pkg.dev/<project>/app-images/product-catalog-api:v0.1.0
```

---

## References

- [Artifact Registry documentation](https://cloud.google.com/artifact-registry/docs)
- [Terraform resource: google_artifact_registry_repository](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository)
- [Container Registry deprecation notice](https://cloud.google.com/artifact-registry/docs/transition/transition-from-gcr)
