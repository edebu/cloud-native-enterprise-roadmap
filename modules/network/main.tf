# modules/network/main.tf
#
# Cloud-agnostic network module wrapper.
#
# This top-level module delegates to the appropriate cloud-specific sub-module
# based on the `cloud_provider` variable. The interface (inputs & outputs) is
# identical regardless of the target cloud — callers should not need to change
# their code when switching between GCP and AWS.
#
# Sub-modules:
#   gcp/ — Google Cloud VPC, subnets, Cloud NAT, Cloud Router, firewall rules
#   aws/ — AWS VPC, subnets, Internet Gateway, NAT Gateway, Security Groups
#
# ADR: docs/decision-records/009-multi-cloud-strategy.md

# ---------------------------------------------------------------------------
# GCP Network
# Invoked only when cloud_provider = "gcp"
# ---------------------------------------------------------------------------
module "gcp" {
  source = "./gcp"
  count  = var.cloud_provider == "gcp" ? 1 : 0

  project_id          = var.project_id
  region              = var.region
  network_name        = var.network_name
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
}

# ---------------------------------------------------------------------------
# AWS Network
# Invoked only when cloud_provider = "aws"
# ---------------------------------------------------------------------------
module "aws" {
  source = "./aws"
  count  = var.cloud_provider == "aws" ? 1 : 0

  region              = var.region
  network_name        = var.network_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  tags                = var.tags
}
