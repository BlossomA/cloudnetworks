terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.6"
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
}

locals {
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# Virtual WAN and Hub
resource "azurerm_virtual_wan" "main" {
  name                = "${var.project_name}-${var.environment}-vwan"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  type                = "Standard"
  tags                = local.tags
}

resource "azurerm_virtual_hub" "main" {
  name                = "${var.project_name}-${var.environment}-vhub"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  virtual_wan_id      = azurerm_virtual_wan.main.id
  address_prefix      = "10.10.100.0/23"
  sku                 = "Standard"
  tags                = local.tags
}

# Hub VNet and Subnets
resource "azurerm_virtual_network" "hub" {
  name                = "${var.project_name}-${var.environment}-hub-vnet"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  address_space       = [var.hub_vnet_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "hub_gateway" {
  name                 = "GatewaySubnet"
  virtual_network_name = azurerm_virtual_network.hub.name
  resource_group_name  = data.azurerm_resource_group.main.name
  address_prefixes     = [var.hub_gateway_subnet_cidr]
}

resource "azurerm_subnet" "hub_mgmt" {
  name                 = "${var.project_name}-${var.environment}-hub-mgmt-subnet"
  virtual_network_name = azurerm_virtual_network.hub.name
  resource_group_name  = data.azurerm_resource_group.main.name
  address_prefixes     = [var.hub_mgmt_subnet_cidr]
}

# Spoke1 VNet and Subnet
resource "azurerm_virtual_network" "spoke1" {
  name                = "${var.project_name}-${var.environment}-spoke1-vnet"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  address_space       = [var.spoke1_vnet_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "spoke1" {
  name                 = "${var.project_name}-${var.environment}-spoke1-subnet"
  virtual_network_name = azurerm_virtual_network.spoke1.name
  resource_group_name  = data.azurerm_resource_group.main.name
  address_prefixes     = [var.spoke1_subnet_cidr]
}

# Spoke2 VNet and Subnet
resource "azurerm_virtual_network" "spoke2" {
  name                = "${var.project_name}-${var.environment}-spoke2-vnet"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  address_space       = [var.spoke2_vnet_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "spoke2" {
  name                 = "${var.project_name}-${var.environment}-spoke2-subnet"
  virtual_network_name = azurerm_virtual_network.spoke2.name
  resource_group_name  = data.azurerm_resource_group.main.name
  address_prefixes     = [var.spoke2_subnet_cidr]
}

# Virtual Hub Connections
resource "azurerm_virtual_hub_connection" "spoke1" {
  name                      = "${var.project_name}-${var.environment}-spoke1-conn"
  virtual_hub_id            = azurerm_virtual_hub.main.id
  remote_virtual_network_id = azurerm_virtual_network.spoke1.id
}

resource "azurerm_virtual_hub_connection" "spoke2" {
  name                      = "${var.project_name}-${var.environment}-spoke2-conn"
  virtual_hub_id            = azurerm_virtual_hub.main.id
  remote_virtual_network_id = azurerm_virtual_network.spoke2.id
}

# Network Security Groups
resource "azurerm_network_security_group" "hub_mgmt" {
  name                = "${var.project_name}-${var.environment}-hub-mgmt-nsg"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = local.tags

  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-icmp"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-iperf"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5201"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "spoke1" {
  name                = "${var.project_name}-${var.environment}-spoke1-nsg"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = local.tags

  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.10.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-icmp"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-iperf"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5201"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "spoke2" {
  name                = "${var.project_name}-${var.environment}-spoke2-nsg"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = local.tags

  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.10.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-icmp"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-iperf"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5201"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSG Associations
resource "azurerm_subnet_network_security_group_association" "hub_mgmt" {
  subnet_id                 = azurerm_subnet.hub_mgmt.id
  network_security_group_id = azurerm_network_security_group.hub_mgmt.id
}

resource "azurerm_subnet_network_security_group_association" "spoke1" {
  subnet_id                 = azurerm_subnet.spoke1.id
  network_security_group_id = azurerm_network_security_group.spoke1.id
}

resource "azurerm_subnet_network_security_group_association" "spoke2" {
  subnet_id                 = azurerm_subnet.spoke2.id
  network_security_group_id = azurerm_network_security_group.spoke2.id
}

# Network Watcher
resource "azurerm_network_watcher" "main" {
  name                = "${var.project_name}-${var.environment}-network-watcher"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = local.tags
}

# Public IP for Hub VM
resource "azurerm_public_ip" "hub_vm" {
  name                = "${var.project_name}-${var.environment}-hub-vm-pip"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

# Network Interfaces
resource "azurerm_network_interface" "hub_vm" {
  name                = "${var.project_name}-${var.environment}-hub-vm-nic"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.hub_mgmt.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.hub_vm.id
  }
}

resource "azurerm_network_interface" "spoke1_vm" {
  name                = "${var.project_name}-${var.environment}-spoke1-vm-nic"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.spoke1.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "spoke2_vm" {
  name                = "${var.project_name}-${var.environment}-spoke2-vm-nic"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.spoke2.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Virtual Machines
resource "azurerm_linux_virtual_machine" "hub" {
  name                = "${var.project_name}-${var.environment}-hub-vm"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.hub_vm.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key != "" ? var.ssh_public_key : file("~/.ssh/id_rsa.pub")
  }

  custom_data = base64encode("#!/bin/bash\napt-get update -y\napt-get install -y iperf3 traceroute mtr")

  tags = local.tags
}

resource "azurerm_linux_virtual_machine" "spoke1" {
  name                = "${var.project_name}-${var.environment}-spoke1-vm"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.spoke1_vm.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key != "" ? var.ssh_public_key : file("~/.ssh/id_rsa.pub")
  }

  custom_data = base64encode("#!/bin/bash\napt-get update -y\napt-get install -y iperf3 traceroute mtr")

  tags = local.tags
}

resource "azurerm_linux_virtual_machine" "spoke2" {
  name                = "${var.project_name}-${var.environment}-spoke2-vm"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.spoke2_vm.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key != "" ? var.ssh_public_key : file("~/.ssh/id_rsa.pub")
  }

  custom_data = base64encode("#!/bin/bash\napt-get update -y\napt-get install -y iperf3 traceroute mtr")

  tags = local.tags
}
