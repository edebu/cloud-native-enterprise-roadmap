# modules/kubernetes/aws/variables.tf

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster. GCP equivalent: google_container_cluster.name."
  default     = "cn-er-dev-eks"
}

variable "region" {
  type        = string
  description = "AWS region for the EKS cluster. eu-central-1 = Frankfurt (GCP europe-west3 equivalent)."
}

variable "kubernetes_version" {
  type        = string
  description = <<-EOT
    Kubernetes version for the EKS cluster.
    GCP equivalent: GKE release_channel = REGULAR (auto-updated).
    In EKS, version must be explicitly pinned and updated manually or via automation.
  EOT
  default     = "1.30"
}

variable "vpc_id" {
  type        = string
  description = "ID of the AWS VPC where the cluster will be created. From modules/network/aws output."
}

variable "subnet_ids" {
  type        = list(string)
  description = <<-EOT
    List of subnet IDs for the EKS cluster and node group.
    GCP equivalent: subnetwork_name in google_container_cluster.
    Use private subnet IDs for nodes; include both public and private for the control plane.
  EOT
}

variable "cluster_security_group_id" {
  type        = string
  description = "Security group ID to attach to the EKS cluster API server endpoint."
  default     = ""
}

variable "node_instance_type" {
  type        = string
  description = <<-EOT
    EC2 instance type for managed node group.
    GCP equivalent: GKE Autopilot auto-selects machine type per pod request.
    t3.medium (2 vCPU, 4GB RAM) is the minimum for a functional dev cluster.
  EOT
  default     = "t3.medium"
}

variable "node_desired_size" {
  type        = number
  description = "Desired number of nodes in the managed node group."
  default     = 2
}

variable "node_min_size" {
  type        = number
  description = "Minimum number of nodes."
  default     = 1
}

variable "node_max_size" {
  type        = number
  description = "Maximum number of nodes."
  default     = 3
}

variable "tags" {
  type        = map(string)
  description = "AWS tags for all resources."
  default = {
    ManagedBy   = "terraform"
    Environment = "dev"
    Phase       = "phase5"
  }
}
