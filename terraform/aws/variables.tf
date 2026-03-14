variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "multi-cloud-net"
}

variable "environment" {
  description = "Environment label"
  type        = string
  default     = "lab"
}

variable "hub_vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "hub_public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "hub_private_subnet_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "spoke1_vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "spoke1_public_subnet_cidr" {
  type    = string
  default = "10.1.1.0/24"
}

variable "spoke1_private_subnet_cidr" {
  type    = string
  default = "10.1.2.0/24"
}

variable "spoke2_vpc_cidr" {
  type    = string
  default = "10.2.0.0/16"
}

variable "spoke2_public_subnet_cidr" {
  type    = string
  default = "10.2.1.0/24"
}

variable "spoke2_private_subnet_cidr" {
  type    = string
  default = "10.2.2.0/24"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_pair_name" {
  description = "AWS EC2 key pair name (must already exist in the account)"
  type        = string
  default     = ""
}
