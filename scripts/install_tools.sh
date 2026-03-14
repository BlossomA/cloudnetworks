#!/usr/bin/env bash
# Install required tools on the Azure VM (Ubuntu/Debian) or local machine
# Run as root or with sudo on the target VM
# Usage: curl -sL <url> | bash  OR  ./install_tools.sh

set -euo pipefail

OS="$(uname -s)"
ARCH="$(uname -m)"

echo "=== Multi-Cloud Networking Lab - Tool Installer ==="
echo "OS: $OS | Arch: $ARCH"

install_debian() {
  apt-get update -q
  apt-get install -y \
    curl wget unzip git \
    python3 python3-pip python3-venv \
    iperf3 traceroute iputils-ping \
    jq netcat-openbsd nmap \
    tcpdump mtr

  # Terraform
  if ! command -v terraform &>/dev/null; then
    echo "Installing Terraform ..."
    TERRAFORM_VER="1.6.6"
    wget -qO /tmp/terraform.zip \
      "https://releases.hashicorp.com/terraform/${TERRAFORM_VER}/terraform_${TERRAFORM_VER}_linux_amd64.zip"
    unzip -q /tmp/terraform.zip -d /usr/local/bin/
    rm /tmp/terraform.zip
    terraform version
  else
    echo "Terraform already installed: $(terraform version | head -1)"
  fi

  # AWS CLI v2
  if ! command -v aws &>/dev/null; then
    echo "Installing AWS CLI ..."
    curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscli.zip
    unzip -q /tmp/awscli.zip -d /tmp/
    /tmp/aws/install
    rm -rf /tmp/aws /tmp/awscli.zip
    aws --version
  else
    echo "AWS CLI already installed: $(aws --version)"
  fi

  # Azure CLI
  if ! command -v az &>/dev/null; then
    echo "Installing Azure CLI ..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash
    az version
  else
    echo "Azure CLI already installed."
  fi

  # gcloud SDK
  if ! command -v gcloud &>/dev/null; then
    echo "Installing gcloud SDK ..."
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
      | tee /etc/apt/sources.list.d/google-cloud-sdk.list
    curl -sL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
      | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
    apt-get update -q && apt-get install -y google-cloud-cli
    gcloud version
  else
    echo "gcloud already installed."
  fi
}

install_python_deps() {
  echo "Installing Python dependencies ..."
  cd "$(dirname "${BASH_SOURCE[0]}")/../scripts/python" 2>/dev/null || true
  if [[ -f requirements.txt ]]; then
    pip3 install --quiet -r requirements.txt
    echo "Python deps installed."
  else
    pip3 install --quiet boto3 azure-mgmt-network azure-identity google-cloud-compute tabulate
    echo "Python deps installed (direct)."
  fi
}

case "$OS" in
  Linux)
    if command -v apt-get &>/dev/null; then
      install_debian
      install_python_deps
    else
      echo "Non-Debian Linux detected. Install manually:"
      echo "  terraform, aws-cli, azure-cli, gcloud, iperf3, python3, pip3"
    fi
    ;;
  Darwin)
    if command -v brew &>/dev/null; then
      echo "macOS with Homebrew detected. Installing ..."
      brew install terraform awscli azure-cli iperf3 mtr jq
      echo "Note: Install gcloud from https://cloud.google.com/sdk/docs/install"
      install_python_deps
    else
      echo "Install Homebrew first: https://brew.sh"
      exit 1
    fi
    ;;
  *)
    echo "Unsupported OS: $OS"
    exit 1
    ;;
esac

echo ""
echo "=== Tool installation complete ==="
terraform version | head -1
aws --version
az version 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print('az', d.get('azure-cli','?'))" 2>/dev/null || true
command -v gcloud &>/dev/null && gcloud version | head -1 || echo "gcloud: not installed"
iperf3 --version 2>/dev/null | head -1 || echo "iperf3: not found"
python3 --version
