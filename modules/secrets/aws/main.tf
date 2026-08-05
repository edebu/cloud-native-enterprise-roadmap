# modules/secrets/aws/main.tf
#
# AWS Secrets Manager
#
# GCP equivalent: Google Secret Manager
#
# Used by ESO (External Secrets Operator) to sync secrets into Kubernetes.
# ESO on AWS uses IRSA to authenticate to Secrets Manager.
# ESO on GCP uses Workload Identity to authenticate to Secret Manager.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Secret
#
# GCP equivalent: google_secret_manager_secret
# ---------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "main" {
  name        = var.secret_id
  description = "Managed by Terraform — ESO reads this secret for Kubernetes workloads"

  # Auto-rotate: not configured here (requires Lambda function for rotation)
  # GCP equivalent: Secret Manager does not auto-rotate either.

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Secret Version (initial value)
#
# GCP equivalent: google_secret_manager_secret_version
# ---------------------------------------------------------------------------
resource "aws_secretsmanager_secret_version" "main" {
  secret_id     = aws_secretsmanager_secret.main.id
  secret_string = var.secret_value

  # Don't re-create the version if the value is rotated externally
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ---------------------------------------------------------------------------
# IAM Policy for ESO (IRSA)
#
# GCP equivalent: google_secret_manager_secret_iam_member with
#   roles/secretmanager.secretAccessor on the ESO KSA's GSA
#
# In AWS, ESO uses IRSA to assume this policy's IAM role.
# The role ARN is annotated on the ESO Kubernetes Service Account:
#   eks.amazonaws.com/role-arn: <role_arn>
# ---------------------------------------------------------------------------
resource "aws_iam_policy" "eso_secret_read" {
  name        = "${var.secret_id}-eso-read-policy"
  description = "Allows ESO to read the ${var.secret_id} secret from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = aws_secretsmanager_secret.main.arn
    }]
  })

  tags = var.tags
}
