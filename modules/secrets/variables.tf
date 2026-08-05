# modules/secrets/variables.tf
#
# Cloud-agnostic secrets module interface.
# GCP: Secret Manager  |  AWS: AWS Secrets Manager

variable "cloud_provider" {
  type        = string
  description = "Target cloud provider. Supported values: 'gcp', 'aws'."
  default     = "gcp"

  validation {
    condition     = contains(["gcp", "aws"], var.cloud_provider)
    error_message = "cloud_provider must be either 'gcp' or 'aws'."
  }
}

variable "secret_id" {
  type        = string
  description = "Unique ID/name for the secret."
}

variable "secret_value" {
  type        = string
  description = "The initial secret value."
  sensitive   = true
}

variable "labels" {
  type        = map(string)
  description = "Labels/tags for cost attribution."
  default     = {}
}

# GCP
variable "project_id" {
  type        = string
  description = "GCP Project ID. Required when cloud_provider = 'gcp'."
  default     = ""
}

# AWS
variable "tags" {
  type        = map(string)
  description = "AWS resource tags. Required when cloud_provider = 'aws'."
  default     = {}
}
