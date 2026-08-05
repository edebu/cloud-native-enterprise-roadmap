# modules/registry/aws/outputs.tf

output "repository_id" {
  description = "The short name of the ECR repository. GCP equivalent: repository_id."
  value       = aws_ecr_repository.main.name
}

output "repository_url" {
  description = <<-EOT
    The full ECR repository URI. GCP equivalent: repository_url.
    Format: <account_id>.dkr.ecr.<region>.amazonaws.com/<name>
    Use as the prefix for docker tag and docker push commands.
  EOT
  value = aws_ecr_repository.main.repository_url
}

output "repository_arn" {
  description = "ARN of the ECR repository."
  value       = aws_ecr_repository.main.arn
}
