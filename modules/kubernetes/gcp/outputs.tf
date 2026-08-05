# modules/gke/outputs.tf

output "cluster_name" {
  description = "The name of the GKE Autopilot cluster."
  value       = google_container_cluster.main.name
}

output "cluster_endpoint" {
  description = <<-EOT
    The IP address of the cluster's Kubernetes API server.
    Used by kubectl and CI/CD pipelines to reach the control plane.
  EOT
  value     = google_container_cluster.main.endpoint
  sensitive = true
}

output "cluster_ca_certificate" {
  description = <<-EOT
    Base64-encoded public certificate of the cluster's certificate authority.
    Required by kubectl and Kubernetes provider to verify the API server TLS cert.
  EOT
  value     = google_container_cluster.main.master_auth[0].cluster_ca_certificate
  sensitive = true
}

output "cluster_location" {
  description = "The GCP region where the cluster is deployed."
  value       = google_container_cluster.main.location
}

output "workload_identity_pool" {
  description = <<-EOT
    The Workload Identity pool for this cluster.
    Used when binding Kubernetes Service Accounts (KSA) to GCP Service Accounts (GSA).
    Format: <project_id>.svc.id.goog
  EOT
  value = google_container_cluster.main.workload_identity_config[0].workload_pool
}

output "get_credentials_command" {
  description = <<-EOT
    Run this command locally to configure kubectl to communicate with the cluster.
    Requires gcloud CLI and appropriate IAM permissions (roles/container.developer or higher).
  EOT
  value = "gcloud container clusters get-credentials ${google_container_cluster.main.name} --region ${google_container_cluster.main.location} --project ${google_container_cluster.main.project}"
}
