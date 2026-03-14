#!/usr/bin/env bash
# Enable GCP Operations Suite (Cloud Logging + Network Topology) for multi-cloud lab
# Prereqs: gcloud installed and authenticated, or uses project ID directly via API

set -euo pipefail

GCP_PROJECT="${GCP_PROJECT_ID:-project-903fb6d7-a6c2-406c-9bb}"
GCP_REGION="${GCP_REGION:-us-central1}"
PROJECT_NAME="${PROJECT_NAME:-multi-cloud-net}"

echo "=== Setting up GCP Operations Suite ==="
echo "Project: $GCP_PROJECT"

if ! command -v gcloud &>/dev/null; then
  echo "WARNING: gcloud CLI not found. Install from: https://cloud.google.com/sdk/docs/install"
  echo "After installing, run: gcloud auth application-default login"
  echo ""
  echo "Manual steps to enable monitoring:"
  echo "  1. Go to: https://console.cloud.google.com/apis/library?project=${GCP_PROJECT}"
  echo "  2. Enable: Cloud Monitoring API, Cloud Logging API, Network Topology API"
  echo "  3. Go to: https://console.cloud.google.com/net-intelligence/topology?project=${GCP_PROJECT}"
  echo "     to view the Network Topology visualization."
  exit 0
fi

gcloud config set project "$GCP_PROJECT"

echo "Enabling required APIs ..."
gcloud services enable \
  monitoring.googleapis.com \
  logging.googleapis.com \
  networkintelligence.googleapis.com \
  networkmanagement.googleapis.com \
  compute.googleapis.com \
  --project="$GCP_PROJECT"

echo "APIs enabled."

# Create a log-based metric for VPC flow log rejected traffic
echo "Creating log-based metric for firewall denies ..."
gcloud logging metrics create firewall-denies \
  --project="$GCP_PROJECT" \
  --description="Count of firewall deny rules triggered" \
  --log-filter='resource.type="gce_subnetwork" AND jsonPayload.disposition="DENIED"' \
  2>/dev/null || echo "Metric already exists."

# Create uptime check for hub VM (if external IP is known)
if [[ -n "${GCP_HUB_IP:-}" ]]; then
  echo "Creating uptime check for hub VM at $GCP_HUB_IP ..."
  # Uptime checks are best created via the console UI or Terraform
  echo "Note: Create uptime check manually in console or via Terraform (google_monitoring_uptime_check_config)"
fi

echo ""
echo "=== GCP Operations Suite setup complete ==="
echo "Network Topology: https://console.cloud.google.com/net-intelligence/topology?project=${GCP_PROJECT}"
echo "Logs Explorer:    https://console.cloud.google.com/logs/query?project=${GCP_PROJECT}"
echo "Monitoring:       https://console.cloud.google.com/monitoring?project=${GCP_PROJECT}"
