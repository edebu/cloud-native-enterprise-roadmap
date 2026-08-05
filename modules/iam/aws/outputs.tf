# modules/iam/aws/outputs.tf

output "role_arn" {
  description = "ARN of the IAM role. GCP equivalent: service_account_email."
  value       = aws_iam_role.main.arn
}

output "role_name" {
  description = "Name of the IAM role."
  value       = aws_iam_role.main.name
}

output "instance_profile_name" {
  description = "Name of the IAM instance profile (for EC2/EKS node attachment)."
  value       = aws_iam_instance_profile.main.name
}
