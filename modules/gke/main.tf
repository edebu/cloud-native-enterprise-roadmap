# modules/gke/main.tf
#
# Provisions a GKE Autopilot cluster inside the existing VPC (Phase 1).
#
# Architecture decisions:
#   - Autopilot mode: Google manages node pools, bin-packing, scaling.
#     Developers focus on workloads, not nodes. Cost is per-Pod, not per-node.
#   - Private nodes (enable_private_nodes = true): node VMs have no public IPs.
#     Outbound internet access is via Cloud NAT provisioned in Phase 1.
#   - Public endpoint (enable_private_endpoint = false): the control plane
#     is reachable over the internet for `kubectl`. Access is locked via
#     master_authorized_networks. In full enterprise setups this would be
#     flipped to true and accessed via IAP tunnel or bastion — that tradeoff
#     is documented in ADR 004.
#   - Workload Identity: enabled automatically in Autopilot. Pods can
#     impersonate GCP service accounts via KSA → GSA binding (Phase 3).
#   - Release channel REGULAR: production-tested releases, auto-patched.
#
# ADR: docs/decision-records/004-gke-autopilot.md

# ---------------------------------------------------------------------------
# Enable the GKE API
# ---------------------------------------------------------------------------
resource "google_project_service" "container_api" {
  project = var.project_id
  service = "container.googleapis.com"

  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# GKE Autopilot Cluster
# ---------------------------------------------------------------------------
locals {
  # ---------------------------------------------------------------------------
  # Authorized networks fallback
  #
  # GKE behaviour when master_authorized_networks_config is set:
  #   - cidr_blocks = []  → ONLY gcp_public_cidrs allowed → developers LOCKED OUT
  #   - cidr_blocks = [{0.0.0.0/0}] → anyone can reach the control plane
  #
  # We want empty var = "no restriction" (dev convenience). Production callers
  # should always pass explicit CIDR blocks (e.g. VPN egress, Cloud Build SA).
  # ---------------------------------------------------------------------------
  effective_authorized_networks = length(var.authorized_networks) == 0 ? [
    { cidr_block = "0.0.0.0/0", display_name = "allow-all-dev" }
  ] : var.authorized_networks
}

resource "google_container_cluster" "main" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # Autopilot — Google manages all node infrastructure.
  # Mutually exclusive with node_pool and node_config blocks.
  enable_autopilot = true

  # Prevent accidental `terraform destroy` in production.
  deletion_protection = var.deletion_protection

  # Attach to the VPC created in Phase 1.
  network    = var.network_name
  subnetwork = var.subnetwork_name

  # ---------------------------------------------------------------------------
  # Private cluster — nodes have no external IPs.
  # Egress handled by Cloud NAT (Phase 1). Control plane remains publicly
  # reachable for kubectl during the learning phase (see ADR 004).
  # ---------------------------------------------------------------------------
  private_cluster_config {
    enable_private_nodes = true

    # false = public control plane endpoint (accessible from internet).
    # Restricted via master_authorized_networks below.
    enable_private_endpoint = false

    # Internal peering CIDR between GCP control plane and the VPC.
    # Must be /28, must not overlap with any subnet in the VPC.
    master_ipv4_cidr_block = var.master_ipv4_cidr_block
  }

  # ---------------------------------------------------------------------------
  # VPC-native networking (alias IP ranges)
  # Required for private clusters. GKE auto-allocates secondary CIDR ranges
  # for Pod and Service IPs when cidr blocks are left empty.
  # ---------------------------------------------------------------------------
  ip_allocation_policy {}

  # ---------------------------------------------------------------------------
  # Control plane access restriction
  #
  # Uses local.effective_authorized_networks so that an empty var produces
  # 0.0.0.0/0 (open) rather than silently locking out all external IPs.
  # ---------------------------------------------------------------------------
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = local.effective_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
    # Allow GCP-internal services (Cloud Shell, Cloud Build) to always connect.
    gcp_public_cidrs_access_enabled = true
  }

  # ---------------------------------------------------------------------------
  # Workload Identity
  # Enabled by default in Autopilot. Explicitly declared for clarity.
  # Pods authenticate to GCP services via KSA → GSA binding — no static keys.
  # ---------------------------------------------------------------------------
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # ---------------------------------------------------------------------------
  # Release channel — REGULAR gets production-tested releases ~2-3 months
  # after RAPID. Automatic security patches and minor version upgrades.
  # ---------------------------------------------------------------------------
  release_channel {
    channel = "REGULAR"
  }

  resource_labels = var.labels

  depends_on = [google_project_service.container_api]
}
