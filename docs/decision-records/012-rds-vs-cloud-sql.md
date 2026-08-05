# ADR 012: RDS vs Cloud SQL

**Date:** 2026-08-04  
**Status:** Accepted  
**Phase:** Phase 5 — PR 5.4  
**Deciders:** Platform Engineering Team

---

## Context

Phase 2 deployed Cloud SQL PostgreSQL 16 as the database layer, using Private Service Access (VPC Peering) for network isolation. Phase 5 requires an AWS equivalent.

---

## Decision

Use **AWS RDS PostgreSQL 15** in a private subnet group as the AWS equivalent of Cloud SQL.

---

## Comparison

| Dimension | GCP Cloud SQL | AWS RDS PostgreSQL |
|:----------|:-------------|:------------------|
| **Engine** | PostgreSQL 16 | PostgreSQL 15 |
| **Instance type** | db-f1-micro (~1 shared vCPU, 614 MB) | db.t3.micro (2 vCPU, 1 GB) |
| **Network isolation** | Private Service Access (VPC Peering, separate network) | DB Subnet Group in private VPC subnets (same VPC) |
| **Public IP** | `ipv4_enabled = false` | `publicly_accessible = false` |
| **Password management** | Stored in GCP Secret Manager (external) | Stored in AWS Secrets Manager (in module) |
| **Connection model** | Direct private IP or Cloud SQL Auth Proxy | Direct private IP or RDS Proxy |
| **Auto backup** | 7-day retention, 02:00 UTC start | 7-day retention, 02:00-03:00 UTC window |
| **Maintenance** | Sunday 03:00 UTC | Sunday 03:00-04:00 UTC |
| **Storage** | Automatic resize | `max_allocated_storage = 100 GB` (auto-scaling) |
| **Encryption** | Default (Google-managed keys) | `storage_encrypted = true` (AWS-managed) |
| **Cost (dev)** | ~$7-15/month (db-f1-micro) | ~$13/month (db.t3.micro) |

---

## Networking Differences

**GCP Cloud SQL Private Service Access:**
- Creates a VPC peering between your VPC and GCP's service producer network
- Requires `google_compute_global_address` (reserved IP range) + `google_service_networking_connection`
- Cloud SQL instance gets a private IP from the reserved range (10.100.0.0/16)
- Peering setup is project-wide, shared across all Cloud SQL instances

**AWS RDS Subnet Group:**
- Instance is placed directly inside VPC private subnets
- No peering required — same VPC plane
- Security Groups control which resources can reach port 5432
- Simpler networking model, less infrastructure overhead

---

## Password Management

| | GCP | AWS |
|:--|:----|:----|
| Storage | GCP Secret Manager (separate resource, referenced by ESO) | AWS Secrets Manager (created in same module for dev convenience) |
| ESO access | Workload Identity → GSA → `roles/secretmanager.secretAccessor` | IRSA → IAM Role → `secretsmanager:GetSecretValue` policy |
| Rotation | Manual or via Secret Manager rotation feature | Manual or via RDS-integrated rotation (requires Lambda) |

---

## Consequences

**Positive:**
- Simpler network topology (no VPC peering required)
- Built-in storage auto-scaling
- Image scanning on push via RDS Enhanced Monitoring (optional)

**Negative:**
- RDS has a minimum instance size larger than GCP's db-f1-micro
- AWS requires explicit Security Group rules (GCP used VPC peering isolation)
- PostgreSQL version may lag slightly behind GCP's available versions

---

## References

- [AWS RDS PostgreSQL](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html)
- [GCP Cloud SQL](https://cloud.google.com/sql/docs/postgres)
- [ADR 005: Cloud SQL PostgreSQL Integration](005-cloud-sql-private-ip.md)
