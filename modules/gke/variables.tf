# modules/gke/variables.tf

variable "project_id" {
  type        = string
  description = "GCP Project ID where the GKE cluster will be created."
}

variable "region" {
  type        = string
  description = "GCP region. Autopilot clusters are always regional (multi-zone by default)."
}

variable "cluster_name" {
  type        = string
  description = "Name of the GKE Autopilot cluster."
  default     = "cn-er-autopilot"
}

variable "network_name" {
  type        = string
  description = "Name of the existing VPC network to attach the cluster to. Created in Phase 1."
}

variable "subnetwork_name" {
  type        = string
  description = "Name of the existing private subnet to attach the cluster nodes to. Created in Phase 1."
}

variable "master_ipv4_cidr_block" {
  type        = string
  description = <<-EOT
    CIDR block for the Kubernetes control plane (master) internal IP range.
    Must be /28 and must not overlap with any subnet in the VPC.
    This range is used for GKE to VPC peering — not exposed externally.
  EOT
  default     = "172.16.0.0/28"
}

variable "authorized_networks" {
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  description = <<-EOT
    List of CIDR blocks allowed to reach the cluster control plane endpoint.
    Since enable_private_endpoint = false, the public endpoint is on — limit
    who can hit it via this allowlist.

    Add your developer and CI/CD IP ranges here.
    Empty list = no external access restriction (not recommended for prod).
  EOT
  default = []
}

variable "deletion_protection" {
  type        = bool
  description = "Set to true in production to prevent accidental cluster deletion via Terraform."
  default     = false
}

variable "labels" {
  type        = map(string)
  description = "Labels applied to the cluster for cost attribution and resource grouping."
  default = {
    managed-by  = "terraform"
    environment = "dev"
    phase       = "phase2"
  }
}
