#!/bin/bash
# Install Azure CLI on Fedora/RHEL-based systems

set -e

echo "Installing Azure CLI on Fedora..."
echo ""

# Import Microsoft repository key
echo "[1/4] Importing Microsoft repository key..."
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

# Add Microsoft repository
echo "[2/4] Adding Microsoft repository..."
sudo tee /etc/yum.repos.d/azure-cli.repo > /dev/null <<EOF
[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# Install Azure CLI
echo "[3/4] Installing Azure CLI..."
sudo dnf install -y azure-cli

# Verify installation
echo "[4/4] Verifying installation..."
az --version

echo ""
echo "✓ Azure CLI installed successfully!"
echo ""
echo "Next step: Run 'az login' to authenticate"
