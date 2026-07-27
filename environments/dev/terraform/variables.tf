variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  description = "GCP Target Region"
  default     = "europe-west3" # Frankfurt veya ihtiyacına göre değiştirebilirsin
}

variable "zone" {
  type        = string
  description = "GCP Target Zone"
  default     = "europe-west3-a"
}