# environments/dev/terraform/gke/main.tf
#
# GKE Autopilot cluster — wires the module to existing Phase 1 resources
# via data sources (no terraform_remote_state coupling).
#
# Why data sources instead of terraform_remote_state?
#   - Decoupled: this state can be destroyed/recreated without touching Phase 1.
#   - Explicit: the network names are visible here, not buried in another state.
#   - Portable: works even if the network was created manually or by another tool.

# ---------------------------------------------------------------------------
# Data sources — look up Phase 1 resources by name
# ---------------------------------------------------------------------------

# Reads the existing VPC created in Phase 1 to get its self_link.
data "google_compute_network" "vpc" {
  project = var.project_id
  name    = "dev-enterprise-vpc"
}

# Reads the private subnet. GKE nodes will be placed here.
data "google_compute_subnetwork" "private" {
  project = var.project_id
  region  = var.region
  name    = "dev-enterprise-vpc-private-subnet"
}

# Reads the existing GAR repository to bind the node SA as reader.
# This avoids hardcoding the repository resource ID across state files.
data "google_artifact_registry_repository" "app_images" {
  project       = var.project_id
  location      = var.region
  repository_id = "app-images"
}

# Resolves the project number — needed to construct the default compute SA email.
# The default Compute Engine SA format is:
#   <project_number>-compute@developer.gserviceaccount.com
data "google_project" "project" {
  project_id = var.project_id
}

# ---------------------------------------------------------------------------
# GKE Autopilot Cluster
# ---------------------------------------------------------------------------
module "gke" {
  source = "../../../../modules/gke"

  project_id      = var.project_id
  region          = var.region
  cluster_name    = "cn-er-dev-autopilot"
  network_name    = data.google_compute_network.vpc.name
  subnetwork_name = data.google_compute_subnetwork.private.name

  # 172.16.0.0/28 is reserved for GKE control plane peering.
  # Does not conflict with 10.10.x.x subnets from Phase 1.
  master_ipv4_cidr_block = "172.16.0.0/28"

  # Restrict who can reach the public control plane endpoint.
  # Empty = no restriction during development (see ADR 004 for trade-off).
  # Add your static IP: { cidr_block = "x.x.x.x/32", display_name = "my-ip" }
  authorized_networks = []

  deletion_protection = false

  labels = {
    managed-by  = "terraform"
    environment = "dev"
    phase       = "phase2"
  }
}

# ---------------------------------------------------------------------------
# GAR IAM — Grant the default Compute Engine SA read access to pull images.
#
# GKE Autopilot nodes run as the default compute SA unless a custom SA is
# configured (requires Standard mode). Granting reader access here allows
# nodes to pull images from our private GAR repository without authentication
# at the kubelet level.
#
# In Phase 3, Workload Identity will handle per-Pod SA binding for finer
# control — but for the initial deployment we use the node-level SA.
# ---------------------------------------------------------------------------
resource "google_artifact_registry_repository_iam_member" "gke_node_gar_reader" {
  project    = data.google_artifact_registry_repository.app_images.project
  location   = data.google_artifact_registry_repository.app_images.location
  repository = data.google_artifact_registry_repository.app_images.name
  role       = "roles/artifactregistry.reader"

  # Default Compute Engine SA: <project_number>-compute@developer.gserviceaccount.com
  member = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

# ---------------------------------------------------------------------------
# ArgoCD Deployment via Helm
# ---------------------------------------------------------------------------
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.3.11"
  namespace        = "argocd"
  create_namespace = true
  timeout          = 900 # 15 minutes for GKE Autopilot node provisioning

  values = [
    yamlencode({
      controller = {
        resources = {
          requests = { cpu = "50m", memory = "256Mi" }
          limits   = { cpu = "200m", memory = "512Mi" }
        }
      }
      dex = {
        resources = {
          requests = { cpu = "50m", memory = "256Mi" }
          limits   = { cpu = "200m", memory = "512Mi" }
        }
      }
      redis = {
        resources = {
          requests = { cpu = "50m", memory = "256Mi" }
          limits   = { cpu = "200m", memory = "512Mi" }
        }
      }
      server = {
        extraArgs = ["--insecure"]
        resources = {
          requests = { cpu = "50m", memory = "256Mi" }
          limits   = { cpu = "200m", memory = "512Mi" }
        }
      }
      repoServer = {
        resources = {
          requests = { cpu = "50m", memory = "256Mi" }
          limits   = { cpu = "200m", memory = "512Mi" }
        }
      }
      applicationSet = {
        resources = {
          requests = { cpu = "50m", memory = "256Mi" }
          limits   = { cpu = "200m", memory = "512Mi" }
        }
      }
      notifications = {
        resources = {
          requests = { cpu = "50m", memory = "256Mi" }
          limits   = { cpu = "200m", memory = "512Mi" }
        }
      }
    })
  ]
}

# ---------------------------------------------------------------------------
# External Secrets Operator Deployment via Helm
# ---------------------------------------------------------------------------
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.9.20"
  namespace        = "external-secrets"
  create_namespace = true
  timeout          = 900 # 15 minutes for GKE Autopilot node provisioning

  values = [
    yamlencode({
      installCRDs = true
      serviceAccount = {
        annotations = {
          "iam.gke.io/gcp-service-account" = "eso-secrets-sa@${var.project_id}.iam.gserviceaccount.com"
        }
      }
      resources = {
        requests = { cpu = "50m", memory = "256Mi" }
        limits   = { cpu = "200m", memory = "512Mi" }
      }
      webhook = {
        resources = {
          requests = { cpu = "50m", memory = "256Mi" }
          limits   = { cpu = "200m", memory = "512Mi" }
        }
      }
      certController = {
        resources = {
          requests = { cpu = "50m", memory = "256Mi" }
          limits   = { cpu = "200m", memory = "512Mi" }
        }
      }
    })
  ]
}

# ---------------------------------------------------------------------------
# IAM & Workload Identity for External Secrets Operator
# ---------------------------------------------------------------------------

# GSA for ESO secrets access
resource "google_service_account" "eso_secrets_sa" {
  account_id   = "eso-secrets-sa"
  display_name = "External Secrets Operator GSA for dev GKE"
  project      = var.project_id
}

# Grant the GSA access to read Secret Manager secrets
resource "google_project_iam_member" "eso_secrets_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.eso_secrets_sa.email}"
}

# Bind GSA to KSA via Workload Identity.
resource "google_service_account_iam_member" "eso_workload_identity" {
  service_account_id = google_service_account.eso_secrets_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[external-secrets/external-secrets]"
}

# ---------------------------------------------------------------------------
# Enterprise Observability: Prometheus & Grafana via Helm
# ---------------------------------------------------------------------------
resource "helm_release" "prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "61.9.0"
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 900 # 15 minutes for GKE Autopilot pod provisioning

  values = [
    yamlencode({
      # Disable components not compatible/allowed in GKE Autopilot
      prometheusOperator = {
        admissionWebhooks = {
          enabled = false
        }
        tls = {
          enabled = false
        }
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "512Mi"
          }
        }
        prometheusConfigReloader = {
          resources = {
            requests = {
              cpu    = "50m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "256Mi"
            }
          }
        }
      }
      prometheus = {
        prometheusSpec = {
          # Use emptyDir for ephemeral dev storage to avoid persistent disk costs/quotas
          storageSpec = {
            emptyDir = {
              medium = "Memory"
            }
          }
          resources = {
            requests = {
              cpu    = "150m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "300m"
              memory = "1Gi"
            }
          }
        }
      }
      alertmanager = {
        alertmanagerSpec = {
          storageSpec = {
            emptyDir = {
              medium = "Memory"
            }
          }
          resources = {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "512Mi"
            }
          }
        }
      }
      # Disable node-exporter daemonset (host access restrictions on Autopilot)
      nodeExporter = {
        enabled = false
      }
      # Enable kube-state-metrics
      "kube-state-metrics" = {
        enabled = true
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "512Mi"
          }
        }
      }
      # Disable control plane scraping (managed GKE control plane is unreachable)
      kubelet = {
        enabled = false
      }
      kubeApiServer = {
        enabled = false
      }
      kubeControllerManager = {
        enabled = false
      }
      kubeScheduler = {
        enabled = false
      }
      kubeEtcd = {
        enabled = false
      }
      kubeProxy = {
        enabled = false
      }
      coreDns = {
        enabled = false
      }
      kubeDns = {
        enabled = false
      }
      # Grafana sidecar configuration to automatically load dashboards from ConfigMaps
      grafana = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "512Mi"
          }
        }
        sidecar = {
          dashboards = {
            enabled         = true
            label           = "grafana_dashboard"
            labelValue      = "1"
            searchNamespace = "ALL"
          }
        }
      }
    })
  ]
}

# ---------------------------------------------------------------------------
# HashiCorp Vault Deployment via Helm
# ---------------------------------------------------------------------------
resource "helm_release" "vault" {
  name             = "vault"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  version          = "0.28.1"
  namespace        = "vault"
  create_namespace = true
  timeout          = 900 # 15 minutes for GKE Autopilot node provisioning

  values = [
    yamlencode({
      global = {
        enabled = true
      }
      server = {
        ha = {
          enabled  = true
          replicas = 1
          raft = {
            enabled   = true
            setNodeId = true
            config    = <<-EOT
              ui = true
              listener "tcp" {
                tls_disable = 1
                address     = "[::]:8200"
                cluster_address = "[::]:8201"
              }
              storage "raft" {
                path    = "/vault/data"
              }
            EOT
          }
        }
        resources = {
          requests = {
            cpu    = "500m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "1Gi"
          }
        }
        dataStorage = {
          enabled      = true
          size         = "2Gi"
          storageClass = "standard-rwo"
        }
      }
      ui = {
        enabled = true
      }
    })
  ]
}

