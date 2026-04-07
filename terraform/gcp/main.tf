terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.6"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  labels = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  }
}

# VPC Networks
resource "google_compute_network" "hub" {
  name                    = "${var.project_name}-${var.environment}-hub-vpc"
  auto_create_subnetworks = false
  mtu                     = 1460
  description             = "Hub VPC for multi-cloud lab"
}

resource "google_compute_subnetwork" "hub" {
  name          = "${var.project_name}-${var.environment}-hub-subnet"
  ip_cidr_range = var.hub_subnet_cidr
  region        = var.region
  network       = google_compute_network.hub.id

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_network" "spoke1" {
  name                    = "${var.project_name}-${var.environment}-spoke1-vpc"
  auto_create_subnetworks = false
  mtu                     = 1460
  description             = "Spoke1 VPC for multi-cloud lab"
}

resource "google_compute_subnetwork" "spoke1" {
  name          = "${var.project_name}-${var.environment}-spoke1-subnet"
  ip_cidr_range = var.spoke1_subnet_cidr
  region        = var.region
  network       = google_compute_network.spoke1.id

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_network" "spoke2" {
  name                    = "${var.project_name}-${var.environment}-spoke2-vpc"
  auto_create_subnetworks = false
  mtu                     = 1460
  description             = "Spoke2 VPC for multi-cloud lab"
}

resource "google_compute_subnetwork" "spoke2" {
  name          = "${var.project_name}-${var.environment}-spoke2-subnet"
  ip_cidr_range = var.spoke2_subnet_cidr
  region        = var.region
  network       = google_compute_network.spoke2.id

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# VPC Peerings
resource "google_compute_network_peering" "hub_to_spoke1" {
  name                 = "${var.project_name}-${var.environment}-hub-to-spoke1"
  network              = google_compute_network.hub.self_link
  peer_network         = google_compute_network.spoke1.self_link
  export_custom_routes = true
  import_custom_routes = true
}

resource "google_compute_network_peering" "spoke1_to_hub" {
  name                 = "${var.project_name}-${var.environment}-spoke1-to-hub"
  network              = google_compute_network.spoke1.self_link
  peer_network         = google_compute_network.hub.self_link
  export_custom_routes = true
  import_custom_routes = true

  depends_on = [google_compute_network_peering.hub_to_spoke1]
}

resource "google_compute_network_peering" "hub_to_spoke2" {
  name                 = "${var.project_name}-${var.environment}-hub-to-spoke2"
  network              = google_compute_network.hub.self_link
  peer_network         = google_compute_network.spoke2.self_link
  export_custom_routes = true
  import_custom_routes = true

  depends_on = [google_compute_network_peering.spoke1_to_hub]
}

resource "google_compute_network_peering" "spoke2_to_hub" {
  name                 = "${var.project_name}-${var.environment}-spoke2-to-hub"
  network              = google_compute_network.spoke2.self_link
  peer_network         = google_compute_network.hub.self_link
  export_custom_routes = true
  import_custom_routes = true

  depends_on = [
    google_compute_network_peering.hub_to_spoke2,
    google_compute_network_peering.spoke1_to_hub,
  ]
}

# Firewall Rules - Hub
resource "google_compute_firewall" "hub_allow_internal" {
  name    = "${var.project_name}-${var.environment}-hub-allow-internal"
  network = google_compute_network.hub.name

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]
}

resource "google_compute_firewall" "hub_allow_ssh" {
  name    = "${var.project_name}-${var.environment}-hub-allow-ssh"
  network = google_compute_network.hub.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "hub_allow_iperf" {
  name    = "${var.project_name}-${var.environment}-hub-allow-iperf"
  network = google_compute_network.hub.name

  allow {
    protocol = "tcp"
    ports    = ["5201"]
  }
  allow {
    protocol = "udp"
    ports    = ["5201"]
  }

  source_ranges = ["10.0.0.0/8"]
}

# Firewall Rules - Spoke1
resource "google_compute_firewall" "spoke1_allow_internal" {
  name    = "${var.project_name}-${var.environment}-spoke1-allow-internal"
  network = google_compute_network.spoke1.name

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]
}

resource "google_compute_firewall" "spoke1_allow_ssh" {
  name    = "${var.project_name}-${var.environment}-spoke1-allow-ssh"
  network = google_compute_network.spoke1.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["10.20.0.0/16"]
}

# Firewall Rules - Spoke2
resource "google_compute_firewall" "spoke2_allow_internal" {
  name    = "${var.project_name}-${var.environment}-spoke2-allow-internal"
  network = google_compute_network.spoke2.name

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]
}

resource "google_compute_firewall" "spoke2_allow_ssh" {
  name    = "${var.project_name}-${var.environment}-spoke2-allow-ssh"
  network = google_compute_network.spoke2.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["10.20.0.0/16"]
}

# Compute Images and Instances
data "google_compute_image" "debian" {
  family  = "debian-11"
  project = "debian-cloud"
}

resource "google_compute_instance" "hub_vm" {
  name         = "${var.project_name}-${var.environment}-hub-vm"
  machine_type = var.machine_type
  zone         = var.zone
  labels       = local.labels

  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
    }
  }

  network_interface {
    network    = google_compute_network.hub.id
    subnetwork = google_compute_subnetwork.hub.id

    access_config {}
  }

  metadata = {
    "ssh-keys" = var.ssh_pub_key != "" ? var.ssh_pub_key : "${var.ssh_user}:placeholder-set-in-tfvars"
  }

  metadata_startup_script = "#!/bin/bash\napt-get update -y && apt-get install -y iperf3 traceroute mtr"
}

resource "google_compute_instance" "spoke1_vm" {
  name         = "${var.project_name}-${var.environment}-spoke1-vm"
  machine_type = var.machine_type
  zone         = var.zone
  labels       = local.labels

  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
    }
  }

  network_interface {
    network    = google_compute_network.spoke1.id
    subnetwork = google_compute_subnetwork.spoke1.id
  }

  metadata = {
    "ssh-keys" = var.ssh_pub_key != "" ? var.ssh_pub_key : "${var.ssh_user}:placeholder-set-in-tfvars"
  }

  metadata_startup_script = "#!/bin/bash\napt-get update -y && apt-get install -y iperf3 traceroute mtr"
}

resource "google_compute_instance" "spoke2_vm" {
  name         = "${var.project_name}-${var.environment}-spoke2-vm"
  machine_type = var.machine_type
  zone         = var.zone
  labels       = local.labels

  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
    }
  }

  network_interface {
    network    = google_compute_network.spoke2.id
    subnetwork = google_compute_subnetwork.spoke2.id
  }

  metadata = {
    "ssh-keys" = var.ssh_pub_key != "" ? var.ssh_pub_key : "${var.ssh_user}:placeholder-set-in-tfvars"
  }

  metadata_startup_script = "#!/bin/bash\napt-get update -y && apt-get install -y iperf3 traceroute mtr"
}
