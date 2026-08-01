# ADR 004: GKE Autopilot with Private Nodes and Public Control Plane

| Field | Value |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-08-01 |
| **Phase** | 2 — PR 2.4 |
| **Deciders** | @edebu |

---

## Context

Phase 1 established a VPC with private subnets and Cloud NAT. Phase 2 requires a Kubernetes cluster to host the Product Catalog API. Several critical decisions must be made:

1. **GKE mode** — Autopilot vs Standard
2. **Node visibility** — public vs private nodes
3. **Control plane access** — private vs public endpoint
4. **State isolation** — separate Terraform state or same state as Phase 1 base infra
5. **Image pull authentication** — node SA vs Workload Identity

---

## Decisions

### 1. GKE Autopilot over Standard

| | Autopilot | Standard |
|---|---|---|
| Node management | Google | User |
| Billing model | Per-Pod CPU/memory/storage | Per-node (even idle) |
| Scaling | Automatic | Requires Cluster Autoscaler config |
| Security posture | Hardened by default (no SSH, no privilege escalation) | User-configured |
| Learning focus | **Kubernetes workloads** | Node pool config, taints, tolerations |

**Decision**: Autopilot. The learning goal is Kubernetes workload management, not node administration. Lower cost for dev workloads (no idle node charges).

---

### 2. Private Nodes (`enable_private_nodes = true`)

Node VMs have no external (public) IPs. This is mandatory for enterprise clusters:

- Reduces the attack surface — no direct SSH exposure to the internet.
- Outbound internet traffic (image pulls from GAR, external API calls) routes through Cloud NAT provisioned in Phase 1 — no code change needed.

---

### 3. Public Control Plane Endpoint (`enable_private_endpoint = false`)

This is a deliberate **learning-phase trade-off**:

| | Public endpoint | Private endpoint |
|---|---|---|
| `kubectl` access | From anywhere (restricted via authorized_networks) | Only from within VPC (requires IAP tunnel or bastion) |
| Setup complexity | Low | High (VPN or IAP setup required) |
| Security | Acceptable with IP allowlist | Enterprise-grade |

**Decision for dev**: Public endpoint. `authorized_networks = []` is now handled by the module with a `0.0.0.0/0` fallback — any IP can reach the control plane.

> **Bug encountered & fixed (PR hotfix):** Initially, `authorized_networks = []` was passed to a `master_authorized_networks_config` block with an empty `cidr_blocks` dynamic block. GKE interpreted this as: *"only GCP internal IPs allowed"* — not *"unrestricted"*. External `kubectl` calls timed out at port 443. Fixed by adding a `locals` block that substitutes `0.0.0.0/0` when the list is empty. This is a real-world Terraform gotcha worth remembering.

> **Production upgrade path**: Set `enable_private_endpoint = true` and access via `gcloud container clusters get-credentials --internal-ip` through an IAP tunnel or bastion. This will be addressed in a future phase.

**Mülakat sorusu cevabı**: *"GKE Private Cluster üzerinde kubectl nasıl çalıştırırsın?"*
> Cloud Shell, IAP TCP Tunneling (`gcloud compute start-iap-tunnel`), ya da cluster VPC içindeki bir VM üzerinden erişilir. Control plane endpoint'in `--enable-private-endpoint` ile kapatılması durumunda, dışarıdan erişmek için VPN veya IAP zorunludur.

---

### 4. Separate Terraform State (not `terraform_remote_state`)

The GKE directory (`environments/dev/terraform/gke/`) has its own state at `gs://cn-er-terraform-state-bucket-dev/env/dev/gke`.

Phase 1 network resources are referenced via **data sources** (`google_compute_network`, `google_compute_subnetwork`) instead of `terraform_remote_state`.

**Why data sources instead of remote state?**

| | `terraform_remote_state` | Data sources |
|---|---|---|
| Coupling | Tight — GKE state imports Phase 1 outputs | Loose — looks up by name |
| Resilience | If Phase 1 state is corrupt/locked, GKE plan fails | GKE operates independently |
| Portability | Phase 1 must exist as Terraform state | Works if network was created manually |
| Visibility | Output values visible in GKE config | Resource names visible in GKE config |

**Decision**: Data sources. More resilient and portable.

---

### 5. Node SA for Image Pulls (vs Workload Identity per Pod)

GKE Autopilot nodes use the **default Compute Engine SA** (`<project_number>-compute@developer.gserviceaccount.com`). Granting this SA `roles/artifactregistry.reader` allows the kubelet to pull images from the private GAR repository without additional configuration.

**Phase 3 upgrade**: Workload Identity will bind specific Kubernetes SAs to GCP SAs for per-Pod granularity — eliminating the need for the node SA to have any GCP permissions.

---

## Consequences

### Positive

- Zero node management overhead — Google handles patching, scaling, bin-packing.
- Nodes are private — no direct internet exposure.
- `kubectl` accessible from developer machines during learning phase.
- Decoupled state — GKE can be destroyed and recreated without touching Phase 1.

### Negative / Trade-offs

- Public control plane endpoint in dev — not enterprise-grade (acceptable with IP allowlist in staging/prod).
- Default compute SA has GAR reader — broader than necessary (fixed in Phase 3 with Workload Identity).
- Autopilot clusters cannot tune node-level parameters (taints, accelerators beyond standard types) — tradeoff for reduced ops burden.

---

## References

- [GKE Autopilot overview](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview)
- [Private GKE clusters](https://cloud.google.com/kubernetes-engine/docs/how-to/private-cluster-create)
- [GKE Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [Terraform: google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
