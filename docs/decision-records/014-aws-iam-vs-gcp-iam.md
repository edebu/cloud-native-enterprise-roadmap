# ADR 014: AWS IAM vs GCP IAM — Cloud Identity Models

**Date:** 2026-08-04  
**Status:** Accepted  
**Phase:** Phase 5 — PR 5.4  
**Deciders:** Platform Engineering Team

---

## Context

Both GCP and AWS have Identity and Access Management systems, but their architecture, terminology, and Kubernetes integration patterns differ significantly. This ADR documents the conceptual mapping and implementation choices made in the `modules/iam/` wrapper.

---

## Core Concepts Comparison

| Concept | GCP | AWS |
|:--------|:----|:----|
| **Identity principal** | Service Account (GSA) | IAM Role |
| **Permission unit** | IAM Role binding (predefined roles) | Policy (managed or inline) |
| **Human auth** | Google Account + IAM member | IAM User + Access Key (or SSO) |
| **Machine auth** | Service Account key or Workload Identity | IAM Role (assumed via STS) |
| **Resource scope** | Project, folder, or resource level | Account, resource, or condition level |

---

## Service Account vs IAM Role

### GCP Service Account
```hcl
resource "google_service_account" "sa" {
  account_id   = "devops-automation-sa"
  display_name = "DevOps Automation Service Account"
}

resource "google_project_iam_member" "log_writer" {
  role   = "roles/logging.logWriter"
  member = "serviceAccount:${google_service_account.sa.email}"
}
```
- The SA is both an **identity** (who you are) and a **resource** (can be granted roles)
- Email format: `{account_id}@{project}.iam.gserviceaccount.com`
- Can be impersonated by humans or other SAs via `roles/iam.serviceAccountUser`

### AWS IAM Role
```hcl
resource "aws_iam_role" "main" {
  name = "devops-automation-role"
  assume_role_policy = jsonencode({
    Statement = [{
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.main.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}
```
- Role identity is defined by its **trust policy** (who can assume it)
- Permissions are attached as separate policy documents
- Identity is identified by ARN: `arn:aws:iam::{account}:role/{name}`

---

## Kubernetes Pod Identity: Workload Identity vs IRSA

This is the most critical comparison for cloud-native applications:

### GCP — Workload Identity
**Flow:** Pod → KSA (annotated) → GSA (via WI binding) → GCP API

```yaml
# 1. KSA annotation
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    iam.gke.io/gcp-service-account: eso-secrets-sa@PROJECT.iam.gserviceaccount.com
```
```hcl
# 2. WI binding (Terraform)
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.eso.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:PROJECT.svc.id.goog[NAMESPACE/KSA_NAME]"
}
```

### AWS — IRSA (IAM Roles for Service Accounts)
**Flow:** Pod → KSA (annotated) → OIDC token exchange → IAM Role → AWS API

```yaml
# 1. KSA annotation
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/eso-secrets-role
```
```hcl
# 2. IAM Role trust policy (Terraform)
resource "aws_iam_role" "eso" {
  assume_role_policy = jsonencode({
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.cluster.arn }
      Condition = {
        StringEquals = {
          "${replace(oidc_url, "https://", "")}:sub" = "system:serviceaccount:NAMESPACE:KSA_NAME"
        }
      }
    }]
  })
}
```

**Both achieve the same goal:** Pods get cloud credentials without static secret keys.

---

## Instance Profile (AWS-only concept)

AWS requires an `aws_iam_instance_profile` to attach an IAM Role to an EC2 instance (and by extension, EKS nodes). GCP has no equivalent — the Service Account is attached to the VM directly during instance creation.

```hcl
resource "aws_iam_instance_profile" "main" {
  name = "${var.role_name}-instance-profile"
  role = aws_iam_role.main.name
}
```

---

## Module Implementation Decision

The `modules/iam/` wrapper exposes a unified interface:
- `service_account_id` → GCP: `account_id`; AWS: `role_name`
- `display_name` → GCP: `display_name`; AWS: role description
- `service_account_email` output → GCP: SA email; AWS: role ARN

This allows callers to reference the identity without knowing the underlying cloud format.

---

## References

- [GCP IAM Overview](https://cloud.google.com/iam/docs/overview)
- [AWS IAM Overview](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html)
- [IRSA Deep Dive](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [GKE Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [ADR 011: EKS vs GKE Tradeoffs](011-eks-vs-gke-tradeoffs.md)
