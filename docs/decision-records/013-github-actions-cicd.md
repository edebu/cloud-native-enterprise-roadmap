# ADR 013: GitHub Actions CI/CD Pipeline Design

**Date:** 2026-08-04  
**Status:** Accepted  
**Phase:** Phase 5 — PR 5.5  
**Deciders:** Platform Engineering Team

---

## Context

Phase 5 introduces automated CI/CD to complete the cloud-native delivery lifecycle. The pipeline must:
1. Validate code quality and security on every PR
2. Build and push container images on merge to main
3. Trigger ArgoCD to sync the new image to the GKE cluster
4. Run Terraform plans on infrastructure changes

---

## Decision

Use **GitHub Actions** with three workflow files:
- `ci.yml` — PR validation (test, build, scan, tf-validate)
- `cd.yml` — Continuous delivery on main merge (build, push, sync)
- `tf-plan.yml` — Terraform plan on infrastructure PRs

---

## Why GitHub Actions

| Criterion | GitHub Actions | Cloud Build | GitLab CI |
|:----------|:--------------|:-----------|:----------|
| Repository co-location | ✅ Native | ❌ Separate service | ❌ Separate platform |
| Free minutes (public repo) | ✅ 2,000/month | ✅ 120 min/day | ✅ 400 min/month |
| GCP integration | ✅ Official actions | ✅ Native | ⚠️ Manual |
| OIDC/WIF support | ✅ First-class | ✅ Native | ⚠️ Manual |
| Ecosystem maturity | ✅ Largest marketplace | ⚠️ Limited | ✅ Good |

GitHub Actions was chosen because the repository is already hosted on GitHub, making co-location the highest-value choice for developer experience.

---

## Keyless Authentication (Workload Identity Federation)

**Problem:** CI/CD pipelines traditionally require a long-lived service account JSON key stored as a GitHub secret. This creates a credential management and rotation burden, and a significant security risk if the secret leaks.

**Solution:** GitHub Actions supports OIDC token exchange via GCP Workload Identity Federation (WIF).

**Flow:**
```
GitHub Actions Runner
  → generates OIDC JWT (audience: google)
  → sends to GCP STS (Security Token Service)
  → GCP validates JWT against GitHub's OIDC issuer
  → GCP returns short-lived access token
  → Runner impersonates the configured GSA
  → GSA has roles: artifactregistry.writer, container.developer
```

**Benefits:**
- No static credentials stored anywhere
- Token is scoped to the specific workflow run
- Token expires in 1 hour maximum
- Audit trail: GCP logs show which GitHub repo + ref triggered the action

---

## Pipeline Design

### CI (ci.yml) — PR Gating

| Step | Tool | Failure Action |
|:-----|:-----|:--------------|
| Unit tests | pytest | Block PR merge |
| Docker build | docker/build-push-action | Block PR merge |
| Security scan | aquasecurity/trivy-action | Block PR merge (CRITICAL/HIGH) |
| Terraform fmt | terraform fmt -check | Block PR merge |
| Terraform validate | terraform validate | Block PR merge |

**Trivy Configuration:**
- `ignore-unfixed: true` — ignores CVEs with no available fix (reduces noise)
- `severity: CRITICAL,HIGH` — only fails on high-severity issues
- `vuln-type: os,library` — scans both OS packages and application dependencies

### CD (cd.yml) — Main Branch Deploy

**Trigger:** Push to `main` with changes in `applications/**` or `gitops/**`

**Image Tagging Strategy:**
- `europe-west3-docker.pkg.dev/{project}/app-images/product-catalog-api:{short_sha}` — immutable, traceable
- `.../{image}:latest` — floating tag for `imagePullPolicy: Always` convenience

**ArgoCD Integration:**
The CD pipeline connects to ArgoCD via `kubectl port-forward` (no external ArgoCD endpoint). This avoids exposing the ArgoCD UI publicly. Alternative: expose ArgoCD with HTTPS ingress + admin token stored in GitHub secrets.

### TF Plan (tf-plan.yml) — Infrastructure PR Review

Posts `terraform plan` output directly as a PR comment, making infrastructure changes visible in the code review workflow. Requires `pull-requests: write` permission for the GITHUB_TOKEN.

---

## Required GitHub Secrets

| Secret | Description | How to Get |
|:-------|:------------|:-----------|
| `GCP_PROJECT_ID` | GCP project ID | `gcloud projects list` |
| `GCP_WIF_PROVIDER` | WIF provider resource name | `gcloud iam workload-identity-pools providers describe ...` |
| `GCP_WIF_SERVICE_ACCOUNT` | GSA email for WIF impersonation | `gcloud iam service-accounts list` |

---

## Consequences

**Positive:**
- No long-lived credentials in GitHub secrets
- Trivy catches container vulnerabilities before deployment
- Terraform plan in PR comments improves infrastructure change visibility
- ArgoCD remains the single source of truth for cluster state

**Negative:**
- WIF setup requires one-time gcloud commands (documented in cd.yml header)
- ArgoCD sync via port-forward is fragile (depends on GKE network access from runner)
- GitHub Actions runners are ephemeral — no persistent cache (using gha cache type)

---

## References

- [GitHub Actions WIF for GCP](https://github.com/google-github-actions/auth#workload-identity-federation)
- [Trivy GitHub Action](https://github.com/aquasecurity/trivy-action)
- [docker/build-push-action](https://github.com/docker/build-push-action)
- [ArgoCD CLI Docs](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_app_sync/)
