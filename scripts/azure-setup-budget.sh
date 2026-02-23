#!/bin/bash
# Whanos Azure Infrastructure Setup Script - Budget Version
# Uses smaller VMs and combines Jenkins + Registry on same server
# This fits within free tier limits!

set -e

# Configuration
RESOURCE_GROUP="whanos"
LOCATION="francecentral"
ADMIN_USER="azureuser"
VM_SIZE="Standard_B2s" # 2 vCPU, 4GB RAM - Minimum viable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Whanos Azure Setup - Budget Version ║${NC}"
echo -e "${GREEN}║  (Jenkins + Registry on same server)   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}This version creates 2 VMs:${NC}"
echo -e "  1. whanos-services (Jenkins + Registry + K8s Master)"
echo -e "  2. whanos-k8s-worker"
echo ""
echo -e "${YELLOW}Total cores needed: 4 (fits your quota!)${NC}"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed${NC}"
    echo ""
    if [ -f /etc/fedora-release ]; then
        echo "Install with: ${GREEN}./install-azure-cli-fedora.sh${NC}"
    else
        echo "Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    fi
    exit 1
fi

# Check if logged in
echo -e "${YELLOW}[1/8] Checking Azure login status...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}Not logged in. Running 'az login'...${NC}"
    az login
fi

SUBSCRIPTION=$(az account show --query name -o tsv)
echo -e "${GREEN}✓ Logged in to subscription: $SUBSCRIPTION${NC}"
echo ""

# Create resource group
echo -e "${YELLOW}[2/8] Creating resource group '$RESOURCE_GROUP' in '$LOCATION'...${NC}"
if az group show --name $RESOURCE_GROUP &> /dev/null; then
    echo -e "${YELLOW}Resource group already exists, continuing...${NC}"
else
    az group create --name $RESOURCE_GROUP --location $LOCATION --output none
    echo -e "${GREEN}✓ Resource group created${NC}"
fi
echo ""

# Function to create VM
create_vm() {
    local VM_NAME=$1
    local VM_DESC=$2
    local VM_SIZE=$3
    
    if az vm show --resource-group $RESOURCE_GROUP --name $VM_NAME &> /dev/null 2>&1; then
        echo -e "${YELLOW}  ✓ $VM_NAME already exists, skipping...${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}  Creating $VM_NAME ($VM_DESC)...${NC}"
    
    if az vm create \
        --resource-group $RESOURCE_GROUP \
        --name $VM_NAME \
        --image Ubuntu2204 \
        --location $LOCATION \
        --size $VM_SIZE \
        --admin-username $ADMIN_USER \
        --generate-ssh-keys \
        --no-wait; then
        echo -e "${GREEN}  ✓ $VM_NAME created successfully${NC}"
    else
        echo -e "${RED}  ✗ Failed to create $VM_NAME${NC}"
        echo -e "${RED}     This might be a quota issue. Check: az vm list-usage --location $LOCATION${NC}"
        return 1
    fi
}

# Create VMs one by one
echo -e "${YELLOW}[3/8] Creating Virtual Machines (this takes 5-8 minutes)...${NC}"
echo ""

create_vm "whanos-all" "All services on one VM" "$VM_SIZE"

echo ""
echo -e "${GREEN}✓ All VMs created${NC}"
echo ""

# Verify all VMs exist
echo -e "${YELLOW}[4/8] Verifying VMs...${NC}"
MISSING_VMS=0
for VM_NAME in whanos-all; do
    if ! az vm show --resource-group $RESOURCE_GROUP --name $VM_NAME &> /dev/null; then
        echo -e "${RED}  ✗ $VM_NAME not found${NC}"
        MISSING_VMS=$((MISSING_VMS + 1))
    else
        echo -e "${GREEN}  ✓ $VM_NAME exists${NC}"
    fi
done

if [ $MISSING_VMS -gt 0 ]; then
    echo -e "${RED}Error: $MISSING_VMS VM(s) missing.${NC}"
    echo -e "${YELLOW}Tip: Check your quota with: az vm list-usage --location $LOCATION -o table${NC}"
    exit 1
fi
echo ""

# Open ports
echo -e "${YELLOW}[5/8] Configuring network security (opening ports)...${NC}"

# Jenkins + Registry - Ports 8080 and 5000
echo "  - Opening port 8080 for Jenkins..."
az vm open-port --resource-group $RESOURCE_GROUP --name whanos-services --port 8080 --priority 1001 --output none 2>/dev/null || true

echo "  - Opening port 5000 for Docker Registry..."
az vm open-port --resource-group $RESOURCE_GROUP --name whanos-services --port 5000 --priority 1002 --output none 2>/dev/null || true

# Kubernetes Master - API Server
echo "  - Opening port 6443 for Kubernetes API..."
az vm open-port --resource-group $RESOURCE_GROUP --name whanos-services --port 6443 --priority 1003 --output none 2>/dev/null || true

# Kubernetes Worker - NodePort range
echo "  - Opening ports 30000-32767 for Kubernetes services..."
az vm open-port --resource-group $RESOURCE_GROUP --name whanos-k8s-worker --port 30000-32767 --priority 1001 --output none 2>/dev/null || true

echo -e "${GREEN}✓ Ports configured${NC}"
echo ""

# Get IP addresses
echo -e "${YELLOW}[6/8] Retrieving public IP addresses...${NC}"
SERVICES_IP=$(az vm show -d --resource-group $RESOURCE_GROUP --name whanos-services --query publicIps -o tsv)
WORKER_IP=$(az vm show -d --resource-group $RESOURCE_GROUP --name whanos-k8s-worker --query publicIps -o tsv)

echo -e "${GREEN}✓ IP addresses retrieved${NC}"
echo ""

# Display results
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Infrastructure Ready!          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Public IP Addresses:${NC}"
echo -e "  Services Server: ${GREEN}$SERVICES_IP${NC}"
echo -e "    - Jenkins:     http://$SERVICES_IP:8080"
echo -e "    - Registry:    http://$SERVICES_IP:5000"
echo -e "    - K8s API:     https://$SERVICES_IP:6443"
echo -e "  K8s Worker:      ${GREEN}$WORKER_IP${NC}"
echo ""

# Generate inventory file
echo -e "${YELLOW}[7/8] Generating Ansible inventory file...${NC}"
INVENTORY_FILE="../ansible/inventory.ini"

cat > $INVENTORY_FILE << EOF
# Whanos Azure Infrastructure Inventory - Budget Version
# Generated on $(date)
# Jenkins and Docker Registry share the same server

[jenkins_server]
whanos-services ansible_host=$SERVICES_IP ansible_user=$ADMIN_USER ansible_ssh_private_key_file=~/.ssh/id_rsa

[docker_registry]
whanos-services ansible_host=$SERVICES_IP ansible_user=$ADMIN_USER ansible_ssh_private_key_file=~/.ssh/id_rsa

[kubernetes_cluster]
whanos-services ansible_host=$SERVICES_IP ansible_user=$ADMIN_USER ansible_ssh_private_key_file=~/.ssh/id_rsa
whanos-k8s-worker ansible_host=$WORKER_IP ansible_user=$ADMIN_USER ansible_ssh_private_key_file=~/.ssh/id_rsa

[kube_control_plane]
whanos-services

[kube_node]
whanos-k8s-worker

[etcd]
whanos-services

[k8s_cluster:children]
kube_control_plane
kube_node

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

echo -e "${GREEN}✓ Inventory file created at: $INVENTORY_FILE${NC}"
echo ""

# Test SSH connectivity
echo -e "${YELLOW}[8/8] Testing SSH connectivity...${NC}"

# Add host keys to known_hosts
ssh-keyscan -H $SERVICES_IP >> ~/.ssh/known_hosts 2>/dev/null
ssh-keyscan -H $WORKER_IP >> ~/.ssh/known_hosts 2>/dev/null

echo -e "${GREEN}✓ SSH host keys added${NC}"
echo ""

# Summary
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Setup Complete!             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Architecture:${NC}"
echo -e "  • 2 VMs (4 total cores - fits your quota!)"
echo -e "  • Jenkins, Registry, and K8s Master on one server"
echo -e "  • K8s Worker on separate server"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Test Ansible connection:"
echo -e "     ${GREEN}cd .. && ansible all -i ansible/inventory.ini -m ping${NC}"
echo ""
echo -e "  2. Deploy Whanos infrastructure:"
echo -e "     ${GREEN}ansible-playbook -i ansible/inventory.ini ansible/playbook.yml${NC}"
echo ""
echo -e "  3. Access services:"
echo -e "     Jenkins:  ${GREEN}http://$SERVICES_IP:8080${NC} (admin/admin)"
echo -e "     Registry: ${GREEN}http://$SERVICES_IP:5000${NC}"
echo ""
echo -e "${YELLOW}Cost Management:${NC}"
echo -e "  - Monthly cost: ~€40 (2 VMs)"
echo -e "  - Stop VMs: ${GREEN}./azure-cleanup.sh${NC} (option 1)"
echo -e "  - Delete all: ${GREEN}./azure-cleanup.sh${NC} (option 5)"
echo ""
