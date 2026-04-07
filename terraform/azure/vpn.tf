# ─── Azure VPN Gateway (Step 8 — Hybrid Connectivity) ────────────────────────
# BUDGET NOTE: VPN Gateway costs ~€0.19/hr (VpnGw1) or ~€0.45/hr (VpnGw1AZ).
# With limited Azure for Students credits, deploy_vpn_gateway defaults to false.
# Enable it only when working on Steps 7-9 (hybrid/VPN testing).
#
# To enable:
#   Set deploy_vpn_gateway = true in terraform.tfvars
#   Then: terraform apply
# To destroy when done:
#   Set deploy_vpn_gateway = false, then: terraform apply (or terraform destroy)

variable "deploy_vpn_gateway" {
  description = "Deploy VPN Gateway (costly ~€0.19/hr). Enable for Steps 7-9 only."
  type        = bool
  default     = false
}

# Public IP for VPN Gateway (single, non-AZ for cost)
resource "azurerm_public_ip" "vpn_gw" {
  count               = var.deploy_vpn_gateway ? 1 : 0
  name                = "${var.project_name}-${var.environment}-pip-vpngw"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.tags
}

# VPN Gateway — VpnGw1 (non-AZ, cheapest BGP-capable SKU ~€0.19/hr)
resource "azurerm_virtual_network_gateway" "hub" {
  count               = var.deploy_vpn_gateway ? 1 : 0
  name                = "${var.project_name}-${var.environment}-vpngw-hub"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  type          = "Vpn"
  vpn_type      = "RouteBased"
  active_active = false
  enable_bgp    = true
  sku           = "VpnGw1"

  bgp_settings {
    asn = 65515
  }

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gw[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.hub_gateway.id
  }

  tags = local.tags
}

# Local Network Gateway — represents on-premises (Azure legacy VM at 172.161.13.168)
resource "azurerm_local_network_gateway" "onprem" {
  count               = var.deploy_vpn_gateway ? 1 : 0
  name                = "${var.project_name}-${var.environment}-lng-onprem"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  gateway_address     = "172.161.13.168"
  address_space       = ["192.168.0.0/16"]

  bgp_settings {
    asn                 = 65000
    bgp_peering_address = "169.254.20.1"
  }

  tags = local.tags
}

# VPN Connection with BGP + IPsec
resource "azurerm_virtual_network_gateway_connection" "hub_to_onprem" {
  count               = var.deploy_vpn_gateway ? 1 : 0
  name                = "${var.project_name}-${var.environment}-conn-hub-onprem"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.hub[0].id
  local_network_gateway_id   = azurerm_local_network_gateway.onprem[0].id
  enable_bgp                 = true
  shared_key                 = "MultiCloud@Lab2024!"

  ipsec_policy {
    ike_encryption   = "AES256"
    ike_integrity    = "SHA256"
    dh_group         = "DHGroup14"
    ipsec_encryption = "AES256"
    ipsec_integrity  = "GCMAES256"
    pfs_group        = "PFS14"
    sa_lifetime      = 27000
    sa_datasize      = 102400000
  }

  tags = local.tags
}

output "vpn_gateway_id" {
  value = var.deploy_vpn_gateway ? azurerm_virtual_network_gateway.hub[0].id : "not-deployed"
}

output "vpn_gateway_public_ip" {
  value = var.deploy_vpn_gateway ? azurerm_public_ip.vpn_gw[0].ip_address : "not-deployed"
}

output "vpn_gateway_bgp_asn" {
  value = var.deploy_vpn_gateway ? azurerm_virtual_network_gateway.hub[0].bgp_settings[0].asn : 0
}
