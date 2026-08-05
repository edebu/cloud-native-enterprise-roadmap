# modules/secrets/gcp/main.tf
#
# GCP Secret Manager wrapper.
#
# Creates a Secret Manager secret and stores an initial version.
# ESO (External Secrets Operator) reads from this secret via Workload Identity.
# The secret value is passed in as a sensitive variable — never logged.

resource "google_project_service" "secretmanager_api" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_secret_manager_secret" "secret" {
  project   = var.project_id
  secret_id = var.secret_id

  replication {
    auto {}
  }

  labels = var.labels

  depends_on = [google_project_service.secretmanager_api]
}

resource "google_secret_manager_secret_version" "version" {
  secret      = google_secret_manager_secret.secret.id
  secret_data = var.secret_value

  lifecycle {
    ignore_changes = [secret_data]
  }
}
