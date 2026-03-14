# ─── GCP HA VPN Gateway + Cloud Router (Step 8) ──────────────────────────────
# Simulates Cloud Interconnect via HA VPN with BGP
# Connects hub VPC to on-premises (Azure VM at 172.161.13.168)

variable "onprem_public_ip" {
  description = "Public IP of the simulated on-premises endpoint (Azure VM)"
  type        = string
  default     = "172.161.13.168"
}

variable "onprem_bgp_asn" {
  description = "BGP ASN of the on-premises peer"
  type        = number
  default     = 65000
}

variable "onprem_cidr" {
  description = "On-premises CIDR range"
  type        = string
  default     = "192.168.0.0/16"
}

# Cloud Router for BGP sessions in hub VPC
resource "google_compute_router" "hub" {
  name    = "${var.project_name}-${var.environment}-router-hub"
  network = google_compute_network.hub.id
  region  = var.region

  bgp {
    asn               = 65520
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]

    advertised_ip_ranges {
      range = "10.20.0.0/16"
    }
    advertised_ip_ranges {
      range = "10.21.0.0/16"
    }
    advertised_ip_ranges {
      range = "10.22.0.0/16"
    }
  }
}

# HA VPN Gateway (2 external IPs for redundancy)
resource "google_compute_ha_vpn_gateway" "hub" {
  name    = "${var.project_name}-${var.environment}-ha-vpngw-hub"
  network = google_compute_network.hub.id
  region  = var.region
}

# External VPN Gateway (represents on-premises endpoint)
resource "google_compute_external_vpn_gateway" "onprem" {
  name            = "${var.project_name}-${var.environment}-ext-vpngw-onprem"
  redundancy_type = "SINGLE_IP_INTERNALLY_REDUNDANT"

  interface {
    id         = 0
    ip_address = var.onprem_public_ip
  }
}

# VPN Tunnel 1 (primary)
resource "google_compute_vpn_tunnel" "hub_to_onprem_tunnel1" {
  name                            = "${var.project_name}-${var.environment}-tunnel1-hub-onprem"
  region                          = var.region
  ha_vpn_gateway                  = google_compute_ha_vpn_gateway.hub.id
  ha_vpn_gateway_interface        = 0
  peer_external_gateway           = google_compute_external_vpn_gateway.onprem.id
  peer_external_gateway_interface = 0
  router                          = google_compute_router.hub.id
  shared_secret                   = "MultiCloud@Lab2024!"
  ike_version                     = 2
}

# VPN Tunnel 2 (failover)
resource "google_compute_vpn_tunnel" "hub_to_onprem_tunnel2" {
  name                            = "${var.project_name}-${var.environment}-tunnel2-hub-onprem"
  region                          = var.region
  ha_vpn_gateway                  = google_compute_ha_vpn_gateway.hub.id
  ha_vpn_gateway_interface        = 1
  peer_external_gateway           = google_compute_external_vpn_gateway.onprem.id
  peer_external_gateway_interface = 0
  router                          = google_compute_router.hub.id
  shared_secret                   = "MultiCloud@Lab2024!"
  ike_version                     = 2
}

# BGP interface for tunnel 1
resource "google_compute_router_interface" "tunnel1" {
  name       = "${var.project_name}-${var.environment}-rif-tunnel1"
  router     = google_compute_router.hub.name
  region     = var.region
  ip_range   = "169.254.30.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.hub_to_onprem_tunnel1.name
}

# BGP interface for tunnel 2
resource "google_compute_router_interface" "tunnel2" {
  name       = "${var.project_name}-${var.environment}-rif-tunnel2"
  router     = google_compute_router.hub.name
  region     = var.region
  ip_range   = "169.254.30.5/30"
  vpn_tunnel = google_compute_vpn_tunnel.hub_to_onprem_tunnel2.name

  depends_on = [google_compute_router_interface.tunnel1]
}

# BGP peer for tunnel 1
resource "google_compute_router_peer" "tunnel1" {
  name                      = "${var.project_name}-${var.environment}-peer-tunnel1"
  router                    = google_compute_router.hub.name
  region                    = var.region
  peer_ip_address           = "169.254.30.2"
  peer_asn                  = var.onprem_bgp_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.tunnel1.name
}

# BGP peer for tunnel 2 (higher cost = failover)
resource "google_compute_router_peer" "tunnel2" {
  name                      = "${var.project_name}-${var.environment}-peer-tunnel2"
  router                    = google_compute_router.hub.name
  region                    = var.region
  peer_ip_address           = "169.254.30.6"
  peer_asn                  = var.onprem_bgp_asn
  advertised_route_priority = 200
  interface                 = google_compute_router_interface.tunnel2.name
}

# Firewall: allow IKE and ESP from on-premises for VPN
resource "google_compute_firewall" "allow_vpn" {
  name    = "${var.project_name}-${var.environment}-allow-vpn-hub"
  network = google_compute_network.hub.id

  allow {
    protocol = "udp"
    ports    = ["500", "4500"]
  }

  allow {
    protocol = "esp"
  }

  source_ranges = [var.onprem_public_ip]
  target_tags   = ["vpn-endpoint"]

  description = "Allow IKE/ESP from on-premises for HA VPN"
}

# Outputs
output "ha_vpn_gateway_ip1" {
  description = "HA VPN Gateway external IP interface 0"
  value       = google_compute_ha_vpn_gateway.hub.vpn_interfaces[0].ip_address
}

output "ha_vpn_gateway_ip2" {
  description = "HA VPN Gateway external IP interface 1"
  value       = google_compute_ha_vpn_gateway.hub.vpn_interfaces[1].ip_address
}

output "cloud_router_bgp_asn" {
  value = google_compute_router.hub.bgp[0].asn
}
