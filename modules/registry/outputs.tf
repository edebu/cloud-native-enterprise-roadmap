# modules/registry/outputs.tf

output "repository_id" {
  description = "The short ID of the container registry repository."
  value       = var.cloud_provider == "gcp" ? one(module.gcp[*].repository_id) : one(module.aws[*].repository_id)
}

output "repository_url" {
  description = "The Docker-compatible image base URL for the repository."
  value       = var.cloud_provider == "gcp" ? one(module.gcp[*].repository_url) : one(module.aws[*].repository_url)
}
