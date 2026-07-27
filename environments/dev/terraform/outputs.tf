output "vpc_id" {
  value       = module.network.network_id
  description = "VPC ID created in dev environment"
}

output "private_subnet" {
  value       = module.network.private_subnet_name
  description = "Private subnet name"
}