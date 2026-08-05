# modules/network/variables.tf
#
# Cloud-agnostic interface for the network module.
# The caller sets `cloud_provider` and the appropriate sub-module is invoked.
# All other variables map 1-to-1 between GCP and AWS implementations.

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
# Common variables (shared across all cloud providers)
# ---------------------------------------------------------------------------

variable "network_name" {
  type        = string
  description = "Name of the VPC / virtual network."
  default     = "enterprise-vpc"
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR block for the public subnet."
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  type        = string
  description = "CIDR block for the private subnet."
  default     = "10.0.2.0/24"
}

variable "region" {
  type        = string
  description = "Cloud region where the network resources will be created."
}

# ---------------------------------------------------------------------------
# GCP-specific variables (ignored when cloud_provider = 'aws')
# ---------------------------------------------------------------------------

variable "project_id" {
  type        = string
  description = "GCP Project ID. Required when cloud_provider = 'gcp'."
  default     = ""
}

# ---------------------------------------------------------------------------
# AWS-specific variables (ignored when cloud_provider = 'gcp')
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the entire AWS VPC. Required when cloud_provider = 'aws'."
  default     = "10.20.0.0/16"
}

variable "tags" {
  type        = map(string)
  description = "AWS tags to apply to all resources. Required when cloud_provider = 'aws'."
  default = {
    ManagedBy   = "terraform"
    Environment = "dev"
    Phase       = "phase5"
  }
}
