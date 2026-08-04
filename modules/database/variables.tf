# modules/database/variables.tf
#
# Cloud-agnostic database module interface.
# GCP: Cloud SQL PostgreSQL  |  AWS: RDS PostgreSQL

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

variable "instance_name" {
  type        = string
  description = "Unique name for the database instance."
  default     = "cn-er-postgres"
}

variable "db_name" {
  type        = string
  description = "Name of the application database."
  default     = "productdb"
}

variable "db_user" {
  type        = string
  description = "Name of the application database user."
  default     = "appuser"
}

variable "db_password" {
  type        = string
  description = "Password for the application database user."
  sensitive   = true
}

variable "region" {
  type        = string
  description = "Cloud region for the database instance."
}

variable "deletion_protection" {
  type        = bool
  description = "Prevents accidental instance deletion via Terraform."
  default     = false
}

variable "labels" {
  type        = map(string)
  description = "Labels/tags for cost attribution."
  default = {
    managed-by  = "terraform"
    environment = "dev"
    phase       = "phase5"
  }
}

# ---------------------------------------------------------------------------
# GCP-specific variables
# ---------------------------------------------------------------------------

variable "project_id" {
  type        = string
  description = "GCP Project ID. Required when cloud_provider = 'gcp'."
  default     = ""
}

variable "network_id" {
  type        = string
  description = "GCP VPC network self_link. Required when cloud_provider = 'gcp'."
  default     = ""
}

variable "database_version" {
  type        = string
  description = "PostgreSQL engine version for Cloud SQL."
  default     = "POSTGRES_16"
}

variable "tier" {
  type        = string
  description = "Cloud SQL machine type (e.g. db-f1-micro)."
  default     = "db-f1-micro"
}

variable "private_ip_range_name" {
  type        = string
  description = "Name for the allocated private IP range for VPC peering."
  default     = "cloud-sql-private-ip-range"
}

variable "private_ip_address" {
  type        = string
  description = "Starting IP for the private service range."
  default     = "10.100.0.0"
}

variable "private_ip_prefix_length" {
  type        = number
  description = "Prefix length for the private service range."
  default     = 16
}

# ---------------------------------------------------------------------------
# AWS-specific variables
# ---------------------------------------------------------------------------

variable "db_subnet_group_name" {
  type        = string
  description = "Name of the RDS DB subnet group. Required when cloud_provider = 'aws'."
  default     = "cn-er-db-subnet-group"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for RDS. Required when cloud_provider = 'aws'."
  default     = []
}

variable "vpc_id" {
  type        = string
  description = "AWS VPC ID for the database security group. Required when cloud_provider = 'aws'."
  default     = ""
}

variable "allowed_security_group_id" {
  type        = string
  description = "Security group ID of EKS nodes allowed to connect to RDS."
  default     = ""
}

variable "db_instance_class" {
  type        = string
  description = "RDS instance class (e.g. db.t3.micro)."
  default     = "db.t3.micro"
}

variable "tags" {
  type        = map(string)
  description = "AWS tags for all resources."
  default     = {}
}
