# Multi-Cloud Networking: Comparative Analysis Report

**Project:** Multi-Cloud Hub-and-Spoke Networking Lab
**Clouds:** AWS, Azure, GCP
**Date:** [INSERT DATE]

---

## Executive Summary

[2-3 paragraph summary of findings. Which cloud performed best for which use case. Key recommendation for enterprise adoption.]

---

## Architecture Overview

| Cloud  | Hub Technology     | Spoke Mechanism        | Hybrid Connectivity     |
|--------|--------------------|------------------------|-------------------------|
| AWS    | Transit Gateway    | VPC Attachments        | Site-to-Site VPN + BGP  |
| Azure  | Virtual WAN        | Virtual Hub Connections| VPN Gateway (Active-Active, BGP) |
| GCP    | VPC Peering (hub)  | Peered VPCs            | HA VPN + Cloud Router BGP |

---

## Section 1: Performance Results

### 1.1 Intra-Cloud Throughput (iperf3, 30s TCP)

| Test Path             | Cloud | Throughput (Mbps) | Retransmits | RTT (ms) |
|-----------------------|-------|-------------------|-------------|----------|
| Hub → Spoke1          | AWS   |                   |             |          |
| Hub → Spoke2          | AWS   |                   |             |          |
| Spoke1 → Spoke2       | AWS   |                   |             |          |
| Hub → Spoke1          | Azure |                   |             |          |
| Hub → Spoke2          | Azure |                   |             |          |
| Hub → Spoke1          | GCP   |                   |             |          |
| Hub → Spoke2          | GCP   |                   |             |          |

### 1.2 Intra-Cloud Latency (ping, 100 packets)

| Test Path        | Cloud | Min (ms) | Avg (ms) | Max (ms) | Packet Loss |
|------------------|-------|----------|----------|----------|-------------|
| Hub → Spoke1     | AWS   |          |          |          |             |
| Hub → Spoke2     | AWS   |          |          |          |             |
| Hub → Spoke1     | Azure |          |          |          |             |
| Hub → Spoke2     | Azure |          |          |          |             |
| Hub → Spoke1     | GCP   |          |          |          |             |
| Hub → Spoke2     | GCP   |          |          |          |             |

### 1.3 Hybrid (VPN) Throughput

| Test Path             | Throughput (Mbps) | Latency (ms) | Protocol   |
|-----------------------|-------------------|--------------|------------|
| On-Prem → AWS Hub     |                   |              | IPsec/BGP  |
| On-Prem → Azure Hub   |                   |              | IPsec/BGP  |
| On-Prem → GCP Hub     |                   |              | HA VPN/BGP |

---

## Section 2: Resilience & Failover

### 2.1 VPN Failover Test

| Cloud | Primary Link Down | Failover Time (s) | Traffic Restored? |
|-------|-------------------|-------------------|-------------------|
| AWS   | Tunnel 1 severed  |                   |                   |
| Azure | Primary IP lost   |                   |                   |
| GCP   | Tunnel 1 severed  |                   |                   |

### 2.2 Route Withdrawal (BGP)

| Cloud | BGP Session Dropped | Reroute Time (s) | Fallback Path      |
|-------|---------------------|------------------|--------------------|
| AWS   |                     |                  |                    |
| Azure |                     |                  |                    |
| GCP   |                     |                  |                    |

---

## Section 3: Security

### 3.1 Traffic Enforcement

| Control          | Cloud | Configured | Tested | Result |
|------------------|-------|------------|--------|--------|
| Spoke→Spoke deny | AWS   | NACL       | Yes    |        |
| Spoke→Spoke deny | Azure | NSG        | Yes    |        |
| Spoke→Spoke deny | GCP   | Firewall   | Yes    |        |
| Unauthorized SSH | AWS   | SG         | Yes    |        |
| Unauthorized SSH | Azure | NSG        | Yes    |        |
| Unauthorized SSH | GCP   | Firewall   | Yes    |        |

### 3.2 Flow Log Coverage

| Cloud | Log Source     | Denied Traffic Captured? | Latency to Log |
|-------|----------------|--------------------------|----------------|
| AWS   | CloudWatch     |                          |                |
| Azure | Traffic Analytics |                       |                |
| GCP   | Cloud Logging  |                          |                |

---

## Section 4: Cost Analysis

### 4.1 Estimated Monthly Costs (Lab Scale)

| Resource                  | Cloud | Unit Cost         | Lab Usage      | Est. Monthly |
|---------------------------|-------|-------------------|----------------|--------------|
| Transit Gateway           | AWS   | $0.05/hr + data   |                |              |
| TGW Attachment            | AWS   | $0.05/hr each     | 3 attachments  |              |
| VPN Connection            | AWS   | $0.05/hr          |                |              |
| Virtual WAN (Standard)    | Azure | $1.25/hr/hub      |                |              |
| VPN Gateway (VpnGw1AZ)    | Azure | ~$0.49/hr         |                |              |
| VMs (3x B1s)              | Azure | $0.0104/hr each   |                |              |
| VPC Egress                | GCP   | $0.01/GB          |                |              |
| HA VPN                    | GCP   | $0.05/hr/tunnel   |                |              |
| Compute (3x e2-micro)     | GCP   | ~$0.0084/hr each  |                |              |
| EC2 (3x t3.micro)         | AWS   | $0.0104/hr each   |                |              |
| **Total Estimated**       |       |                   |                |              |

### 4.2 Cost Observations

[Fill in after reviewing billing dashboards]

---

## Section 5: Operational Complexity

### 5.1 Route Table Management

| Cloud | Route Tables | Manual Steps | Auto-propagation | Notes |
|-------|-------------|--------------|------------------|-------|
| AWS   | Per VPC + TGW RT | TGW associations | BGP propagation | Most explicit |
| Azure | Per VWAN Hub | Virtual Hub connections | Branch-to-branch | Managed service |
| GCP   | Per VPC (custom) | Peering re-export | BGP via Cloud Router | Non-transitive peering caveat |

### 5.2 Automation Effort

| Task                    | AWS (Terraform LoC) | Azure (Terraform LoC) | GCP (Terraform LoC) |
|-------------------------|--------------------|-----------------------|---------------------|
| Hub VPC / VNet          |                    |                       |                     |
| Spoke setup             |                    |                       |                     |
| Hub connectivity        |                    |                       |                     |
| VPN + BGP               |                    |                       |                     |
| Security controls       |                    |                       |                     |
| Monitoring              |                    |                       |                     |

---

## Section 6: Enterprise Use Case Mapping

| Use Case                    | Best Fit | Reason |
|-----------------------------|----------|--------|
| Global low-latency mesh     | GCP      | Premium Tier networking, global VPC |
| Complex segmentation        | AWS      | Fine-grained TGW route tables, NACLs |
| Managed connectivity        | Azure    | Virtual WAN abstracts routing complexity |
| Cost-sensitive large scale  | GCP      | Competitive egress pricing, e2-micro |
| Hybrid enterprise (BGP)     | Azure    | ExpressRoute ecosystem, active-active VPN |
| Multi-region HA             | Azure    | Virtual WAN multi-hub support |

---

## Section 7: Conclusions and Recommendations

### 7.1 Performance
[Fill in after tests]

### 7.2 Cost
[Fill in after billing review]

### 7.3 Complexity
[Fill in]

### 7.4 Final Recommendation

For enterprise multi-cloud hub-and-spoke deployments:

1. **Primary recommendation:** [Cloud] for [reason]
2. **Hybrid connectivity:** [preferred approach]
3. **Cost optimisation:** [observation]

---

## Appendix A: Test Environment

| Cloud | Region      | VM Type        | OS                |
|-------|-------------|----------------|-------------------|
| AWS   | us-east-1   | t3.micro       | Amazon Linux 2    |
| Azure | UK South    | Standard_B1s   | Ubuntu 22.04 LTS  |
| GCP   | us-central1 | e2-micro       | Debian 11         |

## Appendix B: Tools Used

- Infrastructure: Terraform 1.6+
- Testing: iperf3, ping, traceroute, mtr
- Monitoring: CloudWatch, Azure Network Watcher + Traffic Analytics, GCP Operations Suite
- Automation: Python 3.x with boto3, azure-mgmt-network, google-cloud-compute
- Diagrams: graphviz (Python)
