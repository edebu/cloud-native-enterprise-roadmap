# modules/database/aws/outputs.tf

output "instance_name" {
  description = "The identifier of the RDS instance. GCP equivalent: instance_name."
  value       = aws_db_instance.main.identifier
}

output "private_ip_address" {
  description = "Private endpoint hostname of the RDS instance. GCP equivalent: private_ip_address."
  value       = aws_db_instance.main.address
  sensitive   = true
}

output "connection_name" {
  description = "Connection endpoint (host:port). GCP equivalent: connection_name."
  value       = "${aws_db_instance.main.address}:${aws_db_instance.main.port}"
}

output "database_name" {
  description = "The name of the application database."
  value       = aws_db_instance.main.db_name
}

output "db_user" {
  description = "The application database user name."
  value       = aws_db_instance.main.username
}

output "secret_arn" {
  description = "ARN of the AWS Secrets Manager secret holding the DB password."
  value       = aws_secretsmanager_secret.db_password.arn
}
