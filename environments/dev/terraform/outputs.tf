output "vpc_id" {
  value       = module.network.network_id
  description = "VPC ID created in dev environment"
}

output "private_subnet" {
  value       = module.network.private_subnet_name
  description = "Private subnet name"
}

output "service_account_email" {
  value       = module.iam.service_account_email
  description = "Created service account email"
}

output "artifact_registry_url" {
  description = <<-EOT
    Docker image base URL for the Artifact Registry repository.
    Use this prefix when tagging and pushing images:
      docker tag product-catalog-api:local <artifact_registry_url>/product-catalog-api:v0.1.0
      docker push <artifact_registry_url>/product-catalog-api:v0.1.0
  EOT
  value       = module.artifact_registry.repository_url
}