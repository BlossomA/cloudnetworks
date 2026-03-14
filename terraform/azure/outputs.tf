output "resource_group_name" {
  value = data.azurerm_resource_group.main.name
}
output "hub_vnet_id" {
  value = azurerm_virtual_network.hub.id
}
output "spoke1_vnet_id" {
  value = azurerm_virtual_network.spoke1.id
}
output "spoke2_vnet_id" {
  value = azurerm_virtual_network.spoke2.id
}
output "virtual_wan_id" {
  value = azurerm_virtual_wan.main.id
}
output "virtual_hub_id" {
  value = azurerm_virtual_hub.main.id
}
output "hub_vm_public_ip" {
  value = azurerm_public_ip.hub_vm.ip_address
}
output "hub_vm_private_ip" {
  value = azurerm_network_interface.hub_vm.private_ip_address
}
output "spoke1_vm_private_ip" {
  value = azurerm_network_interface.spoke1_vm.private_ip_address
}
output "spoke2_vm_private_ip" {
  value = azurerm_network_interface.spoke2_vm.private_ip_address
}
output "network_watcher_id" {
  value = azurerm_network_watcher.main.id
}
