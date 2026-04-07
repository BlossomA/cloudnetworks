#!/usr/bin/env bash
# SSH to the original Azure VM from Step 1 (vm-cloud-lab at 172.161.13.168)
# Usage: ./ssh-legacy-azure.sh [--key /path/to/key] [--user USERNAME]

set -euo pipefail

VM_IP="${LEGACY_AZURE_VM_IP:-172.161.13.168}"
VM_USER="${LEGACY_AZURE_VM_USER:-azureuser}"
SSH_KEY="${LEGACY_AZURE_SSH_KEY:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --key)  SSH_KEY="$2";  shift 2 ;;
    --user) VM_USER="$2";  shift 2 ;;
    --ip)   VM_IP="$2";    shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

SSH_ARGS=(-o StrictHostKeyChecking=no -o ServerAliveInterval=30 -o ConnectTimeout=10)
if [[ -n "$SSH_KEY" ]] && [[ -f "$SSH_KEY" ]]; then
  chmod 400 "$SSH_KEY"
  SSH_ARGS+=(-i "$SSH_KEY")
fi

echo "Connecting to legacy Azure VM (vm-cloud-lab) at $VM_IP ..."
exec ssh "${SSH_ARGS[@]}" "${VM_USER}@${VM_IP}"
