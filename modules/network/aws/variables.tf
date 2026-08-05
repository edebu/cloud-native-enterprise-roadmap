# modules/network/aws/variables.tf

variable "region" {
  type        = string
  description = "AWS region where network resources will be created. eu-central-1 = Frankfurt (GCP europe-west3 equivalent)."
}

variable "network_name" {
  type        = string
  description = "Name prefix for all network resources (VPC, subnets, gateway)."
  default     = "cn-er-enterprise-vpc"
}

variable "vpc_cidr" {
  type        = string
  description = <<-EOT
    CIDR block for the AWS VPC.
    Chosen to avoid conflict with GCP CIDR ranges:
      GCP public subnet:   10.10.1.0/24
      GCP private subnet:  10.10.2.0/24
      GCP master CIDR:     172.16.0.0/28
    AWS VPC: 10.20.0.0/16 — safely isolated.
  EOT
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR block for the public subnet. Must be within vpc_cidr."
  default     = "10.20.1.0/24"
}

variable "private_subnet_cidr" {
  type        = string
  description = "CIDR block for the private subnet. EKS nodes reside here."
  default     = "10.20.2.0/24"
}

variable "tags" {
  type        = map(string)
  description = "AWS tags to apply to all resources."
  default = {
    ManagedBy   = "terraform"
    Environment = "dev"
    Phase       = "phase5"
  }
}
