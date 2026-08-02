# Workspace Customizations & Rules

This document outlines workspace-scoped rules and the status/plan for the project to ensure context is shared across agent sessions (e.g. for `claude-mem`).

## Project Status

- **Completed Phases**: 
  - Phase 1 (Infrastructure foundation)
  - Phase 2 (GKE cluster, Database, Ingress)
  - Phase 3 (GitOps, ArgoCD, ESO, Secret Manager)
  - Phase 4 (Enterprise Observability & Security)
- **Active Phase**: Phase 5 (Multi-Cloud Agnostic Transformation)

## Phase 4: Sub-PR Breakdown Plan (Completed)

1. **PR 4.1**: Deploy `kube-prometheus-stack` Helm chart via Terraform in `monitoring` namespace. (Completed)
2. **PR 4.2**: Configure `ServiceMonitor` in `product-catalog-api` Helm chart for metrics scraping. (Completed)
3. **PR 4.3**: Provision FastAPI custom dashboard ConfigMap in Grafana. (Completed)
4. **PR 4.4**: Deploy official HashiCorp Vault Helm chart via Terraform in `vault` namespace. (Completed)
5. **PR 4.5**: Integrate Vault with External Secrets Operator (ESO) via Kubernetes Authentication. (Completed)

## Agent Guidelines

- Always ensure Terraform variables and resource namespaces are well-structured.
- Keep application Kubernetes manifests fully managed by GitOps (under `gitops/` or in application Helm charts).
- Maintain clean Git hygiene by utilizing the designated branch prefixes (e.g. `feature/phase4-pr1-...`).
