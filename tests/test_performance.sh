#!/usr/bin/env bash
# Performance test — runs iperf3 TCP/UDP tests between cloud VMs
# Prereq: iperf3 must be running as server on the target VM (iperf3 -s -D)
# Usage: ./test_performance.sh --client-ip X --server-ip X --label "aws-hub-to-spoke1" --ssh-key ~/.ssh/key.pem

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILE="${RESULTS_DIR}/performance_${TIMESTAMP}.json"

CLIENT_IP=""
SERVER_IP=""
SSH_KEY="${AWS_SSH_KEY:-}"
SSH_USER="ec2-user"
LABEL="test"
DURATION=30
UDP_BANDWIDTH="10M"

usage() {
  echo "Usage: $0 --client-ip IP --server-ip IP [OPTIONS]"
  echo "  --client-ip IP    IP of the VM to SSH into (runs iperf3 client)"
  echo "  --server-ip IP    IP of the iperf3 server (target)"
  echo "  --ssh-key PATH    SSH private key"
  echo "  --user USER       SSH user (default: ec2-user)"
  echo "  --label LABEL     Test label for the report"
  echo "  --duration SECS   Test duration in seconds (default: 30)"
  echo "  --udp-bw BW       UDP test bandwidth (default: 10M)"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --client-ip)  CLIENT_IP="$2";    shift 2 ;;
    --server-ip)  SERVER_IP="$2";    shift 2 ;;
    --ssh-key)    SSH_KEY="$2";      shift 2 ;;
    --user)       SSH_USER="$2";     shift 2 ;;
    --label)      LABEL="$2";        shift 2 ;;
    --duration)   DURATION="$2";     shift 2 ;;
    --udp-bw)     UDP_BANDWIDTH="$2"; shift 2 ;;
    -h|--help)    usage ;;
    *) echo "Unknown: $1"; usage ;;
  esac
done

if [[ -z "$CLIENT_IP" || -z "$SERVER_IP" ]]; then
  echo "ERROR: --client-ip and --server-ip are required"
  usage
fi

mkdir -p "$RESULTS_DIR"

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=15 -o BatchMode=yes"
if [[ -n "$SSH_KEY" && -f "$SSH_KEY" ]]; then
  SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
fi

run_ssh() {
  ssh $SSH_OPTS "${SSH_USER}@${CLIENT_IP}" "$@"
}

echo "=== iperf3 Performance Test ==="
echo "  Label:    $LABEL"
echo "  Client:   $CLIENT_IP ($SSH_USER)"
echo "  Server:   $SERVER_IP"
echo "  Duration: ${DURATION}s"
echo ""

# Ensure iperf3 is installed on client
run_ssh "command -v iperf3 >/dev/null || (apt-get install -y iperf3 2>/dev/null || yum install -y iperf3 2>/dev/null)" 2>/dev/null || true

echo "--- TCP Throughput Test ---"
TCP_JSON=$(run_ssh "iperf3 -c ${SERVER_IP} -t ${DURATION} -J 2>&1") || TCP_JSON="{}"

TCP_BPS=$(echo "$TCP_JSON" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    bps = d['end']['sum_received']['bits_per_second']
    print(f'{bps:.0f}')
except:
    print('0')
" 2>/dev/null || echo "0")

TCP_MBPS=$(python3 -c "print(f'{int(\"${TCP_BPS}\") / 1e6:.2f}')" 2>/dev/null || echo "N/A")

TCP_RTT=$(echo "$TCP_JSON" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    rtt = d['end']['streams'][0]['sender']['mean_rtt']
    print(f'{rtt/1000:.3f}')
except:
    print('N/A')
" 2>/dev/null || echo "N/A")

TCP_RETRANS=$(echo "$TCP_JSON" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    r = d['end']['sum_sent']['retransmits']
    print(r)
except:
    print('N/A')
" 2>/dev/null || echo "N/A")

echo "  Throughput: ${TCP_MBPS} Mbps"
echo "  Mean RTT:   ${TCP_RTT} ms"
echo "  Retransmits: ${TCP_RETRANS}"

echo ""
echo "--- UDP Latency Test (${UDP_BANDWIDTH}) ---"
UDP_JSON=$(run_ssh "iperf3 -c ${SERVER_IP} -u -b ${UDP_BANDWIDTH} -t ${DURATION} -J 2>&1") || UDP_JSON="{}"

UDP_JITTER=$(echo "$UDP_JSON" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    j = d['end']['sum']['jitter_ms']
    print(f'{j:.3f}')
except:
    print('N/A')
" 2>/dev/null || echo "N/A")

UDP_LOSS=$(echo "$UDP_JSON" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    lost = d['end']['sum']['lost_percent']
    print(f'{lost:.2f}')
except:
    print('N/A')
" 2>/dev/null || echo "N/A")

echo "  Jitter:    ${UDP_JITTER} ms"
echo "  Loss:      ${UDP_LOSS}%"

# Build JSON result
RESULT=$(python3 -c "
import json, sys
result = {
    'label': '${LABEL}',
    'timestamp': '${TIMESTAMP}',
    'client_ip': '${CLIENT_IP}',
    'server_ip': '${SERVER_IP}',
    'duration_s': ${DURATION},
    'tcp': {
        'throughput_mbps': float('${TCP_MBPS}') if '${TCP_MBPS}' != 'N/A' else None,
        'mean_rtt_ms': float('${TCP_RTT}') if '${TCP_RTT}' != 'N/A' else None,
        'retransmits': '${TCP_RETRANS}',
    },
    'udp': {
        'bandwidth': '${UDP_BANDWIDTH}',
        'jitter_ms': float('${UDP_JITTER}') if '${UDP_JITTER}' != 'N/A' else None,
        'loss_percent': float('${UDP_LOSS}') if '${UDP_LOSS}' != 'N/A' else None,
    }
}
print(json.dumps(result, indent=2))
")

# Append to results file (as JSON array)
if [[ -f "$RESULT_FILE" ]]; then
  python3 -c "
import json
with open('${RESULT_FILE}') as f:
    data = json.load(f)
data.append(${RESULT})
with open('${RESULT_FILE}', 'w') as f:
    json.dump(data, f, indent=2)
"
else
  echo "[${RESULT}]" > "$RESULT_FILE"
fi

echo ""
echo "=== Summary ==="
printf "  %-20s %12s %10s %10s %10s %8s\n" "Label" "TCP(Mbps)" "RTT(ms)" "Retrans" "Jitter(ms)" "Loss%"
printf "  %-20s %12s %10s %10s %10s %8s\n" "$LABEL" "$TCP_MBPS" "$TCP_RTT" "$TCP_RETRANS" "$UDP_JITTER" "$UDP_LOSS"
echo ""
echo "Result appended to: $RESULT_FILE"
