#!/usr/bin/env bash
# SSH helper for AWS test instances
# Usage: ./ssh-aws.sh [hub|spoke1|spoke2] [--key /path/to/key.pem]
# Reads instance IPs from Terraform outputs automatically if terraform is available

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../../terraform/aws"
AWS_USER="ec2-user"
SSH_KEY=""
TARGET="${1:-}"

usage() {
  echo "Usage: $0 [hub|spoke1|spoke2] [--key /path/to/key.pem]"
  echo ""
  echo "Options:"
  echo "  hub     SSH into the hub VPC test instance"
  echo "  spoke1  SSH into spoke1 VPC test instance"
  echo "  spoke2  SSH into spoke2 VPC test instance"
  echo "  --key   Path to SSH private key (.pem file)"
  echo ""
  echo "Environment variables:"
  echo "  AWS_SSH_KEY   Path to SSH key (alternative to --key)"
  echo "  AWS_HUB_IP    Hub instance IP (overrides Terraform output)"
  echo "  AWS_SPOKE1_IP Spoke1 instance IP"
  echo "  AWS_SPOKE2_IP Spoke2 instance IP"
  exit 1
}

# Parse arguments
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --key) SSH_KEY="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Resolve SSH key
SSH_KEY="${SSH_KEY:-${AWS_SSH_KEY:-}}"
if [[ -z "$SSH_KEY" ]]; then
  echo "ERROR: No SSH key provided. Use --key /path/to/key.pem or set AWS_SSH_KEY"
  exit 1
fi

if [[ ! -f "$SSH_KEY" ]]; then
  echo "ERROR: SSH key not found: $SSH_KEY"
  exit 1
fi

chmod 400 "$SSH_KEY"

# Resolve target IP from Terraform outputs or env vars
get_ip() {
  local output_name="$1"
  local env_var="$2"

  # Check env var first
  if [[ -n "${!env_var:-}" ]]; then
    echo "${!env_var}"
    return
  fi

  # Try Terraform output
  if command -v terraform &>/dev/null && [[ -d "$TERRAFORM_DIR" ]]; then
    cd "$TERRAFORM_DIR"
    local ip
    ip=$(terraform output -raw "$output_name" 2>/dev/null || echo "")
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return
    fi
  fi

  echo ""
}

case "$TARGET" in
  hub)
    IP=$(get_ip "hub_test_instance_ip" "AWS_HUB_IP")
    ;;
  spoke1)
    IP=$(get_ip "spoke1_test_instance_ip" "AWS_SPOKE1_IP")
    ;;
  spoke2)
    IP=$(get_ip "spoke2_test_instance_ip" "AWS_SPOKE2_IP")
    ;;
  *)
    usage
    ;;
esac

if [[ -z "$IP" ]]; then
  echo "ERROR: Could not resolve IP for '$TARGET'."
  echo "Set AWS_${TARGET^^}_IP or run 'terraform apply' in $TERRAFORM_DIR first."
  exit 1
fi

echo "Connecting to AWS $TARGET at $IP ..."
exec ssh -i "$SSH_KEY" \
  -o StrictHostKeyChecking=no \
  -o ServerAliveInterval=30 \
  -o ConnectTimeout=10 \
  "${AWS_USER}@${IP}"
