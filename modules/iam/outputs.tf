# modules/iam/outputs.tf

output "service_account_email" {
  description = "The email (GCP) or ARN (AWS) of the created service account/role."
  value       = var.cloud_provider == "gcp" ? one(module.gcp[*].service_account_email) : one(module.aws[*].role_arn)
}
