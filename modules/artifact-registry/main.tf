# modules/artifact-registry/main.tf
#
# Provisions a private Docker repository in Google Artifact Registry (GAR).
#
# Why GAR instead of the older Container Registry (GCR)?
#   - GCR is deprecated and will be shut down in 2025.
#   - GAR supports fine-grained IAM per repository (GCR was project-wide).
#   - GAR supports multiple artifact formats (Docker, Maven, npm, Python, Helm).
#   - GAR integrates natively with GKE Autopilot's pull secret mechanism.
#
# ADR: docs/decision-records/003-artifact-registry.md

# ---------------------------------------------------------------------------
# Enable the Artifact Registry API
# ---------------------------------------------------------------------------
resource "google_project_service" "artifact_registry_api" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"

  # Prevent Terraform destroy from disabling the API —
  # other resources in the project might depend on it.
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# Docker repository
# ---------------------------------------------------------------------------
resource "google_artifact_registry_repository" "docker_repo" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  description   = var.description
  format        = "DOCKER"

  labels = var.labels

  # Ensure the API is enabled before trying to create the resource.
  depends_on = [google_project_service.artifact_registry_api]
}

# ---------------------------------------------------------------------------
# IAM — Reader bindings
#
# Uses for_each over the reader list so Terraform plans are deterministic
# and individual SA bindings can be added/removed without touching others.
# ---------------------------------------------------------------------------
resource "google_artifact_registry_repository_iam_member" "readers" {
  for_each = toset(var.reader_service_accounts)

  project    = google_artifact_registry_repository.docker_repo.project
  location   = google_artifact_registry_repository.docker_repo.location
  repository = google_artifact_registry_repository.docker_repo.name
  role       = "roles/artifactregistry.reader"
  member     = each.value
}

# ---------------------------------------------------------------------------
# IAM — Writer bindings
#
# Writer role is intentionally separate from Reader — CI/CD SA gets writer,
# GKE nodes get reader. Least privilege at the registry level.
# ---------------------------------------------------------------------------
resource "google_artifact_registry_repository_iam_member" "writers" {
  for_each = toset(var.writer_service_accounts)

  project    = google_artifact_registry_repository.docker_repo.project
  location   = google_artifact_registry_repository.docker_repo.location
  repository = google_artifact_registry_repository.docker_repo.name
  role       = "roles/artifactregistry.writer"
  member     = each.value
}
