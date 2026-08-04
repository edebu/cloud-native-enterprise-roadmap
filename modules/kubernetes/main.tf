# modules/kubernetes/main.tf
#
# Cloud-agnostic Kubernetes cluster wrapper.
#
# GCP: GKE Autopilot (fully managed, per-Pod billing, auto node provisioning)
# AWS: EKS Managed Node Group (managed control plane, self-managed EC2 nodes)
#
# The interface is identical for both providers — callers use the same
# variables and receive the same output structure.
#
# ADR: docs/decision-records/011-eks-vs-gke-tradeoffs.md

module "gcp" {
  source = "./gcp"
  count  = var.cloud_provider == "gcp" ? 1 : 0

  project_id             = var.project_id
  region                 = var.region
  cluster_name           = var.cluster_name
  network_name           = var.network_name
  subnetwork_name        = var.subnetwork_name
  master_ipv4_cidr_block = var.master_ipv4_cidr_block
  authorized_networks    = var.authorized_networks
  deletion_protection    = var.deletion_protection
  labels                 = var.labels
}

module "aws" {
  source = "./aws"
  count  = var.cloud_provider == "aws" ? 1 : 0

  cluster_name              = var.cluster_name
  region                    = var.region
  vpc_id                    = var.vpc_id
  subnet_ids                = var.subnet_ids
  kubernetes_version        = var.kubernetes_version
  cluster_security_group_id = var.cluster_security_group_id
  node_instance_type        = var.node_instance_type
  node_desired_size         = var.node_desired_size
  node_min_size             = var.node_min_size
  node_max_size             = var.node_max_size
  tags                      = var.tags
}
