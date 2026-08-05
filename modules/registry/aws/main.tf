# modules/registry/aws/main.tf
#
# AWS Elastic Container Registry (ECR)
#
# GCP equivalent: Google Artifact Registry (GAR)
#
# ADR: docs/decision-records/009-multi-cloud-strategy.md (registry mapping)

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# ECR Repository
#
# GCP equivalent: google_artifact_registry_repository (DOCKER format)
# ---------------------------------------------------------------------------
resource "aws_ecr_repository" "main" {
  name                 = var.repository_id
  image_tag_mutability = var.image_tag_mutability

  # GCP: GAR encrypts by default (Google-managed keys)
  # AWS: ECR encryption with AWS managed KMS key
  encryption_configuration {
    encryption_type = "AES256"
  }

  # Enable image scanning on push (no direct GCP equivalent — GAR uses
  # artifact analysis separately; ECR has built-in basic scanning)
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Name        = var.repository_id
    Description = var.description
  })
}

# ---------------------------------------------------------------------------
# Lifecycle Policy
#
# GCP equivalent: no built-in equivalent — GAR doesn't auto-delete old images.
# AWS ECR lifecycle policy removes untagged images after 30 days to reduce
# storage costs in the dev environment.
# ---------------------------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images older than 30 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 30
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}
