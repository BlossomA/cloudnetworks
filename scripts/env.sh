#!/usr/bin/env bash
# Source this file to set all cloud environment variables for the lab
# Usage: source scripts/env.sh
# Do NOT commit this file if you fill in real secrets — it is in .gitignore

# ─── AWS ──────────────────────────────────────────────────────────────────────
export AWS_ACCESS_KEY_ID="YOUR_AWS_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="YOUR_AWS_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_ACCOUNT_ID="416852954517"

# ─── Azure ────────────────────────────────────────────────────────────────────
export AZURE_SUBSCRIPTION_ID="da9b7708-5f06-4d47-b2b3-13528692df47"
export AZURE_TENANT_ID="4947ad8c-f569-43e6-915c-1566b0cbaee5"
export AZURE_CLIENT_ID="31e6764c-d46b-49e2-ad03-a63372f8a16f"
export AZURE_CLIENT_SECRET="YOUR_AZURE_CLIENT_SECRET"
export AZURE_RG="rg-building-arbitrary-cloud-thesis"
export AZURE_LOCATION="uksouth"

# ARM_* variables are used by the Terraform azurerm provider
export ARM_SUBSCRIPTION_ID="$AZURE_SUBSCRIPTION_ID"
export ARM_TENANT_ID="$AZURE_TENANT_ID"
export ARM_CLIENT_ID="$AZURE_CLIENT_ID"
export ARM_CLIENT_SECRET="$AZURE_CLIENT_SECRET"

# ─── GCP ──────────────────────────────────────────────────────────────────────
export GCP_PROJECT_ID="project-903fb6d7-a6c2-406c-9bb"
export GCP_REGION="us-central1"
export GCP_ZONE="us-central1-a"
export GOOGLE_CLOUD_PROJECT="$GCP_PROJECT_ID"

# ─── Common ───────────────────────────────────────────────────────────────────
export PROJECT_NAME="multi-cloud-net"
export ENVIRONMENT="lab"

# ─── SSH (fill in after key pairs are created) ───────────────────────────────
# export AWS_SSH_KEY="~/.ssh/aws-multi-cloud-lab.pem"
# export AZURE_SSH_KEY="~/.ssh/azure-multi-cloud-lab"
# export GCP_SSH_KEY="~/.ssh/gcp-multi-cloud-lab"

# ─── VM IPs (auto-populated after terraform apply) ───────────────────────────
# export AWS_HUB_IP=""
# export AWS_SPOKE1_IP=""
# export AWS_SPOKE2_IP=""
# export AZURE_HUB_IP=""
# export AZURE_SPOKE1_IP=""
# export AZURE_SPOKE2_IP=""
# export GCP_HUB_IP=""
# export GCP_SPOKE1_IP=""
# export GCP_SPOKE2_IP=""

echo "Cloud environment variables loaded."
echo "  AWS:   $AWS_DEFAULT_REGION (account $AWS_ACCOUNT_ID)"
echo "  Azure: $AZURE_SUBSCRIPTION_ID"
echo "  GCP:   $GCP_PROJECT_ID / $GCP_REGION"
