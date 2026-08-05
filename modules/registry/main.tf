# modules/registry/main.tf
#
# Cloud-agnostic container registry wrapper.
#
# GCP: Google Artifact Registry (DOCKER format, per-repository IAM)
# AWS: Elastic Container Registry (ECR, lifecycle policies)

module "gcp" {
  source = "./gcp"
  count  = var.cloud_provider == "gcp" ? 1 : 0

  project_id              = var.project_id
  region                  = var.region
  repository_id           = var.repository_id
  description             = var.description
  reader_service_accounts = var.reader_service_accounts
  writer_service_accounts = var.writer_service_accounts
  labels                  = var.labels
}

module "aws" {
  source = "./aws"
  count  = var.cloud_provider == "aws" ? 1 : 0

  repository_id        = var.repository_id
  description          = var.description
  image_tag_mutability = var.image_tag_mutability
  tags                 = var.tags
}
