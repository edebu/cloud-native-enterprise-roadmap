# modules/database/main.tf
#
# Cloud-agnostic database module wrapper.
#
# GCP: Cloud SQL PostgreSQL (Private Service Access, VPC peering)
# AWS: RDS PostgreSQL (private subnet group, Security Groups)
#
# ADR: docs/decision-records/012-rds-vs-cloud-sql.md

module "gcp" {
  source = "./gcp"
  count  = var.cloud_provider == "gcp" ? 1 : 0

  project_id               = var.project_id
  region                   = var.region
  instance_name            = var.instance_name
  database_version         = var.database_version
  tier                     = var.tier
  network_id               = var.network_id
  private_ip_range_name    = var.private_ip_range_name
  private_ip_address       = var.private_ip_address
  private_ip_prefix_length = var.private_ip_prefix_length
  db_name                  = var.db_name
  db_user                  = var.db_user
  db_password              = var.db_password
  deletion_protection      = var.deletion_protection
  labels                   = var.labels
}

module "aws" {
  source = "./aws"
  count  = var.cloud_provider == "aws" ? 1 : 0

  instance_name             = var.instance_name
  region                    = var.region
  db_name                   = var.db_name
  db_user                   = var.db_user
  db_password               = var.db_password
  db_instance_class         = var.db_instance_class
  db_subnet_group_name      = var.db_subnet_group_name
  subnet_ids                = var.subnet_ids
  vpc_id                    = var.vpc_id
  allowed_security_group_id = var.allowed_security_group_id
  deletion_protection       = var.deletion_protection
  tags                      = var.tags
}
