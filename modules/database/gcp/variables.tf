# modules/cloud-sql/variables.tf

variable "project_id" {
  type        = string
  description = "GCP Project ID."
}

variable "region" {
  type        = string
  description = "GCP region. Instance will be created here. Must match the VPC region."
}

variable "instance_name" {
  type        = string
  description = "Unique name for the Cloud SQL instance within the project."
  default     = "cn-er-postgres"
}

variable "database_version" {
  type        = string
  description = "PostgreSQL engine version. Use POSTGRES_16 for latest LTS."
  default     = "POSTGRES_16"
}

variable "tier" {
  type        = string
  description = <<-EOT
    Machine type for the SQL instance.
    - db-f1-micro : 1 shared vCPU, 614 MB RAM — dev/learning only (~$7-15/mo)
    - db-g1-small : 1 shared vCPU, 1.7 GB RAM — light staging
    - db-custom-2-7680 : 2 vCPU, 7.5 GB RAM — production baseline
  EOT
  default     = "db-f1-micro"
}

variable "network_id" {
  type        = string
  description = <<-EOT
    The self_link (full resource URL) of the VPC network to attach the instance to.
    Cloud SQL uses VPC Peering (Private Service Access) — not subnet-level attachment.
    Format: "https://www.googleapis.com/compute/v1/projects/<proj>/global/networks/<name>"
  EOT
}

variable "private_ip_range_name" {
  type        = string
  description = "Name for the allocated private IP address range used for VPC peering."
  default     = "cloud-sql-private-ip-range"
}

variable "private_ip_address" {
  type        = string
  description = "Starting address for the private service range. Must not overlap with existing subnets."
  default     = "10.100.0.0"
}

variable "private_ip_prefix_length" {
  type        = number
  description = "Prefix length for the private service range. /16 gives GCP 65k IPs to assign from."
  default     = 16
}

variable "db_name" {
  type        = string
  description = "Name of the application database to create."
  default     = "productdb"
}

variable "db_user" {
  type        = string
  description = "Name of the application database user."
  default     = "appuser"
}

variable "db_password" {
  type        = string
  description = "Password for the application database user. Pass a randomly generated value — see environments/dev/terraform/cloud-sql/main.tf."
  sensitive   = true
}

variable "deletion_protection" {
  type        = bool
  description = "Prevents accidental instance deletion via Terraform. Always true in production."
  default     = false
}

variable "labels" {
  type        = map(string)
  description = "Labels for cost attribution."
  default = {
    managed-by  = "terraform"
    environment = "dev"
    phase       = "phase2"
  }
}
