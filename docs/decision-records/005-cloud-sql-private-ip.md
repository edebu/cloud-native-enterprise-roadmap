# ADR 005: Cloud SQL PostgreSQL with Private IP and Secret Manager

| Field | Value |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-08-01 |
| **Phase** | 2 — PR 2.5 |
| **Deciders** | @edebu |

---

## Context

The Product Catalog API requires a PostgreSQL database. The database hosting choice and connection security model affect:

- **Network security** — is the DB reachable from the internet?
- **Secret management** — where does the DB password live?
- **Cost** — Cloud SQL billing is instance-hour based (not per-query).
- **Operational complexity** — managed vs self-hosted vs in-cluster.

---

## Decisions

### 1. Cloud SQL over in-cluster PostgreSQL (Helm)

| | Cloud SQL | In-cluster PostgreSQL (Helm) |
|---|---|---|
| HA & failover | Managed by Google | Manual setup (StatefulSet, PVC, replication) |
| Backups | Automated, point-in-time | Manual (pg_dump to GCS or Velero) |
| Patching | Automatic | Manual image upgrades |
| Cost | ~$7-15/mo (db-f1-micro) | No extra cost (uses GKE capacity) |
| Ops burden | Zero | High |

**Decision**: Cloud SQL. This is an enterprise-grade project — managed databases are standard practice. The operational overhead of self-hosting PostgreSQL in Kubernetes is significant and not the learning focus of this phase.

---

### 2. Private IP only (`ipv4_enabled = false`)

The Cloud SQL instance has **no public IP**. Connection requires:

- **Same VPC** — GKE pods connect via private IP directly.
- **Cloud SQL Auth Proxy** (sidecar) — adds IAM authentication on top of TCP (Phase 3 upgrade).

No external attacker can reach port 5432 — it simply doesn't exist outside the VPC peering.

**VPC Peering (Private Service Access)**: Cloud SQL with private IP does not attach to a subnet directly. GCP creates a peered VPC and assigns the instance an IP from the reserved range (`10.100.0.0/16`). Traffic flows through the VPC peer — no NAT, no public transit.

---

### 3. `db-f1-micro` tier

| Tier | vCPU | RAM | Cost/mo | Use case |
|---|---|---|---|---|
| `db-f1-micro` | 0.6 shared | 614 MB | ~$7 | **Dev/learning** |
| `db-g1-small` | 0.5 shared | 1.7 GB | ~$25 | Light staging |
| `db-custom-2-7680` | 2 | 7.5 GB | ~$200 | Production |

**Decision**: `db-f1-micro` for dev. Real enterprise projects use at minimum `db-custom-2-7680` with HA in production.

> **Upgrade path**: Change `tier` variable value. Terraform updates in-place (brief downtime ~2 min). No data loss.

---

### 4. Password in Secret Manager (not tfvars / Kubernetes Secret base64)

| Approach | Security | Auditability | Rotation |
|---|---|---|---|
| Hardcoded in tfvars | ❌ Git risk | ❌ None | ❌ Manual |
| `random_password` → Terraform state only | ⚠️ State-only | ❌ None | ❌ Manual |
| **`random_password` → Secret Manager** | ✅ IAM-controlled | ✅ Version history | ✅ `gcloud secrets versions add` |
| External Secrets Operator + Secret Manager | ✅✅ Pod-level isolation | ✅ | ✅ Auto-sync |

**Decision**: `random_password` → Secret Manager. This is the foundation for Phase 4 (External Secrets Operator). The Kubernetes Secret in PR 2.6 will reference the Secret Manager value.

**Why not phase 4 approach now?**: External Secrets Operator requires ArgoCD (Phase 3) to be installed first. We'll upgrade the pattern incrementally.

---

### 5. Separate Terraform State (`env/dev/cloud-sql`)

Same reasoning as GKE (ADR 004): data sources over `terraform_remote_state`, independent lifecycle.

The Cloud SQL `deletion_policy = "ABANDON"` on the VPC peering connection prevents `terraform destroy` from failing when the peering is shared with other resources.

---

## Consequences

### Positive

- Zero public IP exposure — no 5432 reachable from internet.
- Managed backups (7-day retention, daily 02:00 UTC).
- Password never in source code — Secret Manager with IAM audit log.
- Decoupled from GKE and base infra state.

### Negative / Trade-offs

- **VPC Peering prerequisite**: `google_service_networking_connection` must be created before the instance. First `terraform apply` takes ~10-15 minutes.
- **`db-f1-micro` limitations**: No point-in-time recovery, no read replicas, limited concurrent connections (~25). Fine for dev, not for production.
- **Private IP connectivity**: Accessing the DB from your local machine requires Cloud SQL Auth Proxy or IAP TCP tunnel (no direct psql from outside VPC).

---

## Local Access (During Development)

```bash
# Cloud SQL Auth Proxy (local to the DB for debugging)
gcloud sql connect cn-er-dev-postgres --user=appuser --database=productdb

# Or download the proxy binary:
cloud-sql-proxy cn-er-dev-postgres \
  --credentials-file=path/to/sa.json \
  --port=5433
psql "host=127.0.0.1 port=5433 dbname=productdb user=appuser"
```

---

## References

- [Cloud SQL Private IP](https://cloud.google.com/sql/docs/postgres/private-ip)
- [Private Service Access](https://cloud.google.com/vpc/docs/private-services-access)
- [Secret Manager](https://cloud.google.com/secret-manager/docs)
- [Terraform: google_sql_database_instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance)
