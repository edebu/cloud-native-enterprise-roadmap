# modules/database/outputs.tf

output "instance_name" {
  description = "The name of the database instance."
  value       = var.cloud_provider == "gcp" ? one(module.gcp[*].instance_name) : one(module.aws[*].instance_name)
}

output "private_ip_address" {
  description = "Private IP address of the database instance."
  value       = var.cloud_provider == "gcp" ? one(module.gcp[*].private_ip_address) : one(module.aws[*].private_ip_address)
  sensitive   = true
}

output "connection_name" {
  description = "Connection string/name for the database instance."
  value       = var.cloud_provider == "gcp" ? one(module.gcp[*].connection_name) : one(module.aws[*].connection_name)
}

output "database_name" {
  description = "The name of the application database."
  value       = var.cloud_provider == "gcp" ? one(module.gcp[*].database_name) : one(module.aws[*].database_name)
}

output "db_user" {
  description = "The application database user name."
  value       = var.cloud_provider == "gcp" ? one(module.gcp[*].db_user) : one(module.aws[*].db_user)
}
