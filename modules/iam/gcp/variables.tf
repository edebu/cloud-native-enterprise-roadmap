variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "service_account_id" {
  type        = string
  description = "Unique ID/Name for the service account"
  default     = "devops-sa"
}

variable "display_name" {
  type        = string
  description = "Display name for the service account"
  default     = "DevOps Automation Service Account"
}