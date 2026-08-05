# modules/registry/variables.tf
#
# Cloud-agnostic container registry module interface.
# GCP: Google Artifact Registry (GAR)  |  AWS: Elastic Container Registry (ECR)

variable "cloud_provider" {
  type        = string
  description = "Target cloud provider. Supported values: 'gcp', 'aws'."
  default     = "gcp"

  validation {
    condition     = contains(["gcp", "aws"], var.cloud_provider)
    error_message = "cloud_provider must be either 'gcp' or 'aws'."
  }
}

# ---------------------------------------------------------------------------
# Common variables
# ---------------------------------------------------------------------------

variable "repository_id" {
  type        = string
  description = "Unique identifier for the repository."
  default     = "app-images"
}

variable "description" {
  type        = string
  description = "Human-readable description of the repository."
  default     = "Docker image repository for Cloud Native Enterprise Roadmap applications."
}

variable "labels" {
  type        = map(string)
  description = "Labels/tags for cost attribution."
  default = {
    managed-by  = "terraform"
    environment = "dev"
    phase       = "phase5"
  }
}

# ---------------------------------------------------------------------------
# GCP-specific variables
# ---------------------------------------------------------------------------

variable "project_id" {
  type        = string
  description = "GCP Project ID. Required when cloud_provider = 'gcp'."
  default     = ""
}

variable "region" {
  type        = string
  description = "GCP region. Required when cloud_provider = 'gcp'."
  default     = ""
}

variable "reader_service_accounts" {
  type        = list(string)
  description = "GCP service accounts granted read access to the GAR repository."
  default     = []
}

variable "writer_service_accounts" {
  type        = list(string)
  description = "GCP service accounts granted write access to the GAR repository."
  default     = []
}

# ---------------------------------------------------------------------------
# AWS-specific variables
# ---------------------------------------------------------------------------

variable "image_tag_mutability" {
  type        = string
  description = "Image tag mutability for ECR: MUTABLE or IMMUTABLE."
  default     = "MUTABLE"
}

variable "tags" {
  type        = map(string)
  description = "AWS tags for all resources."
  default     = {}
}
