# modules/kubernetes/aws/main.tf
#
# AWS EKS Managed Node Group
#
# GCP equivalent: GKE Autopilot Cluster
#
# Key differences:
#   - GKE Autopilot: fully managed nodes, per-Pod billing, no node config
#   - EKS: managed control plane + managed node group (EC2 instances)
#   - GKE Workload Identity → EKS IRSA (IAM Roles for Service Accounts)
#   - GKE release channel → EKS k8s_version pinning
#
# ADR: docs/decision-records/011-eks-vs-gke-tradeoffs.md

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# IAM Role — EKS Cluster
#
# The EKS control plane needs permission to manage AWS resources on behalf
# of the cluster. This is the AWS equivalent of GKE's built-in service
# account — in GCP this is implicit; in AWS it must be explicit.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })

  tags = merge(var.tags, { Name = "${var.cluster_name}-cluster-role" })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# ---------------------------------------------------------------------------
# EKS Cluster
#
# GCP equivalent: google_container_cluster (enable_autopilot = true)
# ---------------------------------------------------------------------------
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true # Same as GKE: public endpoint for kubectl

    # GCP: master_authorized_networks_config
    # AWS: no built-in IP allowlist on the cluster resource itself;
    # security groups and NACLs handle access control.
    security_group_ids = [var.cluster_security_group_id]
  }

  tags = merge(var.tags, { Name = var.cluster_name })

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

# ---------------------------------------------------------------------------
# OIDC Provider for IRSA (IAM Roles for Service Accounts)
#
# GCP equivalent: Workload Identity (google_service_account_iam_member with
# serviceAccount:{project}.svc.id.goog[{namespace}/{ksa}] binding)
#
# IRSA allows Kubernetes pods to assume AWS IAM roles without static credentials,
# the same concept as GCP's KSA → GSA binding via Workload Identity.
# ---------------------------------------------------------------------------
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = var.tags
}

# ---------------------------------------------------------------------------
# IAM Role — EKS Node Group
#
# Each managed node runs as this IAM role. Equivalent to the default Compute
# Engine SA in GKE (project_number-compute@developer.gserviceaccount.com).
# ---------------------------------------------------------------------------
resource "aws_iam_role" "node_group" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = merge(var.tags, { Name = "${var.cluster_name}-node-role" })
}

resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_ecr_readonly" {
  # GCP equivalent: google_artifact_registry_repository_iam_member (reader)
  # Allows nodes to pull container images from ECR without static credentials.
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

# ---------------------------------------------------------------------------
# EKS Managed Node Group
#
# GCP equivalent: GKE Autopilot manages nodes automatically.
# In EKS we define a managed node group — AWS handles node provisioning,
# patching, and scaling, but we specify the EC2 instance type.
# ---------------------------------------------------------------------------
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.subnet_ids
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-node-group" })

  depends_on = [
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_ecr_readonly,
  ]
}
