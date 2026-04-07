variable "location" {
  type    = string
  default = "UK South"
}
variable "project_name" {
  type    = string
  default = "multi-cloud-net"
}
variable "environment" {
  type    = string
  default = "lab"
}
variable "subscription_id" {
  type    = string
  default = "da9b7708-5f06-4d47-b2b3-13528692df47"
}
variable "tenant_id" {
  type    = string
  default = "4947ad8c-f569-43e6-915c-1566b0cbaee5"
}
variable "client_id" {
  type    = string
  default = "31e6764c-d46b-49e2-ad03-a63372f8a16f"
}
variable "client_secret" {
  type      = string
  sensitive = true
  default   = ""
}
variable "resource_group_name" {
  type    = string
  default = "rg-building-arbitrary-cloud-thesis"
}
variable "hub_vnet_cidr" {
  type    = string
  default = "10.10.0.0/16"
}
variable "hub_gateway_subnet_cidr" {
  type    = string
  default = "10.10.0.0/24"
}
variable "hub_mgmt_subnet_cidr" {
  type    = string
  default = "10.10.1.0/24"
}
variable "spoke1_vnet_cidr" {
  type    = string
  default = "10.11.0.0/16"
}
variable "spoke1_subnet_cidr" {
  type    = string
  default = "10.11.1.0/24"
}
variable "spoke2_vnet_cidr" {
  type    = string
  default = "10.12.0.0/16"
}
variable "spoke2_subnet_cidr" {
  type    = string
  default = "10.12.1.0/24"
}
variable "vm_size" {
  type    = string
  default = "Standard_B1s"
}
variable "admin_username" {
  type    = string
  default = "azureuser"
}
variable "ssh_public_key" {
  description = "SSH public key content for VM authentication"
  type        = string
  default     = ""
}
