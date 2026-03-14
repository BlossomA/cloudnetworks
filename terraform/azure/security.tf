# ─── Azure NSG Hardening (Step 9) ────────────────────────────────────────────
# Additional NSG rules for spoke subnets and diagnostics
# Note: Storage Account and Log Analytics are disabled by default because
# switzerlandnorth restricts these resource types on Azure for Students subs.
# Set enable_flow_logs = true to enable once/if the restriction is lifted.

variable "enable_flow_logs" {
  description = "Enable NSG flow logs (requires Storage Account + Log Analytics — restricted in switzerlandnorth on student subscriptions)"
  type        = bool
  default     = false
}

# Diagnostic settings for NSG flow logs (requires storage account)
resource "azurerm_storage_account" "nsg_flow_logs" {
  count                    = var.enable_flow_logs ? 1 : 0
  name                     = replace("${var.project_name}${var.environment}nsgfl", "-", "")
  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = data.azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  tags = local.tags
}

# Log Analytics Workspace for NSG flow log analysis
resource "azurerm_log_analytics_workspace" "main" {
  count               = var.enable_flow_logs ? 1 : 0
  name                = "${var.project_name}-${var.environment}-law"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.tags
}

# NSG Flow Log for hub mgmt NSG
resource "azurerm_network_watcher_flow_log" "hub_mgmt" {
  count                = var.enable_flow_logs ? 1 : 0
  network_watcher_name = data.azurerm_network_watcher.main.name
  resource_group_name  = data.azurerm_network_watcher.main.resource_group_name
  name                 = "${var.project_name}-${var.environment}-flowlog-hub-mgmt"

  network_security_group_id = azurerm_network_security_group.hub_mgmt.id
  storage_account_id        = azurerm_storage_account.nsg_flow_logs[0].id
  enabled                   = true
  version                   = 2

  retention_policy {
    enabled = true
    days    = 30
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.main[0].workspace_id
    workspace_region      = data.azurerm_resource_group.main.location
    workspace_resource_id = azurerm_log_analytics_workspace.main[0].id
    interval_in_minutes   = 10
  }

  tags = local.tags
}

# NSG Flow Log for spoke1 NSG
resource "azurerm_network_watcher_flow_log" "spoke1" {
  count                = var.enable_flow_logs ? 1 : 0
  network_watcher_name = data.azurerm_network_watcher.main.name
  resource_group_name  = data.azurerm_network_watcher.main.resource_group_name
  name                 = "${var.project_name}-${var.environment}-flowlog-spoke1"

  network_security_group_id = azurerm_network_security_group.spoke1.id
  storage_account_id        = azurerm_storage_account.nsg_flow_logs[0].id
  enabled                   = true
  version                   = 2

  retention_policy {
    enabled = true
    days    = 30
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.main[0].workspace_id
    workspace_region      = data.azurerm_resource_group.main.location
    workspace_resource_id = azurerm_log_analytics_workspace.main[0].id
    interval_in_minutes   = 10
  }

  tags = local.tags
}

# NSG Flow Log for spoke2 NSG
resource "azurerm_network_watcher_flow_log" "spoke2" {
  count                = var.enable_flow_logs ? 1 : 0
  network_watcher_name = data.azurerm_network_watcher.main.name
  resource_group_name  = data.azurerm_network_watcher.main.resource_group_name
  name                 = "${var.project_name}-${var.environment}-flowlog-spoke2"

  network_security_group_id = azurerm_network_security_group.spoke2.id
  storage_account_id        = azurerm_storage_account.nsg_flow_logs[0].id
  enabled                   = true
  version                   = 2

  retention_policy {
    enabled = true
    days    = 30
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.main[0].workspace_id
    workspace_region      = data.azurerm_resource_group.main.location
    workspace_resource_id = azurerm_log_analytics_workspace.main[0].id
    interval_in_minutes   = 10
  }

  tags = local.tags
}

output "log_analytics_workspace_id" {
  value = var.enable_flow_logs ? azurerm_log_analytics_workspace.main[0].workspace_id : null
}

output "nsg_flow_logs_storage_account" {
  value = var.enable_flow_logs ? azurerm_storage_account.nsg_flow_logs[0].name : null
}
