variable "project_id" {
  type    = string
  default = "project-903fb6d7-a6c2-406c-9bb"
}
variable "region" {
  type    = string
  default = "us-central1"
}
variable "zone" {
  type    = string
  default = "us-central1-a"
}
variable "project_name" {
  type    = string
  default = "multi-cloud-net"
}
variable "environment" {
  type    = string
  default = "lab"
}
variable "hub_subnet_cidr" {
  type    = string
  default = "10.20.1.0/24"
}
variable "spoke1_subnet_cidr" {
  type    = string
  default = "10.21.1.0/24"
}
variable "spoke2_subnet_cidr" {
  type    = string
  default = "10.22.1.0/24"
}
variable "machine_type" {
  type    = string
  default = "e2-micro"
}
variable "ssh_user" {
  type    = string
  default = "gcpuser"
}
variable "ssh_pub_key" {
  description = "SSH public key in format 'user:ssh-rsa AAAA...'"
  type        = string
  default     = ""
}
