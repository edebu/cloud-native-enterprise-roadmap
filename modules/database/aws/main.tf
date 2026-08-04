# modules/database/aws/main.tf
#
# AWS RDS PostgreSQL (private, no public IP)
#
# GCP equivalent: Cloud SQL PostgreSQL (Private Service Access)
#
# Key differences:
#   - GCP: Private Service Access (VPC Peering) — separate network plane
#   - AWS: DB Subnet Group in private subnets — same VPC plane
#   - GCP: password via Secret Manager (external to module)
#   - AWS: password via aws_secretsmanager_secret (can be in-module)
#   - GCP: Cloud SQL Auth Proxy optional
#   - AWS: Direct connection to private IP in same VPC (no proxy needed for private)
#
# ADR: docs/decision-records/012-rds-vs-cloud-sql.md

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# DB Subnet Group
#
# RDS requires a subnet group specifying which subnets the instance can use.
# GCP equivalent: private_network = var.network_id (VPC-level peering).
# We use private subnets so the instance has no public IP exposure.
# ---------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name        = var.db_subnet_group_name
  description = "RDS subnet group for ${var.instance_name} — private subnets only"
  subnet_ids  = var.subnet_ids

  tags = merge(var.tags, {
    Name = var.db_subnet_group_name
  })
}

# ---------------------------------------------------------------------------
# Security Group for RDS
#
# GCP equivalent: VPC peering + Cloud SQL's private IP = no SG needed.
# In AWS, security groups explicitly control DB access.
# We only allow traffic from the EKS node security group (least privilege).
# ---------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${var.instance_name}-rds-sg"
  description = "Allow PostgreSQL access only from EKS nodes"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_id != "" ? [var.allowed_security_group_id] : []
    cidr_blocks     = var.allowed_security_group_id == "" ? ["10.20.0.0/16"] : []
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.instance_name}-rds-sg"
  })
}

# ---------------------------------------------------------------------------
# RDS PostgreSQL Instance
#
# GCP equivalent: google_sql_database_instance
# ---------------------------------------------------------------------------
resource "aws_db_instance" "main" {
  identifier = var.instance_name

  # Engine
  engine               = "postgres"
  engine_version       = "15"         # GCP equivalent: database_version = "POSTGRES_16"
  instance_class       = var.db_instance_class  # GCP equivalent: tier = "db-f1-micro"

  # Storage
  allocated_storage     = 20
  max_allocated_storage = 100         # Auto-scaling storage (GCP: automatic)
  storage_type          = "gp2"
  storage_encrypted     = true        # GCP: encrypted by default

  # Database
  db_name  = var.db_name              # GCP: google_sql_database.app_db.name
  username = var.db_user              # GCP: google_sql_user.app_user.name
  password = var.db_password          # GCP: google_sql_user.app_user.password

  # Network — private only (no public IP)
  # GCP equivalent: ipv4_enabled = false
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false      # GCP equivalent: ipv4_enabled = false

  # Backup
  # GCP equivalent: backup_configuration { enabled = true, start_time = "02:00" }
  backup_retention_period = 7
  backup_window           = "02:00-03:00"
  maintenance_window      = "Sun:03:00-Sun:04:00" # GCP: maintenance_window { day = 7, hour = 3 }

  # Protection
  deletion_protection = var.deletion_protection    # GCP: deletion_protection = false

  # Lifecycle — don't recreate on password change (same as GCP ignore_changes = [password])
  lifecycle {
    ignore_changes = [password]
  }

  tags = merge(var.tags, {
    Name = var.instance_name
  })
}

# ---------------------------------------------------------------------------
# Store DB password in AWS Secrets Manager
# (GCP equivalent: google_secret_manager_secret + version in cloud-sql/main.tf)
# ---------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "db_password" {
  name        = "${var.instance_name}-db-password"
  description = "Database password for ${var.instance_name} RDS instance"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password

  lifecycle {
    ignore_changes = [secret_string]
  }
}
