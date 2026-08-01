# environments/dev/terraform/gke/main.tf
#
# GKE Autopilot cluster — wires the module to existing Phase 1 resources
# via data sources (no terraform_remote_state coupling).
#
# Why data sources instead of terraform_remote_state?
#   - Decoupled: this state can be destroyed/recreated without touching Phase 1.
#   - Explicit: the network names are visible here, not buried in another state.
#   - Portable: works even if the network was created manually or by another tool.

# ---------------------------------------------------------------------------
# Data sources — look up Phase 1 resources by name
# ---------------------------------------------------------------------------

# Reads the existing VPC created in Phase 1 to get its self_link.
data "google_compute_network" "vpc" {
  project = var.project_id
  name    = "dev-enterprise-vpc"
}

# Reads the private subnet. GKE nodes will be placed here.
data "google_compute_subnetwork" "private" {
  project = var.project_id
  region  = var.region
  name    = "dev-enterprise-vpc-private-subnet"
}

# Reads the existing GAR repository to bind the node SA as reader.
# This avoids hardcoding the repository resource ID across state files.
data "google_artifact_registry_repository" "app_images" {
  project       = var.project_id
  location      = var.region
  repository_id = "app-images"
}

# Resolves the project number — needed to construct the default compute SA email.
# The default Compute Engine SA format is:
#   <project_number>-compute@developer.gserviceaccount.com
data "google_project" "project" {
  project_id = var.project_id
}

# ---------------------------------------------------------------------------
# GKE Autopilot Cluster
# ---------------------------------------------------------------------------
module "gke" {
  source = "../../../../modules/gke"

  project_id      = var.project_id
  region          = var.region
  cluster_name    = "cn-er-dev-autopilot"
  network_name    = data.google_compute_network.vpc.name
  subnetwork_name = data.google_compute_subnetwork.private.name

  # 172.16.0.0/28 is reserved for GKE control plane peering.
  # Does not conflict with 10.10.x.x subnets from Phase 1.
  master_ipv4_cidr_block = "172.16.0.0/28"

  # Restrict who can reach the public control plane endpoint.
  # Empty = no restriction during development (see ADR 004 for trade-off).
  # Add your static IP: { cidr_block = "x.x.x.x/32", display_name = "my-ip" }
  authorized_networks = []

  deletion_protection = false

  labels = {
    managed-by  = "terraform"
    environment = "dev"
    phase       = "phase2"
  }
}

# ---------------------------------------------------------------------------
# GAR IAM — Grant the default Compute Engine SA read access to pull images.
#
# GKE Autopilot nodes run as the default compute SA unless a custom SA is
# configured (requires Standard mode). Granting reader access here allows
# nodes to pull images from our private GAR repository without authentication
# at the kubelet level.
#
# In Phase 3, Workload Identity will handle per-Pod SA binding for finer
# control — but for the initial deployment we use the node-level SA.
# ---------------------------------------------------------------------------
resource "google_artifact_registry_repository_iam_member" "gke_node_gar_reader" {
  project    = data.google_artifact_registry_repository.app_images.project
  location   = data.google_artifact_registry_repository.app_images.location
  repository = data.google_artifact_registry_repository.app_images.name
  role       = "roles/artifactregistry.reader"

  # Default Compute Engine SA: <project_number>-compute@developer.gserviceaccount.com
  member = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

# ---------------------------------------------------------------------------
# ArgoCD Deployment via Helm
# ---------------------------------------------------------------------------
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.3.11"
  namespace        = "argocd"
  create_namespace = true
  timeout          = 900 # 15 minutes for GKE Autopilot node provisioning

  set {
    name  = "server.extraArgs"
    value = "{--insecure}"
  }
}

# ---------------------------------------------------------------------------
# External Secrets Operator Deployment via Helm
# ---------------------------------------------------------------------------
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.9.20"
  namespace        = "external-secrets"
  create_namespace = true
  timeout          = 900 # 15 minutes for GKE Autopilot node provisioning

  set {
    name  = "installCRDs"
    value = "true"
  }
}

# ---------------------------------------------------------------------------
# IAM & Workload Identity for External Secrets Operator
# ---------------------------------------------------------------------------

# GSA for ESO secrets access
resource "google_service_account" "eso_secrets_sa" {
  account_id   = "eso-secrets-sa"
  display_name = "External Secrets Operator GSA for dev GKE"
  project      = var.project_id
}

# Grant the GSA access to read Secret Manager secrets
resource "google_project_iam_member" "eso_secrets_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.eso_secrets_sa.email}"
}

# Bind GSA to KSA via Workload Identity.
resource "google_service_account_iam_member" "eso_workload_identity" {
  service_account_id = google_service_account.eso_secrets_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[external-secrets/external-secrets]"
}
