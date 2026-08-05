# modules/kubernetes/outputs.tf

output "cluster_name" {
  description = "The name of the Kubernetes cluster."
  value       = var.cloud_provider == "gcp" ? one(module.gcp[*].cluster_name) : one(module.aws[*].cluster_name)
}

output "cluster_endpoint" {
  description = "The API server endpoint of the Kubernetes cluster."
  value       = var.cloud_provider == "gcp" ? one(module.gcp[*].cluster_endpoint) : one(module.aws[*].cluster_endpoint)
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the cluster."
  value       = var.cloud_provider == "gcp" ? one(module.gcp[*].cluster_ca_certificate) : one(module.aws[*].cluster_ca_certificate)
  sensitive   = true
}

output "get_credentials_command" {
  description = "Command to configure kubectl for this cluster."
  value       = var.cloud_provider == "gcp" ? one(module.gcp[*].get_credentials_command) : one(module.aws[*].get_credentials_command)
}

output "cluster_location" {
  description = "The cloud region where the cluster is deployed."
  value       = var.cloud_provider == "gcp" ? one(module.gcp[*].cluster_location) : var.region
}

output "workload_identity_pool" {
  description = "Workload Identity pool. GCP-specific; empty for AWS (use IRSA instead)."
  value       = var.cloud_provider == "gcp" ? one(module.gcp[*].workload_identity_pool) : ""
}
