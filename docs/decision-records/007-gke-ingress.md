# ADR 007: GKE Ingress with GCP Application Load Balancer

| Field | Value |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-08-01 |
| **Phase** | 2 — PR 2.7 |
| **Deciders** | @edebu |

---

## Context

The Product Catalog API is successfully running internally on GKE Autopilot and connecting to Cloud SQL (PR 2.6). To expose this API to the internet or external clients, we need an Ingress resource. The design must address:

1.  **Ingress Technology** — GCP GCE Ingress Controller (Google Application Load Balancer) vs in-cluster Nginx Ingress Controller.
2.  **Routing Performance** — Container-Native Load Balancing vs traditional NodePort proxying.
3.  **Security** — HTTP/HTTPS requirements and SSL setup.

---

## Decisions

### 1. GCP GCE Ingress over In-cluster Nginx Ingress

| | GCP GCE Ingress (`gce`) | Nginx Ingress Controller |
|---|---|---|
| Infrastructure | Fully managed GCP Application Load Balancer | Runs inside GKE pods |
| Scaling | Google-managed Global Anycast IP scale | Handled by Kubernetes HPA |
| WAF Integration | Google Cloud Armor (Enterprise WAF) | ModSecurity (manual setup) |
| SSL Offloading | Google-managed SSL Certificates | Cert-manager in-cluster |
| Cost | Paid per Load Balancer rule/ingress traffic | Uses GKE pod capacity + LB service cost |
| Maintenance | Zero overhead (GCP managed) | High (requires updates, helm charts) |

**Decision**: GCP GCE Ingress (`gce`). It leverages Google's Global Edge Network, allows direct integration with Cloud Armor (security baseline for enterprise), and requires zero operational maintenance in GKE Autopilot.

---

### 2. Container-Native Load Balancing (Network Endpoint Groups - NEG)
In traditional Kubernetes clusters, external Load Balancers route traffic to a NodePort on node VMs, which then uses `iptables` / `kube-proxy` to route to the actual Pod. This introduces double-hopping and latency.

- **Decision**: Use **Container-Native Load Balancing** via Network Endpoint Groups (NEGs).
- **Mechanism**: GKE Autopilot automatically provisions NEGs for every Service. The GCP Application Load Balancer routes traffic **directly** to the Pod IPs, bypassing NodePort and kube-proxy entirely. This minimizes latency and ensures optimal HTTP keep-alive behavior.

---

### 3. Dev-phase HTTP Allowed (`kubernetes.io/ingress.allow-http: "true"`)
- **Decision**: Permit raw HTTP traffic for initial verification.
- **Trade-off**: In production, HTTPS is mandatory. However, provisioning DNS records (Cloud DNS) and TLS certificates (Google-managed or cert-manager Let's Encrypt) requires domain ownership. This infrastructure will be fully configured in Phase 3.
- **Upgrade Path**: Annotate the Ingress with `networking.gke.io/v1beta1.FrontendConfig` to enforce SSL redirect (HTTP -> HTTPS) once DNS is wired.

---

## Consequences

### Positive
-   **Global Reach**: Leverages Google's global network edge — client traffic hits the closest Google PoP.
-   **No Double-Hop Latency**: Direct routing from Load Balancer to Pod via NEGs.
-   **Managed Scaling**: Google handles traffic spikes at the edge.

### Negative / Trade-offs
-   **Provisioning Time**: GCP Load Balancers take about 4-7 minutes to spin up, configure frontends, and mark backends healthy.
-   **Cost**: Managed Load Balancers cost ~$18-25/month. Must be cleaned up when destroying the environment to avoid idle charges.

---

## Interview Question

**Q: GKE üzerinde "Container-Native Load Balancing" nedir, avantajları nelerdir ve nasıl aktif edilir?**

**A:** Container-Native Load Balancing, GCP Load Balancer'ın trafiği cluster node'larına (VM) değil, doğrudan Kubernetes **Pod IP**'lerine yönlendirmesini sağlayan mimaridir. GKE arka planda her Service için bir **NEG (Network Endpoint Group)** oluşturur ve Load Balancer backend'i olarak bu NEG'yi atar.

**Avantajları:**
1.  **Düşük Latency (Single-Hop):** Trafik NodePort veya `kube-proxy` (iptables/ipvs) üzerinden tekrar yönlendirilmez. Load Balancer'dan doğrudan pod'a gider.
2.  **Doğru Health Check:** Load Balancer doğrudan pod'un sağlığını kontrol eder. Node'un sağlığı ile pod'un sağlığı ayrıştırılmış olur.
3.  **İdeal Trafik Dağılımı:** VM başına değil, Pod başına eşit yük dağılımı sağlanır.

**Nasıl Aktif Edilir:**
GKE Autopilot'ta tüm servisler için **varsayılan olarak aktiftir**. GKE Standard'da ise Service manifestine `cloud.google.com/neg: '{"ingress": true}'` anotasyonu eklenerek kolayca aktif edilebilir.

---

## References
- [Container-Native Load Balancing on GKE](https://cloud.google.com/kubernetes-engine/docs/concepts/container-native-load-balancing)
- [GKE Ingress Guide](https://cloud.google.com/kubernetes-engine/docs/concepts/ingress)
