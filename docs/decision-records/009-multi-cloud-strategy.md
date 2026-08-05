# ADR 009: Multi-Cloud Agnostic Terraform Module Strategy

**Date:** 2026-08-04  
**Status:** Accepted  
**Phase:** Phase 5 — Multi-Cloud Agnostic Transformation  
**Deciders:** Platform Engineering Team

---

## Context

Phase 1–4 delivered a production-ready, GCP-native infrastructure stack:
- **Network:** GCP VPC, Cloud NAT, Cloud Router
- **Compute:** GKE Autopilot
- **Database:** Cloud SQL PostgreSQL (Private Service Access)
- **Registry:** Google Artifact Registry
- **Secrets:** GCP Secret Manager + External Secrets Operator
- **Observability:** Prometheus + Grafana (kube-prometheus-stack)
- **Security:** HashiCorp Vault (Raft storage)

All Terraform modules were written as flat, GCP-specific implementations under `modules/<component>/`. Moving to a multi-cloud strategy requires abstracting cloud-specific details behind a shared interface so that the same calling code can target either GCP or AWS without modification.

---

## Decision

We adopt a **provider sub-module pattern** for cloud abstraction:

```
modules/<component>/
├── main.tf        ← top-level wrapper (routes based on var.cloud_provider)
├── variables.tf   ← unified interface (shared + cloud-specific optional vars)
├── outputs.tf     ← unified outputs (same names regardless of provider)
├── gcp/           ← GCP-specific implementation (moved from original location)
└── aws/           ← AWS-specific implementation (new in Phase 5)
```

The caller passes `cloud_provider = "gcp"` or `cloud_provider = "aws"`. The wrapper invokes the corresponding sub-module using `count = var.cloud_provider == "gcp" ? 1 : 0` guards. Only one sub-module is ever active per workspace.

### Considered Alternatives

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| **Provider sub-modules (chosen)** | Clean separation, minimal GCP refactor, standard pattern | Extra wrapper layer | ✅ Accepted |
| Separate `environments/dev-gcp` and `environments/dev-aws` folders | Zero interface coupling | Massive code duplication | ❌ Rejected |
| Terragrunt DRY | Very DRY, powerful | Extra toolchain dependency, learning curve | ❌ Rejected |
| Single `var.cloud_provider` switch in one file | Simple | Monolithic files, hard to maintain | ❌ Rejected |

---

## Module Mapping

| Original Path | GCP Sub-Module | AWS Sub-Module |
|:-------------|:--------------|:--------------|
| `modules/network/` | `modules/network/gcp/` | `modules/network/aws/` |
| `modules/gke/` | `modules/kubernetes/gcp/` | `modules/kubernetes/aws/` |
| `modules/cloud-sql/` | `modules/database/gcp/` | `modules/database/aws/` |
| `modules/artifact-registry/` | `modules/registry/gcp/` | `modules/registry/aws/` |
| `modules/iam/` | `modules/iam/gcp/` | `modules/iam/aws/` |
| *(new)* | `modules/secrets/gcp/` | `modules/secrets/aws/` |

---

## GCP Migration Notes

All existing GCP implementations are **moved, not rewritten**. The only change to each GCP sub-module is the path — the resource code is identical to what was tested and deployed in Phases 1–4.

Environment callers (`environments/dev/terraform/main.tf` etc.) are updated to:
1. Add `cloud_provider = "gcp"` to each module block
2. Update `source` paths to the new wrapper locations (e.g., `modules/network` → same path, but now routes through wrapper)

`terraform plan` after this refactor **must show 0 changes** — any diff indicates a regression.

---

## AWS Scope (Phase 5)

AWS sub-modules are delivered as **code + plan only** — no real AWS deployment. This decision is based on:
- GCP environment already running in production (Phase 1–4 complete)
- AWS credentials not configured for the dev environment
- The goal is to demonstrate cloud-agnostic architecture patterns, not parallel production deployments

AWS modules can be activated by:
1. Configuring AWS provider credentials
2. Setting `cloud_provider = "aws"` in the environment's `terraform.tfvars`
3. Running `terraform init && terraform apply`

---

## Cloud Provider Equivalence Map

| Concept | GCP | AWS |
|:--------|:----|:----|
| Virtual Network | VPC (`google_compute_network`) | VPC (`aws_vpc`) |
| Egress NAT | Cloud NAT + Cloud Router | NAT Gateway + Elastic IP |
| Kubernetes | GKE Autopilot | EKS Managed Node Group |
| Database | Cloud SQL PostgreSQL | RDS PostgreSQL |
| Container Registry | Artifact Registry (GAR) | Elastic Container Registry (ECR) |
| Secret Store | Secret Manager | AWS Secrets Manager |
| Pod-level Cloud Auth | Workload Identity (KSA → GSA) | IRSA (IAM Roles for Service Accounts) |
| CI/CD Auth (keyless) | Workload Identity Federation | OIDC + IAM Role |

---

## Consequences

**Positive:**
- Clear separation of cloud-specific code from shared interface
- New clouds (Azure, etc.) can be added by creating a new sub-directory
- Callers remain unchanged when cloud_provider switches
- Demonstrates enterprise-grade multi-cloud thinking for portfolio

**Negative:**
- Extra indirection (wrapper → sub-module) adds one layer of abstraction
- `terraform plan` output shows module paths with `.gcp[0]` or `.aws[0]` suffix

**Neutral:**
- AWS modules are not deployed; this is an accepted scope limitation for Phase 5

---

## References

- [Terraform Module Composition](https://developer.hashicorp.com/terraform/language/modules/develop/composition)
- [GCP → AWS Service Mapping](https://cloud.google.com/docs/get-started/aws-azure-gcp-service-comparison)
- Phase 5 Sub-PR Plan: implementation_plan.md
