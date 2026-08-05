# modules/kubernetes/variables.tf
#
# Cloud-agnostic interface for the Kubernetes cluster module.
# GCP: GKE Autopilot  |  AWS: EKS Managed Node Group

variable "cloud_provider" {
  type        = string
  description = "Target cloud provider. Supported values: 'gcp', 'aws'."
  default     = "gcp"

  validation {
    condition     = contains(["gcp", "aws"], var.cloud_provider)
    error_message = "cloud_provider must be either 'gcp' or 'aws'."
  }
}

# ---------------------------------------------------------------------------
# Common variables
# ---------------------------------------------------------------------------

variable "cluster_name" {
  type        = string
  description = "Name of the Kubernetes cluster."
  default     = "cn-er-autopilot"
}

variable "region" {
  type        = string
  description = "Cloud region for the cluster."
}

variable "labels" {
  type        = map(string)
  description = "Labels/tags to attach to the cluster."
  default = {
    managed-by  = "terraform"
    environment = "dev"
    phase       = "phase5"
  }
}

variable "deletion_protection" {
  type        = bool
  description = "Prevents accidental cluster deletion via Terraform."
  default     = false
}

# ---------------------------------------------------------------------------
# GCP-specific variables (ignored when cloud_provider = 'aws')
# ---------------------------------------------------------------------------

variable "project_id" {
  type        = string
  description = "GCP Project ID. Required when cloud_provider = 'gcp'."
  default     = ""
}

variable "network_name" {
  type        = string
  description = "Name of the existing GCP VPC. Required when cloud_provider = 'gcp'."
  default     = ""
}

variable "subnetwork_name" {
  type        = string
  description = "Name of the existing GCP subnet. Required when cloud_provider = 'gcp'."
  default     = ""
}

variable "master_ipv4_cidr_block" {
  type        = string
  description = "CIDR block for GKE control plane peering. Required when cloud_provider = 'gcp'."
  default     = "172.16.0.0/28"
}

variable "authorized_networks" {
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  description = "List of CIDR blocks allowed to reach the GKE control plane."
  default     = []
}

# ---------------------------------------------------------------------------
# AWS-specific variables (ignored when cloud_provider = 'gcp')
# ---------------------------------------------------------------------------

variable "vpc_id" {
  type        = string
  description = "ID of the AWS VPC. Required when cloud_provider = 'aws'."
  default     = ""
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for EKS node group. Required when cloud_provider = 'aws'."
  default     = []
}

variable "node_instance_type" {
  type        = string
  description = "EC2 instance type for EKS managed node group."
  default     = "t3.medium"
}

variable "tags" {
  type        = map(string)
  description = "AWS tags for all resources."
  default     = {}
}
