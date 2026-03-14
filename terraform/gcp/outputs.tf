output "hub_vpc_name" {
  value = google_compute_network.hub.name
}
output "spoke1_vpc_name" {
  value = google_compute_network.spoke1.name
}
output "spoke2_vpc_name" {
  value = google_compute_network.spoke2.name
}
output "hub_subnet_name" {
  value = google_compute_subnetwork.hub.name
}
output "hub_vm_external_ip" {
  value = google_compute_instance.hub_vm.network_interface[0].access_config[0].nat_ip
}
output "hub_vm_internal_ip" {
  value = google_compute_instance.hub_vm.network_interface[0].network_ip
}
output "spoke1_vm_internal_ip" {
  value = google_compute_instance.spoke1_vm.network_interface[0].network_ip
}
output "spoke2_vm_internal_ip" {
  value = google_compute_instance.spoke2_vm.network_interface[0].network_ip
}
output "hub_router_name" {
  value = google_compute_router.hub.name
}
output "ha_vpn_gateway_id" {
  value = google_compute_ha_vpn_gateway.hub.id
}
