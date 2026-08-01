variable "project_id" {
  type        = string
  description = "GCP Project ID. Must match the project where Phase 1 network resources were created."
}

variable "region" {
  type        = string
  description = "GCP region. Must match the region of the Phase 1 VPC and subnets."
  default     = "europe-west3"
}
