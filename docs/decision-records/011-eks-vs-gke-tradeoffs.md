# ADR 011: EKS vs GKE Autopilot Tradeoffs

**Date:** 2026-08-04  
**Status:** Accepted  
**Phase:** Phase 5 — PR 5.3  
**Deciders:** Platform Engineering Team

---

## Context

Phase 2 delivered a GKE Autopilot cluster as the Kubernetes compute layer. Phase 5 requires an AWS-equivalent for the multi-cloud agnostic strategy. The primary AWS managed Kubernetes service is EKS (Elastic Kubernetes Service).

---

## Decision

Use **EKS with Managed Node Group** as the AWS equivalent of GKE Autopilot.

---

## Comparison

| Dimension | GKE Autopilot | AWS EKS + Managed Node Group |
|:----------|:-------------|:----------------------------|
| **Control plane** | Fully managed by Google | Fully managed by AWS |
| **Node management** | Fully managed (no node config) | Managed group (you pick instance type) |
| **Billing model** | Per-Pod CPU/memory request | Per-EC2-node-hour (regardless of utilization) |
| **Scaling** | Automatic, demand-driven | Cluster Autoscaler / KEDA needed |
| **Node OS** | Managed, auto-patched | Amazon Linux 2 / Bottlerocket, auto-patched |
| **Pod identity** | Workload Identity (KSA → GSA) | IRSA (IAM Roles for Service Accounts via OIDC) |
| **Auth model** | GCP IAM → RBAC | aws-auth ConfigMap → RBAC |
| **Kubeconfig** | `gcloud container clusters get-credentials` | `aws eks update-kubeconfig` |
| **Control plane cost** | Included in Autopilot pricing | $0.10/hour per cluster |
| **Node cost (dev)** | ~$0 when no workloads | t3.medium ~$0.047/hour |

---

## Workload Identity vs IRSA

This is the most significant architectural difference between GCP and AWS Kubernetes identity:

### GCP — Workload Identity
```
KSA (Kubernetes Service Account)
  ↓ bound via google_service_account_iam_member
GSA (Google Service Account)
  ↓ has IAM roles
GCP APIs (Secret Manager, Storage, etc.)
```

Configuration: `iam.gke.io/gcp-service-account` annotation on KSA + IAM binding on GSA.

### AWS — IRSA (IAM Roles for Service Accounts)
```
KSA (annotated with IAM Role ARN)
  ↓ OIDC token exchange via EKS OIDC provider
IAM Role (with trust policy referencing the KSA)
  ↓ has IAM policies
AWS APIs (Secrets Manager, S3, etc.)
```

Configuration: IAM OIDC provider + IAM role trust policy specifying `system:serviceaccount:{namespace}:{ksa-name}` + `eks.amazonaws.com/role-arn` annotation on KSA.

Both achieve the same goal: **keyless, pod-level cloud credential binding** without static secrets.

---

## EKS Implementation Choices

| Choice | Decision | Rationale |
|:-------|:---------|:----------|
| Node type | Managed Node Group | Middle ground between self-managed nodes (full control) and Fargate (no nodes) |
| Instance type | t3.medium | Minimum viable for a dev cluster (2 vCPU, 4 GB) |
| Node count | min:1, desired:2, max:3 | Mirrors GKE Autopilot dev sizing |
| Kubernetes version | 1.30 | Current stable at Phase 5 implementation time |
| OIDC provider | Yes | Required for IRSA (equivalent to Workload Identity) |
| Single AZ | Yes | Dev simplicity; production requires multi-AZ with multiple node groups |

---

## Consequences

**Positive:**
- EKS IRSA is functionally equivalent to GKE Workload Identity for pod-level cloud auth
- Managed node group reduces operational burden (auto node replacement, updates)
- Same kubectl commands work on both clusters (Kubernetes API is cloud-agnostic)

**Negative:**
- EKS is less "autopilot" than GKE — explicit node configuration required
- IRSA trust policy setup is more verbose than GKE Workload Identity annotation
- EKS control plane has a fixed hourly cost even with 0 workloads

---

## References

- [EKS Managed Node Groups](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [GKE Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [ADR 004: GKE Autopilot Cluster](004-gke-autopilot.md)
