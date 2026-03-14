#!/usr/bin/env bash
# Set up CloudWatch dashboards and alarms for AWS multi-cloud networking lab
# Prereqs: AWS CLI configured, VPC Flow Logs already enabled via Terraform

set -euo pipefail

AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
PROJECT="${PROJECT_NAME:-multi-cloud-net}"
LOG_GROUP="/aws/vpc/flow-logs"

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
export AWS_DEFAULT_REGION="${AWS_REGION}"

echo "=== Setting up CloudWatch for AWS ==="

# 1. Create dashboard
DASHBOARD_BODY=$(cat <<EOF
{
  "widgets": [
    {
      "type": "log",
      "x": 0, "y": 0, "width": 24, "height": 6,
      "properties": {
        "title": "VPC Flow Logs - Rejected Traffic",
        "query": "SOURCE '${LOG_GROUP}' | fields @timestamp, srcAddr, dstAddr, srcPort, dstPort, protocol, action | filter action = 'REJECT' | sort @timestamp desc | limit 50",
        "region": "${AWS_REGION}",
        "view": "table"
      }
    },
    {
      "type": "log",
      "x": 0, "y": 6, "width": 24, "height": 6,
      "properties": {
        "title": "VPC Flow Logs - Cross-VPC Traffic (10.0.0.0/8)",
        "query": "SOURCE '${LOG_GROUP}' | fields @timestamp, srcAddr, dstAddr, bytes, packets | filter srcAddr like /^10\\./ and dstAddr like /^10\\./ | stats sum(bytes) as totalBytes by srcAddr, dstAddr | sort totalBytes desc",
        "region": "${AWS_REGION}",
        "view": "table"
      }
    },
    {
      "type": "metric",
      "x": 0, "y": 12, "width": 12, "height": 6,
      "properties": {
        "title": "Transit Gateway Bytes In",
        "metrics": [["AWS/TransitGateway", "BytesIn"]],
        "period": 300,
        "region": "${AWS_REGION}",
        "view": "timeSeries"
      }
    },
    {
      "type": "metric",
      "x": 12, "y": 12, "width": 12, "height": 6,
      "properties": {
        "title": "Transit Gateway Bytes Out",
        "metrics": [["AWS/TransitGateway", "BytesOut"]],
        "period": 300,
        "region": "${AWS_REGION}",
        "view": "timeSeries"
      }
    }
  ]
}
EOF
)

DASHBOARD_TMPFILE=$(mktemp /tmp/cw-dashboard-XXXXXX.json)
echo "$DASHBOARD_BODY" > "$DASHBOARD_TMPFILE"

echo "Creating CloudWatch dashboard: ${PROJECT}-network ..."
aws cloudwatch put-dashboard \
  --dashboard-name "${PROJECT}-network" \
  --dashboard-body "file://${DASHBOARD_TMPFILE}" \
  --region "$AWS_REGION"
rm -f "$DASHBOARD_TMPFILE"
echo "Dashboard created."

# 2. Create metric filter for rejected flows
echo "Creating metric filter for rejected flows ..."
aws logs put-metric-filter \
  --log-group-name "$LOG_GROUP" \
  --filter-name "RejectedFlows" \
  --filter-pattern '[version, accountId, interfaceId, srcAddr, dstAddr, srcPort, dstPort, protocol, packets, bytes, start, end, action="REJECT", logStatus]' \
  --metric-transformations \
    metricName=RejectedFlowCount,metricNamespace="${PROJECT}/VPCFlowLogs",metricValue=1,defaultValue=0 \
  --region "$AWS_REGION" 2>/dev/null || echo "Metric filter already exists, skipping."

# 3. Create alarm for high rejected flows
echo "Creating alarm for rejected flows ..."
aws cloudwatch put-metric-alarm \
  --alarm-name "${PROJECT}-high-rejected-flows" \
  --alarm-description "Alert when rejected VPC flows exceed threshold" \
  --metric-name RejectedFlowCount \
  --namespace "${PROJECT}/VPCFlowLogs" \
  --statistic Sum \
  --period 300 \
  --threshold 100 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --treat-missing-data notBreaching \
  --region "$AWS_REGION" 2>/dev/null || echo "Alarm already exists, skipping."

echo ""
echo "=== CloudWatch setup complete ==="
echo "Dashboard: https://console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#dashboards:name=${PROJECT}-network"
echo "Log group:  ${LOG_GROUP}"
