#!/usr/bin/env bash
# SSH helper for GCP test instances
# Usage: ./ssh-gcp.sh [hub|spoke1|spoke2] [--key /path/to/key] [--project PROJECT_ID]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../../terraform/gcp"
GCP_USER="${GCP_SSH_USER:-gcpuser}"
SSH_KEY=""
TARGET="${1:-}"
GCP_PROJECT="${GCP_PROJECT_ID:-project-903fb6d7-a6c2-406c-9bb}"
GCP_ZONE="${GCP_ZONE:-us-central1-a}"

usage() {
  echo "Usage: $0 [hub|spoke1|spoke2] [--key /path/to/key] [--project PROJECT_ID] [--zone ZONE]"
  echo ""
  echo "Options:"
  echo "  hub     SSH into hub VPC VM (has external IP)"
  echo "  spoke1  SSH into spoke1 VM via hub IAP tunnel"
  echo "  spoke2  SSH into spoke2 VM via hub IAP tunnel"
  echo "  --key   Path to SSH private key"
  echo "  --project GCP Project ID"
  echo "  --zone  GCP Zone (default: us-central1-a)"
  echo ""
  echo "Environment variables:"
  echo "  GCP_PROJECT_ID  GCP project ID"
  echo "  GCP_ZONE        GCP zone"
  echo "  GCP_SSH_USER    SSH username (default: gcpuser)"
  echo "  GCP_SSH_KEY     Path to SSH private key"
  echo "  GCP_HUB_IP      Hub VM external IP"
  echo "  GCP_SPOKE1_IP   Spoke1 VM internal IP"
  echo "  GCP_SPOKE2_IP   Spoke2 VM internal IP"
  exit 1
}

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --key) SSH_KEY="$2"; shift 2 ;;
    --project) GCP_PROJECT="$2"; shift 2 ;;
    --zone) GCP_ZONE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

SSH_KEY="${SSH_KEY:-${GCP_SSH_KEY:-}}"

get_ip() {
  local output_name="$1"
  local env_var="$2"

  if [[ -n "${!env_var:-}" ]]; then
    echo "${!env_var}"
    return
  fi

  if command -v terraform &>/dev/null && [[ -d "$TERRAFORM_DIR" ]]; then
    cd "$TERRAFORM_DIR"
    local ip
    ip=$(terraform output -raw "$output_name" 2>/dev/null || echo "")
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return
    fi
  fi

  # Fall back to gcloud if available
  if command -v gcloud &>/dev/null; then
    local instance_filter
    case "$output_name" in
      hub_vm_external_ip) instance_filter="*hub*" ;;
      spoke1_vm_internal_ip) instance_filter="*spoke1*" ;;
      spoke2_vm_internal_ip) instance_filter="*spoke2*" ;;
    esac
    gcloud compute instances list \
      --project="$GCP_PROJECT" \
      --filter="name~'${instance_filter}'" \
      --format="value(networkInterfaces[0].accessConfigs[0].natIP)" \
      2>/dev/null | head -1 || echo ""
  fi
}

SSH_ARGS=(-o StrictHostKeyChecking=no -o ServerAliveInterval=30 -o ConnectTimeout=10)
if [[ -n "$SSH_KEY" ]] && [[ -f "$SSH_KEY" ]]; then
  chmod 400 "$SSH_KEY"
  SSH_ARGS+=(-i "$SSH_KEY")
fi

case "$TARGET" in
  hub)
    IP=$(get_ip "hub_vm_external_ip" "GCP_HUB_IP")
    if [[ -z "$IP" ]]; then
      echo "ERROR: Could not resolve hub VM external IP. Set GCP_HUB_IP."
      exit 1
    fi
    echo "Connecting to GCP hub VM at $IP ..."
    exec ssh "${SSH_ARGS[@]}" "${GCP_USER}@${IP}"
    ;;
  spoke1|spoke2)
    HUB_IP=$(get_ip "hub_vm_external_ip" "GCP_HUB_IP")
    if [[ -z "$HUB_IP" ]]; then
      echo "ERROR: Could not resolve hub VM external IP for jumphost. Set GCP_HUB_IP."
      exit 1
    fi
    if [[ "$TARGET" == "spoke1" ]]; then
      TARGET_IP=$(get_ip "spoke1_vm_internal_ip" "GCP_SPOKE1_IP")
    else
      TARGET_IP=$(get_ip "spoke2_vm_internal_ip" "GCP_SPOKE2_IP")
    fi
    if [[ -z "$TARGET_IP" ]]; then
      echo "ERROR: Could not resolve $TARGET VM IP. Set GCP_${TARGET^^}_IP."
      exit 1
    fi
    echo "Connecting to GCP $TARGET VM at $TARGET_IP (via hub $HUB_IP) ..."
    exec ssh "${SSH_ARGS[@]}" -J "${GCP_USER}@${HUB_IP}" "${GCP_USER}@${TARGET_IP}"
    ;;
  *)
    usage
    ;;
esac
