terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Separate state from base infra and GKE.
  # State layout:
  #   Base (network, IAM, GAR) : gs://cn-er-terraform-state-bucket-dev/env/dev
  #   GKE                       : gs://cn-er-terraform-state-bucket-dev/env/dev/gke
  #   Cloud SQL                 : gs://cn-er-terraform-state-bucket-dev/env/dev/cloud-sql
  backend "gcs" {
    bucket = "cn-er-terraform-state-bucket-dev"
    prefix = "env/dev/cloud-sql"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "random" {}
