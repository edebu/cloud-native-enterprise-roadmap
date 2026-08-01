# environments/dev/terraform/cloud-sql/main.tf
#
# Cloud SQL (PostgreSQL 16) with Private IP — dev environment wiring.
#
# Pattern: same as GKE — data sources for Phase 1 VPC, no remote_state coupling.
# Password: generated via random_password, stored in Secret Manager.
# The Kubernetes Secret (PR 2.6) will reference this Secret Manager secret.

# ---------------------------------------------------------------------------
# Data sources — Phase 1 VPC (same pattern as GKE)
# ---------------------------------------------------------------------------
data "google_compute_network" "vpc" {
  project = var.project_id
  name    = "dev-enterprise-vpc"
}

# ---------------------------------------------------------------------------
# Enable Secret Manager API
# ---------------------------------------------------------------------------
resource "google_project_service" "secretmanager_api" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# DB password — randomly generated, 24-char, alphanumeric + special chars.
#
# Why random_password instead of a hardcoded tfvars value?
#   - Credentials never appear in source code or version control.
#   - Terraform state holds the password (encrypted at rest in GCS).
#   - Stored in Secret Manager for Pod consumption (Phase 4: External Secrets).
# ---------------------------------------------------------------------------
resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}|;:,.<>?"
  min_lower        = 4
  min_upper        = 4
  min_numeric      = 4
  min_special      = 2
}

# ---------------------------------------------------------------------------
# Secret Manager — store the DB password as a versioned secret.
# ---------------------------------------------------------------------------
resource "google_secret_manager_secret" "db_password" {
  project   = var.project_id
  secret_id = "cn-er-dev-db-password"

  replication {
    auto {}
  }

  labels = {
    managed-by  = "terraform"
    environment = "dev"
    phase       = "phase2"
    component   = "cloud-sql"
  }

  depends_on = [google_project_service.secretmanager_api]
}

resource "google_secret_manager_secret_version" "db_password_v1" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

# ---------------------------------------------------------------------------
# Grant GKE default compute SA access to read the secret.
# Phase 4 will replace this with Workload Identity + External Secrets Operator.
# ---------------------------------------------------------------------------
data "google_project" "project" {
  project_id = var.project_id
}

resource "google_secret_manager_secret_iam_member" "gke_node_secret_reader" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

# ---------------------------------------------------------------------------
# Cloud SQL — PostgreSQL 16, db-f1-micro, private IP only
# ---------------------------------------------------------------------------
module "cloud_sql" {
  source = "../../../../modules/cloud-sql"

  project_id    = var.project_id
  region        = var.region
  instance_name = "cn-er-dev-postgres"

  database_version = "POSTGRES_16"

  # db-f1-micro: cheapest option for dev learning — ~$7-15/mo
  # See ADR 005 for upgrade path to db-g1-small or custom tiers.
  tier = "db-f1-micro"

  # VPC self_link — Cloud SQL uses Private Service Access (VPC Peering),
  # not a subnet attachment like GKE. Requires the full self_link URL.
  network_id = data.google_compute_network.vpc.self_link

  private_ip_range_name    = "cloud-sql-private-ip-range"
  private_ip_address       = "10.100.0.0"
  private_ip_prefix_length = 16

  db_name  = "productdb"
  db_user  = "appuser"
  db_password = random_password.db_password.result

  deletion_protection = false

  labels = {
    managed-by  = "terraform"
    environment = "dev"
    phase       = "phase2"
  }
}
