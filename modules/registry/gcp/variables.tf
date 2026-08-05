# modules/artifact-registry/variables.tf

variable "project_id" {
  type        = string
  description = "GCP Project ID where the Artifact Registry repository will be created."
}

variable "region" {
  type        = string
  description = "GCP region for the repository. Prefer the same region as GKE to avoid cross-region egress charges."
}

variable "repository_id" {
  type        = string
  description = "Unique identifier for the repository within the project and region."
  default     = "app-images"
}

variable "description" {
  type        = string
  description = "Human-readable description of the repository."
  default     = "Docker image repository for Cloud Native Enterprise Roadmap applications."
}

variable "reader_service_accounts" {
  type        = list(string)
  description = <<-EOT
    List of service account emails that should be granted read access
    (roles/artifactregistry.reader) to this repository.

    GKE node pool and Workload Identity service accounts are typical consumers.
    Format: ["serviceAccount:sa-name@project.iam.gserviceaccount.com"]
  EOT
  default     = []
}

variable "writer_service_accounts" {
  type        = list(string)
  description = <<-EOT
    List of service account emails that should be granted write access
    (roles/artifactregistry.writer) to this repository.

    Typically the CI/CD service account (GitHub Actions WIF SA) that pushes images.
    Format: ["serviceAccount:sa-name@project.iam.gserviceaccount.com"]
  EOT
  default     = []
}

variable "labels" {
  type        = map(string)
  description = "Labels to attach to the repository for cost attribution and resource grouping."
  default = {
    managed-by  = "terraform"
    environment = "dev"
    phase       = "phase2"
  }
}
