output "network_id" {
  value       = google_compute_network.vpc.id
  description = "The ID of the VPC being created"
}

output "public_subnet_name" {
  value       = google_compute_subnetwork.public_subnet.name
  description = "The name of the public subnet"
}

output "private_subnet_name" {
  value       = google_compute_subnetwork.private_subnet.name
  description = "The name of the private subnet"
}