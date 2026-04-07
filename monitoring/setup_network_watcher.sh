#!/usr/bin/env bash
# Set up Azure Network Watcher connection monitors and flow logs
# Prereqs: az CLI logged in with service principal, Terraform already deployed

set -euo pipefail

SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-da9b7708-5f06-4d47-b2b3-13528692df47}"
TENANT_ID="${AZURE_TENANT_ID:-4947ad8c-f569-43e6-915c-1566b0cbaee5}"
CLIENT_ID="${AZURE_CLIENT_ID:-31e6764c-d46b-49e2-ad03-a63372f8a16f}"
CLIENT_SECRET="${AZURE_CLIENT_SECRET:-oVs8Q~zwDXJObdG8rUkRERJPShtpq_UvESVvDbdN}"
RG="${AZURE_RG:-rg-building-arbitrary-cloud-thesis}"
LOCATION="${AZURE_LOCATION:-uksouth}"
PROJECT="${PROJECT_NAME:-multi-cloud-net}"

echo "=== Logging into Azure ==="
az login --service-principal \
  --tenant "$TENANT_ID" \
  --username "$CLIENT_ID" \
  --password "$CLIENT_SECRET" \
  --allow-no-subscriptions > /dev/null

az account set --subscription "$SUBSCRIPTION_ID" 2>/dev/null || {
  echo "WARNING: Could not set subscription $SUBSCRIPTION_ID."
  echo "Ensure the service principal has Contributor role on the subscription."
  echo "In Azure Portal: Subscriptions > $SUBSCRIPTION_ID > Access control (IAM) > Add role assignment"
  echo "  Role: Contributor"
  echo "  Assign access to: Service principal"
  echo "  Select: (Client ID) $CLIENT_ID"
  exit 1
}

echo "=== Setting up Network Watcher ==="

# Ensure Network Watcher exists
NW_NAME="NetworkWatcher_${LOCATION}"
echo "Checking Network Watcher in $LOCATION ..."
az network watcher configure \
  --locations "$LOCATION" \
  --enabled true \
  --resource-group "$RG" 2>/dev/null || echo "Network Watcher already configured."

# Get hub VM resource ID
HUB_VM_ID=$(az vm show --resource-group "$RG" --name "${PROJECT}-hub-vm" \
  --query id -o tsv 2>/dev/null || echo "")

SPOKE1_VM_ID=$(az vm show --resource-group "$RG" --name "${PROJECT}-spoke1-vm" \
  --query id -o tsv 2>/dev/null || echo "")

SPOKE2_VM_ID=$(az vm show --resource-group "$RG" --name "${PROJECT}-spoke2-vm" \
  --query id -o tsv 2>/dev/null || echo "")

# Connection Monitor: hub -> spoke1
if [[ -n "$HUB_VM_ID" && -n "$SPOKE1_VM_ID" ]]; then
  echo "Creating connection monitor: hub -> spoke1 ..."
  az network watcher connection-monitor create \
    --name "${PROJECT}-hub-to-spoke1" \
    --resource-group "$RG" \
    --location "$LOCATION" \
    --source-resource "$HUB_VM_ID" \
    --dest-resource "$SPOKE1_VM_ID" \
    --dest-port 22 \
    --monitoring-interval 30 2>/dev/null || echo "Connection monitor hub->spoke1 already exists."
fi

# Connection Monitor: hub -> spoke2
if [[ -n "$HUB_VM_ID" && -n "$SPOKE2_VM_ID" ]]; then
  echo "Creating connection monitor: hub -> spoke2 ..."
  az network watcher connection-monitor create \
    --name "${PROJECT}-hub-to-spoke2" \
    --resource-group "$RG" \
    --location "$LOCATION" \
    --source-resource "$HUB_VM_ID" \
    --dest-resource "$SPOKE2_VM_ID" \
    --dest-port 22 \
    --monitoring-interval 30 2>/dev/null || echo "Connection monitor hub->spoke2 already exists."
fi

echo ""
echo "=== Network Watcher setup complete ==="
echo "View in portal: https://portal.azure.com/#blade/Microsoft_Azure_Network/NetworkWatcherMenuBlade/overview"
