# ADR 015: Public Repository Security Design & Actions Hardening

**Date:** 2026-08-05  
**Status:** Accepted  
**Phase:** Phase 5 — Security Hardening  
**Deciders:** Platform Engineering Team

---

## Context

The `cloud-native-enterprise-roadmap` repository is a public project. In a public repository model, open-source users can fork and submit Pull Requests. This introduces specific security vectors:
1. **Poisoned Pipeline Execution (PPE):** A malicious actor forks the repository, modifies a workflow file in their branch, and submits a PR. If workflows run automatically, they could execute arbitrary code on our runners.
2. **Secrets / Identity Exfiltration:** If workflows run with write access or have access to repository secrets, a malicious PR could exfiltrate GCP authentication details or take over GitHub repository resources.
3. **Workload Identity Federation (WIF) Abuse:** WIF allows keyless authentication. If not restricted, a fork of this repository (e.g. `malicious-user/cloud-native-enterprise-roadmap`) could assume the GCP Service Account role by generating OIDC tokens containing their fork repository info.

---

## Decision

We adopt a multi-layered security framework to protect the repository:

### 1. GitHub Actions Permissions Hardening
We configure explicit `permissions: read-all` globally at the top of all workflow YAML files (`ci.yml`, `cd.yml`, `tf-plan.yml`). This ensures:
- The default `GITHUB_TOKEN` is stripped of write access across all scopes.
- Jobs that require elevated permissions must request them explicitly (e.g., `id-token: write` for WIF and `pull-requests: write` for PR comments).

### 2. CODEOWNERS Enforcement
We implement a `.github/CODEOWNERS` file. Any changes to critical paths will require mandatory review and approval from the project owner (`@edebu`).
Protected paths:
- `/.github/workflows/` (CI/CD Pipeline configs)
- `/modules/` (Terraform modules)
- `/environments/` (Active environments deployment wireup)

### 3. Workflow Approval Policy (GitHub Settings)
We mandate repository settings to require approval for all outside collaborators before any GitHub Actions workflows run. This prevents automated execution of malicious code from fork PRs.

### 4. GCP WIF Trust Policy Restriction
We enforce that the Google Cloud Workload Identity Provider trust policy explicitly validates the repository attribute:
```
assertion.repository == "edebu/cloud-native-enterprise-roadmap"
```
This guarantees that OIDC tokens issued to forks of the repository are rejected by GCP's Security Token Service (STS), preventing unauthorized access to the Google Cloud backend.

---

## Consequences

**Positive:**
- Complete protection against malicious workflow execution.
- Keyless GCP credentials (via WIF) are strictly tied to the main repository, preventing fork-abuse.
- Critical infrastructure code (Terraform, Workflows) cannot be modified without `@edebu` approval.
- Minimal permissions (`read-all`) by default limit blast radius of any compromised dependencies.

**Negative:**
- Contributions from forks require manual workflow approval by `@edebu` before tests run. (Acceptable trade-off for public security).

---

## References

- [GitHub Actions Security Best Practices](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [GCP Workload Identity Federation OIDC Mapping](https://cloud.google.com/iam/docs/workload-identity-federation)
- [ADR 013: GitHub Actions CI/CD Pipeline Design](013-github-actions-cicd.md)
