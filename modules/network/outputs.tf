# modules/network/outputs.tf
#
# Cloud-agnostic outputs — the same output names are exposed regardless of
# which cloud_provider is active. Callers reference these outputs without
# knowing which cloud is underneath.

output "network_id" {
  description = "The ID/ARN of the VPC or virtual network."
  value       = var.cloud_provider == "gcp" ? one(module.gcp[*].network_id) : one(module.aws[*].network_id)
}

output "public_subnet_name" {
  description = "The name/ID of the public subnet."
  value       = var.cloud_provider == "gcp" ? one(module.gcp[*].public_subnet_name) : one(module.aws[*].public_subnet_id)
}

output "private_subnet_name" {
  description = "The name/ID of the private subnet."
  value       = var.cloud_provider == "gcp" ? one(module.gcp[*].private_subnet_name) : one(module.aws[*].private_subnet_id)
}
