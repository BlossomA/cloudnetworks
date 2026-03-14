#!/usr/bin/env bash
# SSH helper for Azure test instances
# Usage: ./ssh-azure.sh [hub|spoke1|spoke2] [--key /path/to/key] [--password]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../../terraform/azure"
AZURE_USER="${AZURE_SSH_USER:-azureuser}"
SSH_KEY=""
USE_PASSWORD=false
TARGET="${1:-}"

usage() {
  echo "Usage: $0 [hub|spoke1|spoke2] [--key /path/to/key] [--password]"
  echo ""
  echo "Options:"
  echo "  hub        SSH into hub management VM (has public IP)"
  echo "  spoke1     SSH into spoke1 VM via hub jumphost"
  echo "  spoke2     SSH into spoke2 VM via hub jumphost"
  echo "  --key      Path to SSH private key"
  echo "  --password Use password authentication"
  echo ""
  echo "Environment variables:"
  echo "  AZURE_SSH_KEY    Path to SSH private key"
  echo "  AZURE_HUB_IP     Hub VM public IP"
  echo "  AZURE_SPOKE1_IP  Spoke1 VM private IP"
  echo "  AZURE_SPOKE2_IP  Spoke2 VM private IP"
  echo "  AZURE_SSH_USER   SSH username (default: azureuser)"
  exit 1
}

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --key) SSH_KEY="$2"; shift 2 ;;
    --password) USE_PASSWORD=true; shift ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

SSH_KEY="${SSH_KEY:-${AZURE_SSH_KEY:-}}"

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

  # Fall back to az CLI
  if command -v az &>/dev/null; then
    local vm_name
    case "$output_name" in
      hub_vm_public_ip) vm_name="hub" ;;
      spoke1_vm_private_ip) vm_name="spoke1" ;;
      spoke2_vm_private_ip) vm_name="spoke2" ;;
    esac
    local rg="${AZURE_RG:-rg-building-arbitrary-cloud-thesis}"
    az vm show -g "$rg" -n "*${vm_name}*" --show-details \
      --query 'publicIps' -o tsv 2>/dev/null || echo ""
  fi
}

SSH_ARGS=(-o StrictHostKeyChecking=no -o ServerAliveInterval=30 -o ConnectTimeout=10)
if [[ -n "$SSH_KEY" ]] && [[ -f "$SSH_KEY" ]]; then
  chmod 400 "$SSH_KEY"
  SSH_ARGS+=(-i "$SSH_KEY")
fi

case "$TARGET" in
  hub)
    IP=$(get_ip "hub_vm_public_ip" "AZURE_HUB_IP")
    if [[ -z "$IP" ]]; then
      echo "ERROR: Could not resolve hub VM public IP. Set AZURE_HUB_IP."
      exit 1
    fi
    echo "Connecting to Azure hub VM at $IP ..."
    exec ssh "${SSH_ARGS[@]}" "${AZURE_USER}@${IP}"
    ;;
  spoke1|spoke2)
    HUB_IP=$(get_ip "hub_vm_public_ip" "AZURE_HUB_IP")
    if [[ -z "$HUB_IP" ]]; then
      echo "ERROR: Could not resolve hub VM public IP for jumphost. Set AZURE_HUB_IP."
      exit 1
    fi
    if [[ "$TARGET" == "spoke1" ]]; then
      TARGET_IP=$(get_ip "spoke1_vm_private_ip" "AZURE_SPOKE1_IP")
    else
      TARGET_IP=$(get_ip "spoke2_vm_private_ip" "AZURE_SPOKE2_IP")
    fi
    if [[ -z "$TARGET_IP" ]]; then
      echo "ERROR: Could not resolve $TARGET VM IP. Set AZURE_${TARGET^^}_IP."
      exit 1
    fi
    echo "Connecting to Azure $TARGET VM at $TARGET_IP (via hub $HUB_IP) ..."
    JUMP_OPT="-J ${AZURE_USER}@${HUB_IP}"
    exec ssh "${SSH_ARGS[@]}" $JUMP_OPT "${AZURE_USER}@${TARGET_IP}"
    ;;
  *)
    usage
    ;;
esac
