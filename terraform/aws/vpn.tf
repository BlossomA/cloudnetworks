# ─── AWS Site-to-Site VPN (Hybrid Connectivity - Step 7) ─────────────────────
# Simulates Direct Connect via Site-to-Site VPN with BGP dynamic routing
# The "on-premises" endpoint is the Azure VM (vm-cloud-lab at 172.161.13.168)

variable "onprem_public_ip" {
  description = "Public IP of the simulated on-premises endpoint (Azure VM)"
  type        = string
  default     = "172.161.13.168"
}

variable "onprem_bgp_asn" {
  description = "BGP ASN for the simulated on-premises router"
  type        = number
  default     = 65000
}

variable "onprem_cidr" {
  description = "CIDR block of the simulated on-premises network"
  type        = string
  default     = "192.168.0.0/16"
}

# Customer Gateway - represents the on-premises (Azure VM) side
resource "aws_customer_gateway" "onprem" {
  bgp_asn    = var.onprem_bgp_asn
  ip_address = var.onprem_public_ip
  type       = "ipsec.1"

  tags = merge(local.tags, {
    Name = "${var.project_name}-${var.environment}-cgw-onprem"
  })
}

# VPN Gateway attached to the hub VPC
resource "aws_vpn_gateway" "hub" {
  vpc_id          = aws_vpc.hub.id
  amazon_side_asn = 64512

  tags = merge(local.tags, {
    Name = "${var.project_name}-${var.environment}-vgw-hub"
  })
}

# Attach VPN Gateway to Transit Gateway
resource "aws_vpn_gateway_attachment" "hub_to_tgw" {
  vpc_id         = aws_vpc.hub.id
  vpn_gateway_id = aws_vpn_gateway.hub.id
}

# Site-to-Site VPN Connection with dynamic BGP routing
resource "aws_vpn_connection" "onprem_to_hub" {
  customer_gateway_id = aws_customer_gateway.onprem.id
  vpn_gateway_id      = aws_vpn_gateway.hub.id
  type                = "ipsec.1"
  static_routes_only  = false  # BGP dynamic routing

  # Tunnel 1 options
  tunnel1_inside_cidr   = "169.254.10.0/30"
  tunnel1_preshared_key = "MultiCloud@Lab2024!"

  # Tunnel 2 options (failover)
  tunnel2_inside_cidr   = "169.254.10.4/30"
  tunnel2_preshared_key = "MultiCloud@Lab2024!"

  tags = merge(local.tags, {
    Name = "${var.project_name}-${var.environment}-vpn-onprem"
  })
}

# Route propagation: allow VPN gateway to propagate routes to hub private route table
resource "aws_vpn_gateway_route_propagation" "hub_private" {
  route_table_id = aws_route_table.hub_private.id
  vpn_gateway_id = aws_vpn_gateway.hub.id

  depends_on = [aws_vpn_gateway_attachment.hub_to_tgw]
}

# Static route for on-prem CIDR via VPN (fallback if BGP not available)
resource "aws_route" "hub_to_onprem" {
  route_table_id         = aws_route_table.hub_private.id
  destination_cidr_block = var.onprem_cidr
  gateway_id             = aws_vpn_gateway.hub.id

  depends_on = [aws_vpn_gateway_attachment.hub_to_tgw]
}

# Output VPN tunnel details for on-premises configuration
output "vpn_tunnel1_address" {
  description = "VPN Tunnel 1 AWS endpoint IP"
  value       = aws_vpn_connection.onprem_to_hub.tunnel1_address
}

output "vpn_tunnel2_address" {
  description = "VPN Tunnel 2 AWS endpoint IP"
  value       = aws_vpn_connection.onprem_to_hub.tunnel2_address
}

output "vpn_tunnel1_cgw_inside_ip" {
  description = "Tunnel 1 customer gateway inside IP (for BGP peer config)"
  value       = aws_vpn_connection.onprem_to_hub.tunnel1_cgw_inside_address
}

output "vpn_tunnel1_vgw_inside_ip" {
  description = "Tunnel 1 AWS VGW inside IP (BGP peer)"
  value       = aws_vpn_connection.onprem_to_hub.tunnel1_vgw_inside_address
}

output "customer_gateway_id" {
  value = aws_customer_gateway.onprem.id
}
