# modules/secrets/outputs.tf

output "secret_id" {
  description = "The ID/name of the created secret."
  value       = var.cloud_provider == "gcp" ? one(module.gcp[*].secret_id) : one(module.aws[*].secret_id)
}

output "secret_name" {
  description = "The full resource name/ARN of the secret."
  value       = var.cloud_provider == "gcp" ? one(module.gcp[*].secret_name) : one(module.aws[*].secret_arn)
}
