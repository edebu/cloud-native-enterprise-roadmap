# modules/secrets/main.tf
#
# Cloud-agnostic secrets management wrapper.
#
# GCP: Google Secret Manager (ESO reads via Workload Identity)
# AWS: AWS Secrets Manager (ESO reads via IRSA)

module "gcp" {
  source = "./gcp"
  count  = var.cloud_provider == "gcp" ? 1 : 0

  project_id   = var.project_id
  secret_id    = var.secret_id
  secret_value = var.secret_value
  labels       = var.labels
}

module "aws" {
  source = "./aws"
  count  = var.cloud_provider == "aws" ? 1 : 0

  secret_id    = var.secret_id
  secret_value = var.secret_value
  tags         = var.tags
}
