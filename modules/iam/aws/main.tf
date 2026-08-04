# modules/iam/aws/main.tf
#
# AWS IAM Role with Instance Profile
#
# GCP equivalent: google_service_account + google_project_iam_member
#
# ADR: docs/decision-records/014-aws-iam-vs-gcp-iam.md

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# IAM Role
#
# GCP equivalent: google_service_account
# In AWS, a Role is the principal; in GCP, a Service Account is the principal.
# Both can be granted permissions to call cloud APIs.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "main" {
  name        = var.role_name
  description = var.display_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      for principal in var.assume_role_principals : {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { Service = principal }
      }
    ]
  })

  tags = merge(var.tags, { Name = var.role_name })
}

# ---------------------------------------------------------------------------
# Managed Policy Attachments
#
# GCP equivalent: google_project_iam_member (roles/storage.objectViewer, etc.)
# Attaches AWS managed policies to the role.
# ---------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.main.name
  policy_arn = each.value
}

# ---------------------------------------------------------------------------
# Instance Profile (needed for EC2/EKS nodes)
#
# GCP equivalent: Service Account is attached to VM directly; in AWS this
# requires an intermediate Instance Profile resource.
# ---------------------------------------------------------------------------
resource "aws_iam_instance_profile" "main" {
  name = "${var.role_name}-instance-profile"
  role = aws_iam_role.main.name

  tags = var.tags
}
