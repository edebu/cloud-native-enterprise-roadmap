# Multi-Cloud Usage Guide

Bu kılavuz, CN-ER repository'sindeki cloud-agnostic Terraform modüllerinin nasıl kullanılacağını açıklar. Phase 5 ile eklenen wrapper pattern sayesinde aynı modüller hem GCP hem de AWS üzerinde çalışabilir.

---

## Temel Konsept: `cloud_provider` Flag'i

Her üst-seviye modül bir `cloud_provider` değişkeni alır:

```hcl
module "network" {
  source         = "path/to/modules/network"
  cloud_provider = "gcp"   # veya "aws"
  ...
}
```

Bu değer `"gcp"` olduğunda modül `./gcp/` sub-modülünü, `"aws"` olduğunda `./aws/` sub-modülünü çağırır. Diğer tüm modül çağrı kodu değişmeden kalır.

---

## GCP Kullanımı (Mevcut — Aktif Environment)

`environments/dev/terraform/main.tf` zaten `cloud_provider = "gcp"` ile yapılandırılmıştır:

```hcl
module "network" {
  source = "../../../modules/network"

  cloud_provider      = "gcp"
  project_id          = var.project_id
  region              = var.region
  network_name        = "dev-enterprise-vpc"
  public_subnet_cidr  = "10.10.1.0/24"
  private_subnet_cidr = "10.10.2.0/24"
}

module "artifact_registry" {
  source = "../../../modules/registry"

  cloud_provider  = "gcp"
  project_id      = var.project_id
  region          = var.region
  repository_id   = "app-images"
  writer_service_accounts = [
    "serviceAccount:devops-automation-sa@${var.project_id}.iam.gserviceaccount.com",
  ]
}
```

Mevcut GCP ortamını provision etmek için:

```bash
cd environments/dev/terraform
terraform init
terraform apply -var="project_id=YOUR_GCP_PROJECT_ID"
```

---

## AWS Kullanımı (Kod + Plan — Aktif Deployment Yok)

AWS modüllerini kullanmak için yeni bir environment klasörü oluşturmanız gerekir. Aşağıda örnek bir `environments/dev-aws/terraform/main.tf` yapısı verilmiştir:

### Ön Koşullar

1. **AWS credentials yapılandır:**
   ```bash
   export AWS_ACCESS_KEY_ID=AKIA...
   export AWS_SECRET_ACCESS_KEY=...
   export AWS_DEFAULT_REGION=eu-central-1
   ```
   veya `~/.aws/credentials` dosyası

2. **AWS provider ekle** (`providers.tf`):
   ```hcl
   terraform {
     required_providers {
       aws = {
         source  = "hashicorp/aws"
         version = "~> 5.0"
       }
     }
   }

   provider "aws" {
     region = var.region
   }
   ```

### Örnek `main.tf` (AWS)

```hcl
# environments/dev-aws/terraform/main.tf

locals {
  tags = {
    ManagedBy   = "terraform"
    Environment = "dev"
    Phase       = "phase5"
    Project     = "cn-er"
  }
}

# Network — AWS VPC + subnets + NAT Gateway
module "network" {
  source = "../../../modules/network"

  cloud_provider      = "aws"
  region              = var.region
  network_name        = "cn-er-enterprise-vpc"
  vpc_cidr            = "10.20.0.0/16"
  public_subnet_cidr  = "10.20.1.0/24"
  private_subnet_cidr = "10.20.2.0/24"
  tags                = local.tags
}

# Container Registry — ECR
module "registry" {
  source = "../../../modules/registry"

  cloud_provider = "aws"
  repository_id  = "app-images/product-catalog-api"
  tags           = local.tags
}

# IAM — DevOps role
module "iam" {
  source = "../../../modules/iam"

  cloud_provider     = "aws"
  service_account_id = "devops-automation-role"
  display_name       = "DevOps Automation Role for Dev"
  assume_role_principals = ["ec2.amazonaws.com"]
  tags               = local.tags
}

# Kubernetes — EKS
module "kubernetes" {
  source = "../../../modules/kubernetes"

  cloud_provider     = "aws"
  cluster_name       = "cn-er-dev-eks"
  region             = var.region
  vpc_id             = module.network.network_id
  subnet_ids         = [module.network.private_subnet_name]
  node_instance_type = "t3.medium"
  node_desired_size  = 2
  node_min_size      = 1
  node_max_size      = 3
  tags               = local.tags
}

# Database — RDS PostgreSQL
module "database" {
  source = "../../../modules/database"

  cloud_provider   = "aws"
  instance_name    = "cn-er-dev-postgres"
  region           = var.region
  db_name          = "productdb"
  db_user          = "appuser"
  db_password      = var.db_password  # sensitive
  db_instance_class = "db.t3.micro"
  db_subnet_group_name = "cn-er-db-subnet-group"
  subnet_ids       = [module.network.private_subnet_name]
  vpc_id           = module.network.network_id
  tags             = local.tags
}

# Secrets — AWS Secrets Manager
module "secrets" {
  source = "../../../modules/secrets"

  cloud_provider = "aws"
  secret_id      = "cn-er-dev-db-password"
  secret_value   = var.db_password
  tags           = local.tags
}
```

### Terraform Plan (Doğrulama)

```bash
# Sadece plan çalıştır (gerçek deployment yok)
cd environments/dev-aws/terraform
terraform init
terraform plan -var="db_password=PLACEHOLDER"
```

---

## Modül Çıktıları — Aynı Interface

Her iki cloud_provider için aynı output isimleri kullanılır:

```hcl
# Hangi cloud olursa olsun aynı şekilde referans verilir
output "cluster_endpoint" {
  value = module.kubernetes.cluster_endpoint
}

output "registry_url" {
  value = module.registry.repository_url
}

output "db_private_ip" {
  value = module.database.private_ip_address
}
```

---

## GCP ↔ AWS Fark Tablosu

| Değişken | GCP | AWS | Açıklama |
|:---------|:----|:----|:---------|
| Network ID | VPC name (string) | VPC ID (`vpc-xxxxxxxx`) | AWS uses resource IDs, GCP uses names |
| Subnet reference | Subnet name (string) | Subnet ID (`subnet-xxxxxxxx`) | Same difference |
| Pod cloud auth | Workload Identity annotation | IRSA (OIDC) annotation | Different annotation key but same concept |
| Cluster kubeconfig | `gcloud ... get-credentials` | `aws eks update-kubeconfig` | Provider-specific CLI |

---

## CI/CD ile Entegrasyon

GitHub Actions workflows, her iki cloud'a deploy etmek için ayrı job'larla genişletilebilir:

```yaml
# Gelecekte: cd.yml'de AWS job
deploy-aws:
  needs: build-push
  if: github.ref == 'refs/heads/main'
  steps:
    - uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: arn:aws:iam::ACCOUNT:role/github-actions-role
        aws-region: eu-central-1
    - run: aws eks update-kubeconfig --name cn-er-dev-eks --region eu-central-1
    - run: argocd app sync product-catalog-api
```

---

## İlgili ADR'ler

| ADR | İçerik |
|:----|:-------|
| [ADR 009](decision-records/009-multi-cloud-strategy.md) | Multi-cloud module strategy ve wrapper pattern tasarımı |
| [ADR 010](decision-records/010-aws-network-design.md) | AWS VPC tasarımı ve GCP karşılaştırması |
| [ADR 011](decision-records/011-eks-vs-gke-tradeoffs.md) | EKS vs GKE Autopilot, IRSA vs Workload Identity |
| [ADR 012](decision-records/012-rds-vs-cloud-sql.md) | RDS vs Cloud SQL, networking farkları |
| [ADR 013](decision-records/013-github-actions-cicd.md) | GitHub Actions CI/CD pipeline tasarımı |
| [ADR 014](decision-records/014-aws-iam-vs-gcp-iam.md) | AWS IAM vs GCP IAM detaylı karşılaştırma |
