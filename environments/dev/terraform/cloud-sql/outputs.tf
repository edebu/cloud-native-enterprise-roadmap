output "instance_name" {
  description = "Cloud SQL instance name."
  value       = module.cloud_sql.instance_name
}

output "connection_name" {
  description = "Connection name for Cloud SQL Auth Proxy: <project>:<region>:<instance>."
  value       = module.cloud_sql.connection_name
}

output "database_name" {
  description = "Application database name."
  value       = module.cloud_sql.database_name
}

output "db_user" {
  description = "Application database user."
  value       = module.cloud_sql.db_user
}

output "secret_manager_secret_id" {
  description = <<-EOT
    Secret Manager secret ID for the DB password.
    Access the password:
      gcloud secrets versions access latest --secret=cn-er-dev-db-password
  EOT
  value = google_secret_manager_secret.db_password.secret_id
}

output "k8s_env_config" {
  description = <<-EOT
    Environment variable values to configure the Product Catalog API K8s deployment.
    DB_HOST is the private IP — retrieve after apply:
      terraform output -raw private_ip (sensitive, use: terraform output private_ip)
  EOT
  value = {
    DB_NAME = module.cloud_sql.database_name
    DB_USER = module.cloud_sql.db_user
    DB_PORT = "5432"
  }
}
