# modules/iam/variables.tf
#
# Cloud-agnostic IAM module interface.
# GCP: Google Service Accounts + Project IAM bindings
# AWS: IAM Roles + Instance Profiles + Policy attachments

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

variable "service_account_id" {
  type        = string
  description = "Unique ID/name for the service account or IAM role."
  default     = "devops-sa"
}

variable "display_name" {
  type        = string
  description = "Human-readable display name for the service account or IAM role."
  default     = "DevOps Automation Service Account"
}

# ---------------------------------------------------------------------------
# GCP-specific variables
# ---------------------------------------------------------------------------

variable "project_id" {
  type        = string
  description = "GCP Project ID. Required when cloud_provider = 'gcp'."
  default     = ""
}

# ---------------------------------------------------------------------------
# AWS-specific variables
# ---------------------------------------------------------------------------

variable "assume_role_principals" {
  type        = list(string)
  description = "List of AWS service principals that can assume the role (e.g. ec2.amazonaws.com)."
  default     = ["ec2.amazonaws.com"]
}

variable "managed_policy_arns" {
  type        = list(string)
  description = "List of AWS managed policy ARNs to attach to the role."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "AWS tags for all resources."
  default     = {}
}
