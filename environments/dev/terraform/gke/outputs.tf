output "cluster_name" {
  description = "GKE Autopilot cluster name."
  value       = module.gke.cluster_name
}

output "cluster_location" {
  description = "GCP region where the cluster is deployed."
  value       = module.gke.cluster_location
}

output "get_credentials_command" {
  description = "Run this to configure kubectl for the cluster."
  value       = module.gke.get_credentials_command
}

output "workload_identity_pool" {
  description = "Workload Identity pool for KSA -> GSA bindings (Phase 3)."
  value       = module.gke.workload_identity_pool
}
