#!/usr/bin/env bash
# test_performance.sh
# Runs iperf3 TCP throughput and UDP latency tests between two cloud VMs.
# SSH-es into CLIENT_IP and targets SERVER_IP with iperf3.
#
# Prerequisites:
#   - iperf3 must be installed on both client and server VMs
#   - iperf3 server must be running: iperf3 -s -D
#
# Usage:
#   ./test_performance.sh \
#     --server-ip 10.0.1.5 \
#     --client-ip 1.2.3.4 \
#     --ssh-key ~/.ssh/id_rsa \
#     --label "aws-hub-to-spoke1" \
#     --duration 30

set -euo pipefail

# ---------------------------------------------------------------------------
# Script paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
RESULT_FILE="${RESULTS_DIR}/performance_${TIMESTAMP}.json"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
SERVER_IP=""
CLIENT_IP=""
SSH_KEY="${SSH_KEY:-${HOME}/.ssh/id_rsa}"
SSH_USER="ec2-user"
LABEL="test"
DURATION=30
UDP_BANDWIDTH="10M"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $0 --server-ip IP [OPTIONS]

  --server-ip IP     (required) IP of the iperf3 server VM
  --client-ip IP     IP of the VM to SSH into to run the iperf3 client
  --ssh-key PATH     SSH private key (default: ~/.ssh/id_rsa)
  --label LABEL      Test label used in the JSON report (default: test)
  --duration SECS    Duration of each iperf3 test in seconds (default: 30)
  -h|--help          Show this help
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server-ip)  SERVER_IP="$2";  shift 2 ;;
    --client-ip)  CLIENT_IP="$2";  shift 2 ;;
    --ssh-key)    SSH_KEY="$2";    shift 2 ;;
    --label)      LABEL="$2";      shift 2 ;;
    --duration)   DURATION="$2";   shift 2 ;;
    -h|--help)    usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

if [[ -z "$SERVER_IP" ]]; then
  echo "ERROR: --server-ip is required." >&2
  usage
fi

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
mkdir -p "$RESULTS_DIR"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "========================================================"
echo "  iperf3 Performance Test"
echo "  Label:    $LABEL"
echo "  Server:   $SERVER_IP"
echo "  Client:   ${CLIENT_IP:-<local>}"
echo "  Duration: ${DURATION}s per test"
echo "  Started:  $(date)"
echo "========================================================"

# ---------------------------------------------------------------------------
# SSH helper — runs a command on CLIENT_IP, or locally if CLIENT_IP is empty
# ---------------------------------------------------------------------------
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=15 -o BatchMode=yes"
if [[ -n "$SSH_KEY" && -f "$SSH_KEY" ]]; then
  SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
fi

run_remote() {
  if [[ -n "$CLIENT_IP" ]]; then
    # shellcheck disable=SC2086
    ssh $SSH_OPTS "${SSH_USER}@${CLIENT_IP}" "$@"
  else
    bash -c "$*"
  fi
}

# ---------------------------------------------------------------------------
# Ensure iperf3 is available on the client
# ---------------------------------------------------------------------------
if ! run_remote "command -v iperf3 >/dev/null 2>&1"; then
  echo "iperf3 not found on client. Attempting installation..."
  run_remote "apt-get install -y iperf3 2>/dev/null || yum install -y iperf3 2>/dev/null || true" || true
fi

# ---------------------------------------------------------------------------
# TCP Throughput Test
# ---------------------------------------------------------------------------
echo ""
echo "--- TCP Throughput Test (iperf3 -c ${SERVER_IP} -t ${DURATION} -J) ---"

TCP_JSON=""
TCP_STATUS=0
TCP_JSON=$(run_remote "iperf3 -c ${SERVER_IP} -t ${DURATION} -J 2>&1") || TCP_STATUS=$?

if [[ $TCP_STATUS -ne 0 || -z "$TCP_JSON" ]]; then
  echo "WARNING: TCP iperf3 test failed (exit $TCP_STATUS). Using empty result." >&2
  TCP_JSON="{}"
fi

# Parse TCP results with python3
TCP_BPS=$(echo "$TCP_JSON" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    bps = d['end']['sum_received']['bits_per_second']
    print(f'{bps:.0f}')
except Exception:
    print('0')
" 2>/dev/null || echo "0")

TCP_MBPS=$(python3 -c "
val = '${TCP_BPS}'
try:
    print(f'{int(val) / 1e6:.2f}')
except Exception:
    print('N/A')
" 2>/dev/null || echo "N/A")

TCP_RTT_US=$(echo "$TCP_JSON" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    rtt = d['end']['streams'][0]['sender']['mean_rtt']
    print(rtt)
except Exception:
    print('N/A')
" 2>/dev/null || echo "N/A")

TCP_RTT_MS=$(python3 -c "
val = '${TCP_RTT_US}'
try:
    print(f'{int(val) / 1000:.3f}')
except Exception:
    print(val)
" 2>/dev/null || echo "N/A")

TCP_RETRANS=$(echo "$TCP_JSON" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    r = d['end']['sum_sent']['retransmits']
    print(r)
except Exception:
    print('N/A')
" 2>/dev/null || echo "N/A")

echo "  Throughput:  ${TCP_MBPS} Mbps"
echo "  Mean RTT:    ${TCP_RTT_MS} ms"
echo "  Retransmits: ${TCP_RETRANS}"

# ---------------------------------------------------------------------------
# UDP Latency / Jitter Test
# ---------------------------------------------------------------------------
echo ""
echo "--- UDP Latency Test (iperf3 -c ${SERVER_IP} -u -b ${UDP_BANDWIDTH} -t ${DURATION} -J) ---"

UDP_JSON=""
UDP_STATUS=0
UDP_JSON=$(run_remote "iperf3 -c ${SERVER_IP} -u -b ${UDP_BANDWIDTH} -t ${DURATION} -J 2>&1") || UDP_STATUS=$?

if [[ $UDP_STATUS -ne 0 || -z "$UDP_JSON" ]]; then
  echo "WARNING: UDP iperf3 test failed (exit $UDP_STATUS). Using empty result." >&2
  UDP_JSON="{}"
fi

UDP_JITTER=$(echo "$UDP_JSON" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    j = d['end']['sum']['jitter_ms']
    print(f'{j:.3f}')
except Exception:
    print('N/A')
" 2>/dev/null || echo "N/A")

UDP_LOSS=$(echo "$UDP_JSON" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    lost = d['end']['sum']['lost_percent']
    print(f'{lost:.2f}')
except Exception:
    print('N/A')
" 2>/dev/null || echo "N/A")

echo "  Jitter:   ${UDP_JITTER} ms"
echo "  Loss:     ${UDP_LOSS}%"

# ---------------------------------------------------------------------------
# Human-readable summary table
# ---------------------------------------------------------------------------
echo ""
echo "========================================================"
echo "  Summary: $LABEL"
echo "========================================================"
printf "  %-20s  %-12s  %-10s  %-12s  %-12s  %-8s\n" \
  "Label" "TCP(Mbps)" "RTT(ms)" "Retransmits" "Jitter(ms)" "Loss%"
printf "  %-20s  %-12s  %-10s  %-12s  %-12s  %-8s\n" \
  "--------------------" "------------" "----------" "------------" "------------" "--------"
printf "  %-20s  %-12s  %-10s  %-12s  %-12s  %-8s\n" \
  "$LABEL" "$TCP_MBPS" "$TCP_RTT_MS" "$TCP_RETRANS" "$UDP_JITTER" "$UDP_LOSS"
echo ""

# ---------------------------------------------------------------------------
# Build JSON result record
# ---------------------------------------------------------------------------
RESULT_JSON=$(python3 -c "
import json, sys

def safe_float(val):
    try:
        return float(val)
    except (ValueError, TypeError):
        return None

def safe_int(val):
    try:
        return int(val)
    except (ValueError, TypeError):
        return None

result = {
    'label':       '${LABEL}',
    'timestamp':   '${TIMESTAMP}',
    'client_ip':   '${CLIENT_IP}',
    'server_ip':   '${SERVER_IP}',
    'duration_s':  int('${DURATION}'),
    'tcp': {
        'throughput_mbps': safe_float('${TCP_MBPS}'),
        'mean_rtt_ms':     safe_float('${TCP_RTT_MS}'),
        'retransmits':     safe_int('${TCP_RETRANS}'),
    },
    'udp': {
        'bandwidth':    '${UDP_BANDWIDTH}',
        'jitter_ms':    safe_float('${UDP_JITTER}'),
        'lost_percent': safe_float('${UDP_LOSS}'),
    },
}
print(json.dumps(result, indent=2))
" 2>/dev/null || echo '{"error": "JSON serialization failed"}')

# ---------------------------------------------------------------------------
# Append result to JSON array file
# ---------------------------------------------------------------------------
if [[ -f "$RESULT_FILE" ]]; then
  # File exists: parse existing array and append
  python3 -c "
import json, sys

with open('${RESULT_FILE}', 'r') as f:
    try:
        data = json.load(f)
    except json.JSONDecodeError:
        data = []

if not isinstance(data, list):
    data = [data]

new_entry = json.loads('''${RESULT_JSON}''')
data.append(new_entry)

with open('${RESULT_FILE}', 'w') as f:
    json.dump(data, f, indent=2)
print('Appended to existing results file.')
" 2>/dev/null || echo "[${RESULT_JSON}]" > "$RESULT_FILE"
else
  # First run: create new file with a single-element array
  echo "[${RESULT_JSON}]" > "$RESULT_FILE"
fi

echo "Results appended to: $RESULT_FILE"
echo "========================================================"
