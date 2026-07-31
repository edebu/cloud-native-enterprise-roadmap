# modules/artifact-registry/outputs.tf

output "repository_id" {
  description = "The short ID of the Artifact Registry repository."
  value       = google_artifact_registry_repository.docker_repo.repository_id
}

output "repository_name" {
  description = "The full resource name of the repository."
  value       = google_artifact_registry_repository.docker_repo.name
}

output "repository_url" {
  description = <<-EOT
    The Docker-compatible image base URL for this repository.

    Use this as the prefix for image tags and `docker push` commands:
      docker tag myapp:local <repository_url>/myapp:v1.0.0
      docker push <repository_url>/myapp:v1.0.0
  EOT
  value = format(
    "%s-docker.pkg.dev/%s/%s",
    google_artifact_registry_repository.docker_repo.location,
    google_artifact_registry_repository.docker_repo.project,
    google_artifact_registry_repository.docker_repo.repository_id,
  )
}
