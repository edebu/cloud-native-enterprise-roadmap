variable "project_id" {
  type        = string
  description = "GCP Project ID. Must match Phase 1 network resources."
}

variable "region" {
  type        = string
  description = "GCP region. Must match the Phase 1 VPC region."
  default     = "europe-west3"
}
