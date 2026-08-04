# modules/secrets/aws/outputs.tf

output "secret_id" {
  description = "The name/ID of the AWS Secrets Manager secret. GCP equivalent: secret_id."
  value       = aws_secretsmanager_secret.main.name
}

output "secret_arn" {
  description = "ARN of the AWS Secrets Manager secret. GCP equivalent: secret_name (full resource name)."
  value       = aws_secretsmanager_secret.main.arn
}

output "eso_policy_arn" {
  description = "ARN of the IAM policy granting ESO read access to this secret."
  value       = aws_iam_policy.eso_secret_read.arn
}
