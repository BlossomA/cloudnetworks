#!/usr/bin/env bash
# test_connectivity.sh
# Tests cross-cloud hub-and-spoke connectivity by SSH-ing into hub VMs and pinging spokes.
#
# Usage:
#   ./test_connectivity.sh \
#     --aws-hub-ip 1.2.3.4   --aws-spoke1-ip 10.0.1.5  --aws-spoke2-ip 10.0.2.5 \
#     --azure-hub-ip 1.2.3.5 --azure-spoke1-ip 10.1.1.5 --azure-spoke2-ip 10.1.2.5 \
#     --gcp-hub-ip 1.2.3.6   --gcp-spoke1-ip 10.2.1.5  --gcp-spoke2-ip 10.2.2.5 \
#     --ssh-key ~/.ssh/id_rsa --count 5

set -euo pipefail

# ---------------------------------------------------------------------------
# Script paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
RESULT_FILE="${RESULTS_DIR}/connectivity_${TIMESTAMP}.txt"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
AWS_HUB_IP="${AWS_HUB_IP:-}"
AWS_SPOKE1_IP="${AWS_SPOKE1_IP:-}"
AWS_SPOKE2_IP="${AWS_SPOKE2_IP:-}"
AZURE_HUB_IP="${AZURE_HUB_IP:-}"
AZURE_SPOKE1_IP="${AZURE_SPOKE1_IP:-}"
AZURE_SPOKE2_IP="${AZURE_SPOKE2_IP:-}"
GCP_HUB_IP="${GCP_HUB_IP:-}"
GCP_SPOKE1_IP="${GCP_SPOKE1_IP:-}"
GCP_SPOKE2_IP="${GCP_SPOKE2_IP:-}"
SSH_KEY="${SSH_KEY:-${HOME}/.ssh/id_rsa}"
AWS_SSH_USER="${AWS_SSH_USER:-ec2-user}"
AZURE_SSH_USER="${AZURE_SSH_USER:-azureuser}"
GCP_SSH_USER="${GCP_SSH_USER:-gcpuser}"
COUNT=5

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
# Each entry: "PASS|label", "FAIL|label", "SKIP|label"
declare -a TEST_RESULTS=()

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

  --aws-hub-ip IP       AWS hub VM public IP (SSH entry point)
  --aws-spoke1-ip IP    AWS spoke1 VM private IP (ping target)
  --aws-spoke2-ip IP    AWS spoke2 VM private IP (ping target)
  --azure-hub-ip IP     Azure hub VM public IP
  --azure-spoke1-ip IP  Azure spoke1 VM private IP
  --azure-spoke2-ip IP  Azure spoke2 VM private IP
  --gcp-hub-ip IP       GCP hub VM external IP
  --gcp-spoke1-ip IP    GCP spoke1 VM internal IP
  --gcp-spoke2-ip IP    GCP spoke2 VM internal IP
  --ssh-key PATH        SSH private key (default: ~/.ssh/id_rsa)
  --aws-ssh-user USER   SSH user for AWS (default: ec2-user)
  --azure-ssh-user USER SSH user for Azure (default: azureuser)
  --gcp-ssh-user USER   SSH user for GCP (default: gcpuser)
  --count N             Ping count per test (default: 5)
  -h|--help             Show this help
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --aws-hub-ip)      AWS_HUB_IP="$2";      shift 2 ;;
    --aws-spoke1-ip)   AWS_SPOKE1_IP="$2";   shift 2 ;;
    --aws-spoke2-ip)   AWS_SPOKE2_IP="$2";   shift 2 ;;
    --azure-hub-ip)    AZURE_HUB_IP="$2";    shift 2 ;;
    --azure-spoke1-ip) AZURE_SPOKE1_IP="$2"; shift 2 ;;
    --azure-spoke2-ip) AZURE_SPOKE2_IP="$2"; shift 2 ;;
    --gcp-hub-ip)      GCP_HUB_IP="$2";      shift 2 ;;
    --gcp-spoke1-ip)   GCP_SPOKE1_IP="$2";   shift 2 ;;
    --gcp-spoke2-ip)   GCP_SPOKE2_IP="$2";   shift 2 ;;
    --ssh-key)         SSH_KEY="$2";          shift 2 ;;
    --aws-ssh-user)    AWS_SSH_USER="$2";     shift 2 ;;
    --azure-ssh-user)  AZURE_SSH_USER="$2";   shift 2 ;;
    --gcp-ssh-user)    GCP_SSH_USER="$2";     shift 2 ;;
    --count)           COUNT="$2";            shift 2 ;;
    -h|--help)         usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
mkdir -p "$RESULTS_DIR"

# ---------------------------------------------------------------------------
# Color helpers
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Logging: write to stdout AND results file (colors stripped in file)
# ---------------------------------------------------------------------------
log() {
  echo -e "$@" | tee -a "$RESULT_FILE"
}

log_plain() {
  echo "$@" | tee -a "$RESULT_FILE"
}

# ---------------------------------------------------------------------------
# print_result(label, pass_fail)
# ---------------------------------------------------------------------------
print_result() {
  local label="$1"
  local pass_fail="$2"
  if [[ "$pass_fail" == "PASS" ]]; then
    printf "${GREEN}[PASS]${NC} %-50s\n" "$label" | tee -a "$RESULT_FILE"
  elif [[ "$pass_fail" == "FAIL" ]]; then
    printf "${RED}[FAIL]${NC} %-50s\n" "$label" | tee -a "$RESULT_FILE"
  else
    printf "${YELLOW}[SKIP]${NC} %-50s\n" "$label" | tee -a "$RESULT_FILE"
  fi
}

# ---------------------------------------------------------------------------
# run_ping_test(label, src_ip, dst_ip, ssh_key, count, ssh_user, ssh_key_for_cloud)
# ---------------------------------------------------------------------------
run_ping_test() {
  local label="$1"
  local src_ip="$2"
  local dst_ip="$3"
  local ssh_key="$4"
  local count="$5"
  local ssh_user="${6:-ec2-user}"
  local cloud_key="${7:-}"

  # Use cloud-specific key if provided
  local effective_key="${cloud_key:-$ssh_key}"

  # Skip if IPs not provided
  if [[ -z "$src_ip" || -z "$dst_ip" ]]; then
    print_result "$label" "SKIP"
    TEST_RESULTS+=("SKIP|$label")
    (( SKIP_COUNT++ )) || true
    return
  fi

  log_plain "  Testing: $label  ($src_ip -> ping $dst_ip, count=$count, user=$ssh_user)"

  local ssh_opts="-o StrictHostKeyChecking=no -o ConnectTimeout=15 -o BatchMode=yes"
  if [[ -n "$effective_key" && -f "$effective_key" ]]; then
    ssh_opts="$ssh_opts -i $effective_key"
  fi

  local ping_output
  local ssh_status=0
  # shellcheck disable=SC2086
  ping_output=$(ssh $ssh_opts "${ssh_user}@${src_ip}" \
    "ping -c ${count} -W 2 ${dst_ip}" 2>&1) || ssh_status=$?

  if [[ $ssh_status -ne 0 && -z "$ping_output" ]]; then
    log_plain "  SSH connection failed (exit code $ssh_status)."
    print_result "$label" "FAIL"
    TEST_RESULTS+=("FAIL|$label|SSH connection failed")
    (( FAIL_COUNT++ )) || true
    return
  fi

  local loss_pct=""
  loss_pct=$(echo "$ping_output" | grep -oE '[0-9]+% packet loss' | grep -oE '^[0-9]+' | head -1 || true)

  local summary_line
  summary_line=$(echo "$ping_output" | grep -E "packet loss" | head -1 || true)
  log_plain "  Result: $summary_line"

  if [[ -z "$loss_pct" ]]; then
    log_plain "  Could not parse packet loss percentage. Treating as FAIL."
    print_result "$label" "FAIL"
    TEST_RESULTS+=("FAIL|$label|parse error")
    (( FAIL_COUNT++ )) || true
  elif [[ "$loss_pct" -eq 0 ]]; then
    print_result "$label" "PASS"
    TEST_RESULTS+=("PASS|$label|0% loss")
    (( PASS_COUNT++ )) || true
  else
    log_plain "  Packet loss: ${loss_pct}%"
    print_result "$label" "FAIL"
    TEST_RESULTS+=("FAIL|$label|${loss_pct}% loss")
    (( FAIL_COUNT++ )) || true
  fi
}

# ---------------------------------------------------------------------------
# Main test execution
# ---------------------------------------------------------------------------
# Determine cloud-specific SSH keys
AWS_KEY="${AWS_KEY:-$SSH_KEY}"
AZURE_KEY="${AZURE_KEY:-${HOME}/.ssh/multi-cloud-lab-azure}"
GCP_KEY="${GCP_KEY:-$SSH_KEY}"

log "========================================================"
log "  Connectivity Test Suite"
log "  Started:  $(date)"
log "  SSH Key:  $SSH_KEY"
log "  AWS User/Key: $AWS_SSH_USER / $AWS_KEY"
log "  Azure User/Key: $AZURE_SSH_USER / $AZURE_KEY"
log "  GCP User/Key: $GCP_SSH_USER / $GCP_KEY"
log "  Ping Count: $COUNT"
log "  Results:  $RESULT_FILE"
log "========================================================"

# --- AWS ---
log ""
log "--- AWS Hub-and-Spoke ---"
run_ping_test "AWS Hub -> Spoke1"  "$AWS_HUB_IP"  "$AWS_SPOKE1_IP"  "$SSH_KEY" "$COUNT" "$AWS_SSH_USER"  "$AWS_KEY"
run_ping_test "AWS Hub -> Spoke2"  "$AWS_HUB_IP"  "$AWS_SPOKE2_IP"  "$SSH_KEY" "$COUNT" "$AWS_SSH_USER"  "$AWS_KEY"

# --- Azure ---
log ""
log "--- Azure Hub-and-Spoke ---"
run_ping_test "Azure Hub -> Spoke1"  "$AZURE_HUB_IP"  "$AZURE_SPOKE1_IP"  "$SSH_KEY" "$COUNT" "$AZURE_SSH_USER" "$AZURE_KEY"
run_ping_test "Azure Hub -> Spoke2"  "$AZURE_HUB_IP"  "$AZURE_SPOKE2_IP"  "$SSH_KEY" "$COUNT" "$AZURE_SSH_USER" "$AZURE_KEY"

# --- GCP ---
log ""
log "--- GCP Hub-and-Spoke ---"
run_ping_test "GCP Hub -> Spoke1"  "$GCP_HUB_IP"  "$GCP_SPOKE1_IP"  "$SSH_KEY" "$COUNT" "$GCP_SSH_USER"  "$GCP_KEY"
run_ping_test "GCP Hub -> Spoke2"  "$GCP_HUB_IP"  "$GCP_SPOKE2_IP"  "$SSH_KEY" "$COUNT" "$GCP_SSH_USER"  "$GCP_KEY"

# ---------------------------------------------------------------------------
# Final summary table
# ---------------------------------------------------------------------------
TOTAL_COUNT=$(( PASS_COUNT + FAIL_COUNT + SKIP_COUNT ))

log ""
log "========================================================"
log "  FINAL SUMMARY"
log "========================================================"
printf "  %-50s  %-6s\n" "Test" "Result" | tee -a "$RESULT_FILE"
printf "  %-50s  %-6s\n" "--------------------------------------------------" "------" | tee -a "$RESULT_FILE"

for entry in "${TEST_RESULTS[@]}"; do
  status="${entry%%|*}"
  rest="${entry#*|}"
  label="${rest%%|*}"
  detail="${rest#*|}"

  if [[ "$status" == "PASS" ]]; then
    printf "  ${GREEN}%-50s  PASS${NC}\n" "$label" | tee -a "$RESULT_FILE"
  elif [[ "$status" == "FAIL" ]]; then
    printf "  ${RED}%-50s  FAIL${NC}  ($detail)\n" "$label" | tee -a "$RESULT_FILE"
  else
    printf "  ${YELLOW}%-50s  SKIP${NC}\n" "$label" | tee -a "$RESULT_FILE"
  fi
done

log ""
log_plain "  Total: $TOTAL_COUNT  |  Pass: $PASS_COUNT  |  Fail: $FAIL_COUNT  |  Skip: $SKIP_COUNT"
log ""
log_plain "  Full results saved to: $RESULT_FILE"
log "========================================================"

# Exit non-zero if any test failed
if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 1
fi
exit 0
