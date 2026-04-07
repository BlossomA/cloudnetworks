# Multi-Cloud Networking Lab

A comprehensive study of enterprise-grade hub-and-spoke network topologies across **AWS**, **Azure**, and **GCP**, with hybrid on-premises simulation, infrastructure automation, performance testing, and comparative analysis.

## Architecture Overview

| Cloud  | Hub Technology         | Spoke Connectivity       | CIDR Range     |
|--------|------------------------|--------------------------|----------------|
| AWS    | Transit Gateway        | VPC Attachments          | 10.0.0.0/8 (10.0–10.2) |
| Azure  | Virtual WAN + Hub      | Virtual Hub Connections  | 10.10–10.12.0.0/16 |
| GCP    | VPC Peering (via hub)  | Peered VPCs              | 10.20–10.22.0.0/16 |

## Repository Structure

```
├── terraform/
│   ├── aws/          # VPCs, Transit Gateway, Flow Logs
│   ├── azure/        # VNets, Virtual WAN, NSGs
│   └── gcp/          # VPCs, Peering, Firewall rules
├── scripts/
│   ├── ssh/          # SSH helpers for all cloud VMs
│   ├── python/       # Inventory and automation scripts
│   ├── env.sh        # Environment variable loader
│   └── install_tools.sh
├── monitoring/       # CloudWatch, Network Watcher, Operations Suite setup
├── tests/            # Connectivity and performance test scripts
├── diagrams/         # Architecture diagrams
└── docs/
    ├── architecture/
    ├── test-results/
    └── analysis/
```

## Quick Start

### 1. Load environment variables
```bash
source scripts/env.sh
```

### 2. Install tools (on Azure VM or local machine)
```bash
chmod +x scripts/install_tools.sh
./scripts/install_tools.sh
```

### 3. Deploy infrastructure

**AWS:**
```bash
cd terraform/aws
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your key pair name
terraform init
terraform plan
terraform apply
```

**Azure:**
```bash
cd terraform/azure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your SSH public key
terraform init
terraform plan
terraform apply
```

**GCP:**
```bash
cd terraform/gcp
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your SSH public key
terraform init
terraform plan
terraform apply
```

### 4. SSH into VMs
```bash
chmod +x scripts/ssh/*.sh

# AWS
./scripts/ssh/ssh-aws.sh hub --key ~/.ssh/aws-lab.pem
./scripts/ssh/ssh-aws.sh spoke1 --key ~/.ssh/aws-lab.pem

# Azure
./scripts/ssh/ssh-azure.sh hub --key ~/.ssh/azure-lab
./scripts/ssh/ssh-azure.sh spoke1 --key ~/.ssh/azure-lab   # via hub jumphost

# GCP
./scripts/ssh/ssh-gcp.sh hub --key ~/.ssh/gcp-lab
./scripts/ssh/ssh-gcp.sh spoke1 --key ~/.ssh/gcp-lab       # via hub jumphost

# Legacy Azure VM (vm-cloud-lab)
./scripts/ssh/ssh-legacy-azure.sh --key ~/.ssh/your-key
```

### 5. Run tests
```bash
# Connectivity
chmod +x tests/test_connectivity.sh
./tests/test_connectivity.sh \
  --aws-hub-ip 10.0.2.x --aws-spoke1-ip 10.1.2.x --aws-spoke2-ip 10.2.2.x \
  --azure-hub-ip 10.10.1.x --azure-spoke1-ip 10.11.1.x --azure-spoke2-ip 10.12.1.x \
  --gcp-hub-ip 10.20.1.x --gcp-spoke1-ip 10.21.1.x --gcp-spoke2-ip 10.22.1.x

# Performance (run iperf3 -s on target first)
chmod +x tests/test_performance.sh
./tests/test_performance.sh --server-ip <target-ip>
```

### 6. Run inventory
```bash
cd scripts/python
pip3 install -r requirements.txt
python3 aws_inventory.py
python3 azure_inventory.py
python3 gcp_inventory.py
```

## Known Setup Actions Required

### AWS - IAM Permissions
The `cli-user` currently has no EC2/VPC policies. Attach the following in IAM console:
- `AmazonEC2FullAccess`
- `AmazonVPCFullAccess`
- `CloudWatchFullAccess`
- `IAMReadOnlyAccess`

Or attach `AdministratorAccess` for the lab duration.

### Azure - Service Principal Role Assignment
The service principal (`31e6764c-...`) needs **Contributor** access on subscription `da9b7708-...`:
1. Azure Portal → Subscriptions → `da9b7708-5f06-4d47-b2b3-13528692df47`
2. Access control (IAM) → Add role assignment
3. Role: **Contributor** → Assign to service principal `31e6764c-d46b-49e2-ad03-a63372f8a16f`

### GCP - gcloud Installation
Install gcloud SDK: https://cloud.google.com/sdk/docs/install
Then authenticate:
```bash
gcloud auth application-default login
gcloud config set project project-903fb6d7-a6c2-406c-9bb
```

## IP Addressing Scheme

| Resource                | CIDR           |
|-------------------------|----------------|
| AWS Hub VPC             | 10.0.0.0/16    |
| AWS Hub Public Subnet   | 10.0.1.0/24    |
| AWS Hub Private Subnet  | 10.0.2.0/24    |
| AWS Spoke1 VPC          | 10.1.0.0/16    |
| AWS Spoke2 VPC          | 10.2.0.0/16    |
| Azure Hub VNet          | 10.10.0.0/16   |
| Azure VWAN Hub          | 10.10.100.0/23 |
| Azure Spoke1 VNet       | 10.11.0.0/16   |
| Azure Spoke2 VNet       | 10.12.0.0/16   |
| GCP Hub VPC Subnet      | 10.20.1.0/24   |
| GCP Spoke1 VPC Subnet   | 10.21.1.0/24   |
| GCP Spoke2 VPC Subnet   | 10.22.1.0/24   |
