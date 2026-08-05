module "network" {
  source = "../../../modules/network"

  cloud_provider      = "gcp"
  project_id          = var.project_id
  region              = var.region
  network_name        = "dev-enterprise-vpc"
  public_subnet_cidr  = "10.10.1.0/24"
  private_subnet_cidr = "10.10.2.0/24"
}

module "iam" {
  source = "../../../modules/iam"

  cloud_provider     = "gcp"
  project_id         = var.project_id
  service_account_id = "devops-automation-sa"
  display_name       = "DevOps Automation Service Account for Dev"
}

# ---------------------------------------------------------------------------
# Artifact Registry - private Docker repository
#
# The devops-automation-sa (CI/CD) gets writer access so it can push images.
# GKE node SA will be granted reader access in the GKE module (PR 2.4)
# once the GKE SA email is known.
# ---------------------------------------------------------------------------
module "artifact_registry" {
  source = "../../../modules/registry"

  cloud_provider = "gcp"

  project_id    = var.project_id
  region        = var.region
  repository_id = "app-images"
  description   = "Docker image repository for CN-ER Phase 2 applications."

  # devops-automation-sa pushes images from CI/CD (Phase 3).
  # The SA email follows the pattern: <id>@<project>.iam.gserviceaccount.com
  writer_service_accounts = [
    "serviceAccount:devops-automation-sa@${var.project_id}.iam.gserviceaccount.com",
  ]

  labels = {
    managed-by  = "terraform"
    environment = "dev"
    phase       = "phase2"
  }
}