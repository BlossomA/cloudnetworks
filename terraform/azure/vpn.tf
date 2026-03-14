# ─── Azure ExpressRoute Simulation + VPN Gateway (Step 8) ────────────────────
# Simulates ExpressRoute via VPN Gateway in the Virtual WAN hub
# Also enables branch-to-branch transit

# Public IP for VPN Gateway
resource "azurerm_public_ip" "vpn_gw" {
  name                = "${var.project_name}-${var.environment}-pip-vpngw"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]

  tags = local.tags
}

# Second public IP for active-active VPN Gateway
resource "azurerm_public_ip" "vpn_gw_aa" {
  name                = "${var.project_name}-${var.environment}-pip-vpngw-aa"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]

  tags = local.tags
}

# VPN Gateway in the hub VNet (GatewaySubnet)
resource "azurerm_virtual_network_gateway" "hub" {
  name                = "${var.project_name}-${var.environment}-vpngw-hub"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  type          = "Vpn"
  vpn_type      = "RouteBased"
  active_active = true
  enable_bgp    = true
  sku           = "VpnGw1AZ"

  bgp_settings {
    asn = 65515
  }

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gw.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.hub_gateway.id
  }

  ip_configuration {
    name                          = "vnetGatewayConfigAA"
    public_ip_address_id          = azurerm_public_ip.vpn_gw_aa.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.hub_gateway.id
  }

  tags = local.tags
}

# Local Network Gateway - represents on-premises (Azure legacy VM)
resource "azurerm_local_network_gateway" "onprem" {
  name                = "${var.project_name}-${var.environment}-lng-onprem"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  gateway_address     = "172.161.13.168"

  address_space = ["192.168.0.0/16"]

  bgp_settings {
    asn                 = 65000
    bgp_peering_address = "169.254.20.1"
  }

  tags = local.tags
}

# VPN Connection: Hub Gateway <-> On-Premises (BGP enabled)
resource "azurerm_virtual_network_gateway_connection" "hub_to_onprem" {
  name                = "${var.project_name}-${var.environment}-conn-hub-onprem"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.hub.id
  local_network_gateway_id   = azurerm_local_network_gateway.onprem.id
  enable_bgp                 = true

  shared_key = "MultiCloud@Lab2024!"

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

# Outputs
output "vpn_gateway_id" {
  value = azurerm_virtual_network_gateway.hub.id
}

output "vpn_gateway_public_ip_1" {
  value = azurerm_public_ip.vpn_gw.ip_address
}

output "vpn_gateway_public_ip_2" {
  value = azurerm_public_ip.vpn_gw_aa.ip_address
}

output "vpn_gateway_bgp_asn" {
  value = azurerm_virtual_network_gateway.hub.bgp_settings[0].asn
}
