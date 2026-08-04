# modules/kubernetes/aws/outputs.tf

output "cluster_name" {
  description = "The name of the EKS cluster. GCP equivalent: cluster_name."
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "The API server endpoint of the EKS cluster. GCP equivalent: cluster_endpoint."
  value       = aws_eks_cluster.main.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the EKS cluster. GCP equivalent: cluster_ca_certificate."
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "get_credentials_command" {
  description = "Command to configure kubectl for this EKS cluster. GCP equivalent: gcloud container clusters get-credentials."
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.main.name} --region ${var.region}"
}

output "oidc_provider_arn" {
  description = <<-EOT
    ARN of the IAM OIDC provider for IRSA (IAM Roles for Service Accounts).
    GCP equivalent: Workload Identity pool (project_id.svc.id.goog).
    Use this ARN when creating IRSA roles for pod-level AWS access.
  EOT
  value = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider for IRSA."
  value       = aws_iam_openid_connect_provider.cluster.url
}

output "node_group_arn" {
  description = "ARN of the EKS managed node group."
  value       = aws_eks_node_group.main.arn
}
