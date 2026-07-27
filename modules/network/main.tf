# 1. Custom Mode VPC
resource "google_compute_network" "vpc" {
  name                            = var.network_name
  auto_create_subnetworks         = false
  routing_mode                    = "GLOBAL"
  delete_default_routes_on_create = false
}

# 2. Public Subnet
resource "google_compute_subnetwork" "public_subnet" {
  name          = "${var.network_name}-public-subnet"
  ip_cidr_range = var.public_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
}

# 3. Private Subnet
resource "google_compute_subnetwork" "private_subnet" {
  name                     = "${var.network_name}-private-subnet"
  ip_cidr_range            = var.private_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true # Google API'lerine private IP üzerinden erişim için
}

# 4. Cloud Router (Cloud NAT için gerekli)
resource "google_compute_router" "router" {
  name    = "${var.network_name}-cloud-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

# 5. Cloud NAT (Bastion host olmaksızın private subnet'in dışarı çıkabilmesi için)
resource "google_compute_router_nat" "nat" {
  name                               = "${var.network_name}-cloud-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# 1. SSH (Port 22) erişimini dış dünyaya tamamen kapatan / kısıtlayan kural
resource "google_compute_firewall" "deny_external_ssh" {
  name    = "${var.network_name}-deny-external-ssh"
  network = google_compute_network.vpc.name
  direction = "INGRESS"
  priority  = 1000

  deny {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  # Not: GCP IAP IP aralığı (35.235.240.0/20) üzerinden güvenli bağlantıya ileride izin verilebilir.
}

# 2. Internal (Ağ içi) iletişime izin veren kural
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.network_name}-allow-internal"
  network = google_compute_network.vpc.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [var.public_subnet_cidr, var.private_subnet_cidr]
}