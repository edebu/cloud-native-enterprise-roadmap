# modules/secrets/gcp/variables.tf

variable "project_id" {
  type        = string
  description = "GCP Project ID."
}

variable "secret_id" {
  type        = string
  description = "Unique ID for the Secret Manager secret."
}

variable "secret_value" {
  type        = string
  description = "The initial secret value to store."
  sensitive   = true
}

variable "labels" {
  type        = map(string)
  description = "Labels for cost attribution."
  default     = {}
}
