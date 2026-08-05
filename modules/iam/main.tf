# modules/iam/main.tf
#
# Cloud-agnostic IAM module wrapper.
#
# GCP: Google Service Account + Project IAM bindings (Storage Viewer, Log Writer)
# AWS: IAM Role + Instance Profile + managed policy attachments
#
# ADR: docs/decision-records/014-aws-iam-vs-gcp-iam.md

module "gcp" {
  source = "./gcp"
  count  = var.cloud_provider == "gcp" ? 1 : 0

  project_id         = var.project_id
  service_account_id = var.service_account_id
  display_name       = var.display_name
}

module "aws" {
  source = "./aws"
  count  = var.cloud_provider == "aws" ? 1 : 0

  role_name              = var.service_account_id
  display_name           = var.display_name
  assume_role_principals = var.assume_role_principals
  managed_policy_arns    = var.managed_policy_arns
  tags                   = var.tags
}
