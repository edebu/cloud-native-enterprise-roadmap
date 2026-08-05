# modules/network/aws/main.tf
#
# AWS Network Implementation
#
# GCP vs AWS equivalence:
#   google_compute_network      → aws_vpc
#   google_compute_subnetwork   → aws_subnet
#   google_compute_router +     → aws_nat_gateway + aws_eip
#     google_compute_router_nat
#   google_compute_firewall     → aws_security_group
#
# CIDR design (avoids conflict with GCP subnets 10.10.x.x):
#   VPC:             10.20.0.0/16
#   Public subnet:   10.20.1.0/24
#   Private subnet:  10.20.2.0/24
#
# ADR: docs/decision-records/010-aws-network-design.md

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = var.network_name
  })
}

# ---------------------------------------------------------------------------
# Internet Gateway — allows outbound internet traffic from public subnet
# (equivalent to the default GCP route via the VPC gateway)
# ---------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.network_name}-igw"
  })
}

# ---------------------------------------------------------------------------
# Public Subnet
# map_public_ip_on_launch = true: instances here get a public IP automatically.
# Used for NAT Gateway (which needs a public IP).
# ---------------------------------------------------------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.network_name}-public-subnet"
    Type = "public"
  })
}

# ---------------------------------------------------------------------------
# Private Subnet
# No public IPs. GKE/EKS nodes live here. Outbound via NAT Gateway.
# Equivalent to GCP private subnet with private_ip_google_access = true.
# ---------------------------------------------------------------------------
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "${var.region}a"

  tags = merge(var.tags, {
    Name = "${var.network_name}-private-subnet"
    Type = "private"
  })
}

# ---------------------------------------------------------------------------
# Elastic IP for NAT Gateway
# NAT Gateway requires a static public IP.
# ---------------------------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.network_name}-nat-eip"
  })

  depends_on = [aws_internet_gateway.main]
}

# ---------------------------------------------------------------------------
# NAT Gateway (in public subnet)
#
# GCP equivalent: Cloud NAT + Cloud Router
# Provides outbound internet access for private subnet resources
# (EKS nodes pulling container images, etc.) without exposing them.
# ---------------------------------------------------------------------------
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = merge(var.tags, {
    Name = "${var.network_name}-nat-gw"
  })

  depends_on = [aws_internet_gateway.main]
}

# ---------------------------------------------------------------------------
# Route Tables
# ---------------------------------------------------------------------------

# Public route table: 0.0.0.0/0 → Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.network_name}-public-rt"
  })
}

# Private route table: 0.0.0.0/0 → NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.network_name}-private-rt"
  })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# ---------------------------------------------------------------------------
# Security Groups
#
# GCP equivalent: google_compute_firewall rules
#   deny_external_ssh  → deny_ssh (ingress port 22 from 0.0.0.0/0)
#   allow_internal     → allow_internal (all traffic within VPC CIDR)
# ---------------------------------------------------------------------------

# Deny external SSH — block port 22 from internet.
# In AWS, security groups are ALLOW-only; there is no explicit deny rule.
# We simply omit port 22 from the allowed ingress rules (default deny).
resource "aws_security_group" "default" {
  name        = "${var.network_name}-default-sg"
  description = "Default security group: allow internal VPC traffic, deny external SSH"
  vpc_id      = aws_vpc.main.id

  # Allow all internal VPC traffic (GCP: allow_internal firewall rule)
  ingress {
    description = "Allow all traffic within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow HTTPS from internet (for load balancer health checks, etc.)
  ingress {
    description = "Allow HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP from internet (for load balancer)
  ingress {
    description = "Allow HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic (equivalent to GCP default egress allow)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NOTE: Port 22 (SSH) is intentionally NOT included in ingress rules.
  # Use AWS Systems Manager Session Manager for shell access instead.

  tags = merge(var.tags, {
    Name = "${var.network_name}-default-sg"
  })
}
