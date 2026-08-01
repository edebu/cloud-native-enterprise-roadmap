# modules/cloud-sql/main.tf
#
# Provisions a private Cloud SQL (PostgreSQL) instance using VPC Private Service Access.
#
# Architecture:
#   - No public IP on the instance (ipv4_enabled = false).
#   - GKE pods reach the DB via its private IP — traffic never leaves the VPC.
#   - Peering established via google_service_networking_connection (one per project).
#   - Password managed outside this module; caller generates and stores in Secret Manager.
#
# ADR: docs/decision-records/005-cloud-sql-private-ip.md

# ---------------------------------------------------------------------------
# Enable required APIs
# ---------------------------------------------------------------------------
resource "google_project_service" "sqladmin_api" {
  project            = var.project_id
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "servicenetworking_api" {
  project            = var.project_id
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# Private Service Access — reserve an IP range inside the VPC for GCP services.
#
# Cloud SQL with private IP uses VPC Peering (Private Service Access), not a
# subnet attachment. GCP creates a peered VPC behind the scenes and assigns
# the instance an IP from this reserved range.
#
# 10.100.0.0/16: chosen to avoid conflict with:
#   - Phase 1 subnets: 10.10.1.0/24, 10.10.2.0/24
#   - GKE master CIDR: 172.16.0.0/28
# ---------------------------------------------------------------------------
resource "google_compute_global_address" "private_ip_range" {
  project       = var.project_id
  name          = var.private_ip_range_name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = var.private_ip_address
  prefix_length = var.private_ip_prefix_length
  network       = var.network_id
}

# ---------------------------------------------------------------------------
# VPC Peering connection — links the reserved range to GCP service producer.
# One connection per project per VPC (shared across all Cloud SQL instances).
# ---------------------------------------------------------------------------
resource "google_service_networking_connection" "vpc_peering" {
  network                 = var.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]

  # ABANDON: if we destroy this state, don't try to delete the peering
  # (it may be shared with other resources). Prevents destroy failures.
  deletion_policy = "ABANDON"

  depends_on = [google_project_service.servicenetworking_api]
}

# ---------------------------------------------------------------------------
# Cloud SQL Instance
# ---------------------------------------------------------------------------
resource "google_sql_database_instance" "main" {
  project          = var.project_id
  name             = var.instance_name
  region           = var.region
  database_version = var.database_version

  deletion_protection = var.deletion_protection

  settings {
    tier = var.tier

    user_labels = var.labels

    # ---------------------------------------------------------------------------
    # Private IP only — no public endpoint.
    # Pods connect via the private IP; no Cloud SQL Auth Proxy needed
    # (though Proxy is recommended in production for IAM-based auth — Phase 3).
    # ---------------------------------------------------------------------------
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.network_id
      enable_private_path_for_google_cloud_services = true
    }

    # Automated daily backups at 02:00 UTC — 7-day retention.
    backup_configuration {
      enabled                        = true
      start_time                     = "02:00"
      point_in_time_recovery_enabled = false # Requires >db-f1-micro
      backup_retention_settings {
        retained_backups = 7
      }
    }

    # Maintenance window — Sunday at 03:00 UTC (low-traffic window).
    maintenance_window {
      day          = 7
      hour         = 3
      update_track = "stable"
    }
  }

  depends_on = [google_service_networking_connection.vpc_peering]
}

# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------
resource "google_sql_database" "app_db" {
  project  = var.project_id
  instance = google_sql_database_instance.main.name
  name     = var.db_name
}

# ---------------------------------------------------------------------------
# Application user
#
# Uses BUILT_IN authentication (username + password).
# In Phase 3, this can be replaced with Cloud SQL IAM authentication
# (no passwords — GCP IAM token used instead).
# ---------------------------------------------------------------------------
resource "google_sql_user" "app_user" {
  project  = var.project_id
  instance = google_sql_database_instance.main.name
  name     = var.db_user
  password = var.db_password

  # Prevent recreation when password rotates — update in-place instead.
  lifecycle {
    ignore_changes = [password]
  }
}
