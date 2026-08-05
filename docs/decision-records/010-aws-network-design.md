# ADR 010: AWS Network Design

**Date:** 2026-08-04  
**Status:** Accepted  
**Phase:** Phase 5 — PR 5.2  
**Deciders:** Platform Engineering Team

---

## Context

Phase 5 requires an AWS-equivalent of the GCP network stack built in Phase 1. The GCP network consists of:
- Custom-mode VPC (`dev-enterprise-vpc`)
- Public subnet (10.10.1.0/24) and private subnet (10.10.2.0/24)
- Cloud Router + Cloud NAT for private subnet egress
- Firewall rules: deny external SSH, allow internal VPC traffic

The AWS network module must achieve the same network topology and security posture using AWS-native constructs.

---

## Decision

### CIDR Design

| Resource | GCP | AWS |
|:---------|:----|:----|
| VPC CIDR | *N/A (flat)* | 10.20.0.0/16 |
| Public Subnet | 10.10.1.0/24 | 10.20.1.0/24 |
| Private Subnet | 10.10.2.0/24 | 10.20.2.0/24 |

AWS uses a 10.20.x.x range to avoid any routing conflict if GCP and AWS were ever connected via VPN or Cloud Interconnect. GCP's 10.10.x.x, GKE master CIDR 172.16.0.0/28, and Cloud SQL's 10.100.0.0/16 are all safely isolated.

### Component Mapping

| GCP Component | AWS Equivalent | Notes |
|:-------------|:--------------|:------|
| `google_compute_network` | `aws_vpc` | VPC creation; AWS requires explicit VPC CIDR |
| `google_compute_subnetwork` | `aws_subnet` | Per-AZ in AWS; we use `{region}a` for dev simplicity |
| `google_compute_router` | *(implicit in NAT GW)* | AWS NAT GW doesn't need a separate router resource |
| `google_compute_router_nat` | `aws_nat_gateway` + `aws_eip` | AWS requires an Elastic IP bound to the NAT GW |
| `google_compute_firewall` (deny SSH) | Security Group (SSH port omitted) | AWS SGs are allow-only; "deny" = absence of allow rule |
| `google_compute_firewall` (allow internal) | Security Group ingress on VPC CIDR | Same concept, different resource model |

### Key Differences

**1. Internet Gateway (IGW)**  
GCP routes outbound traffic through the VPC's default gateway automatically. AWS requires an explicit `aws_internet_gateway` resource attached to the VPC.

**2. Route Tables**  
GCP manages routing at the VPC level with custom routes. AWS uses explicit `aws_route_table` + `aws_route_table_association` per subnet. We create:
- Public route table: `0.0.0.0/0 → IGW`
- Private route table: `0.0.0.0/0 → NAT Gateway`

**3. Security Groups vs Firewall Rules**  
GCP firewall rules are stateful and applied at the VPC level (can target instances by tag). AWS security groups are stateful and applied at the instance/ENI level. For the network module, we create a **default security group** that allows:
- All internal VPC traffic (same as GCP's `allow_internal` rule)
- HTTP/HTTPS from internet (for load balancers)
- All outbound (same as GCP's default egress allow)
- SSH (port 22) is **not** included — use SSM Session Manager instead.

**4. Single AZ for Dev**  
For cost optimization in the dev environment, we use a single AZ (`{region}a`). Production would span at least 2 AZs and require multiple NAT Gateways for HA.

### Cost Considerations

The primary cost difference from GCP: AWS NAT Gateway charges per GB of data processed (~$0.045/GB) plus hourly ($0.045/hour). GCP Cloud NAT charges similarly. For this dev environment (code-only, no actual deployment), there is no runtime cost.

---

## Consequences

**Positive:**
- Clean 1:1 mapping with GCP module interface (same variable names, same output names where feasible)
- No SSH access by default (secure-by-default, same as GCP's deny_external_ssh rule)
- Route tables explicitly document network topology

**Negative:**
- AWS requires more resources than GCP for the same topology (IGW, route tables, EIPs are explicit)
- Single AZ = no HA for private subnet (acceptable for dev/demo)

---

## References

- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/)
- [GCP → AWS Network Mapping](https://cloud.google.com/docs/get-started/aws-azure-gcp-service-comparison#networking)
- [ADR 001: GCS Backend and Cloud NAT](001-gcs-backend-and-cloud-nat.md) — GCP network decisions
