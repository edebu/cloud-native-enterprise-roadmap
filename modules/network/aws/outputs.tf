# modules/network/aws/outputs.tf

output "network_id" {
  description = "The ID of the AWS VPC. Equivalent to GCP network_id."
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "The ID of the public subnet. GCP equivalent: public_subnet_name."
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "The ID of the private subnet. GCP equivalent: private_subnet_name."
  value       = aws_subnet.private.id
}

output "nat_gateway_id" {
  description = "The ID of the NAT Gateway. GCP equivalent: Cloud NAT (no direct ID output in GCP module)."
  value       = aws_nat_gateway.main.id
}

output "default_security_group_id" {
  description = "The ID of the default VPC security group."
  value       = aws_security_group.default.id
}
