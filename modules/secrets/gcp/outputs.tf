# modules/secrets/gcp/outputs.tf

output "secret_id" {
  description = "The Secret Manager secret ID."
  value       = google_secret_manager_secret.secret.secret_id
}

output "secret_name" {
  description = "The full resource name of the secret."
  value       = google_secret_manager_secret.secret.name
}
