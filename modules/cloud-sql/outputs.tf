# modules/cloud-sql/outputs.tf

output "instance_name" {
  description = "The name of the Cloud SQL instance."
  value       = google_sql_database_instance.main.name
}

output "private_ip_address" {
  description = <<-EOT
    Private IP address of the Cloud SQL instance.
    GKE pods use this as DB_HOST when connecting from within the VPC.
    Not reachable from outside the VPC (no public IP).
  EOT
  value     = google_sql_database_instance.main.private_ip_address
  sensitive = true
}

output "connection_name" {
  description = <<-EOT
    Instance connection name in format: <project>:<region>:<instance>.
    Used by Cloud SQL Auth Proxy (Phase 3) for IAM-authenticated connections.
  EOT
  value = google_sql_database_instance.main.connection_name
}

output "database_name" {
  description = "The name of the application database."
  value       = google_sql_database.app_db.name
}

output "db_user" {
  description = "The application database user name."
  value       = google_sql_user.app_user.name
}
