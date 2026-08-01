terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }

  # Separate state from the base infrastructure (network, IAM, GAR).
  # Using the same GCS bucket with a different prefix keeps all state
  # in one place while avoiding state file conflicts between phases.
  #
  # Phase 1 state: gs://cn-er-terraform-state-bucket-dev/env/dev
  # Phase 2 GKE:   gs://cn-er-terraform-state-bucket-dev/env/dev/gke
  backend "gcs" {
    bucket = "cn-er-terraform-state-bucket-dev"
    prefix = "env/dev/gke"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${module.gke.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.cluster_endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
  }
}
