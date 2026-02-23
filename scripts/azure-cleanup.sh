#!/bin/bash
# Whanos Azure Infrastructure Cleanup Script
# This script helps manage or delete Azure resources

set -e

RESOURCE_GROUP="WHANOS"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║   Whanos Azure Infrastructure Manager  ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
echo ""

# Check if resource group exists
if ! az group show --name $RESOURCE_GROUP &> /dev/null; then
    echo -e "${RED}Error: Resource group '$RESOURCE_GROUP' not found${NC}"
    exit 1
fi

echo "What would you like to do?"
echo ""
echo "1) Stop all VMs (no compute charges, keeps data)"
echo "2) Start all VMs"
echo "3) Show VM status"
echo "4) Show public IPs"
echo "5) Delete everything (WARNING: irreversible!)"
echo "6) Exit"
echo ""
read -p "Enter choice [1-6]: " choice

case $choice in
    1)
        echo -e "${YELLOW}Stopping all VMs...${NC}"
        az vm deallocate --resource-group $RESOURCE_GROUP --name whanos-jenkins --no-wait
        az vm deallocate --resource-group $RESOURCE_GROUP --name whanos-registry --no-wait
        az vm deallocate --resource-group $RESOURCE_GROUP --name whanos-k8s-master --no-wait
        az vm deallocate --resource-group $RESOURCE_GROUP --name whanos-k8s-worker --no-wait
        echo -e "${GREEN}✓ VMs are being stopped (this takes 1-2 minutes)${NC}"
        echo "Check status with: az vm list --resource-group $RESOURCE_GROUP --show-details --output table"
        ;;
    
    2)
        echo -e "${YELLOW}Starting all VMs...${NC}"
        az vm start --resource-group $RESOURCE_GROUP --name whanos-jenkins --no-wait
        az vm start --resource-group $RESOURCE_GROUP --name whanos-registry --no-wait
        az vm start --resource-group $RESOURCE_GROUP --name whanos-k8s-master --no-wait
        az vm start --resource-group $RESOURCE_GROUP --name whanos-k8s-worker --no-wait
        echo -e "${GREEN}✓ VMs are being started (this takes 1-2 minutes)${NC}"
        echo "Check status with: az vm list --resource-group $RESOURCE_GROUP --show-details --output table"
        ;;
    
    3)
        echo -e "${YELLOW}VM Status:${NC}"
        az vm list --resource-group $RESOURCE_GROUP --show-details \
            --query "[].{Name:name, PowerState:powerState, PublicIP:publicIps}" \
            --output table
        ;;
    
    4)
        echo -e "${YELLOW}Public IP Addresses:${NC}"
        JENKINS_IP=$(az vm show -d --resource-group $RESOURCE_GROUP --name whanos-jenkins --query publicIps -o tsv 2>/dev/null || echo "N/A")
        REGISTRY_IP=$(az vm show -d --resource-group $RESOURCE_GROUP --name whanos-registry --query publicIps -o tsv 2>/dev/null || echo "N/A")
        K8S_MASTER_IP=$(az vm show -d --resource-group $RESOURCE_GROUP --name whanos-k8s-master --query publicIps -o tsv 2>/dev/null || echo "N/A")
        K8S_WORKER_IP=$(az vm show -d --resource-group $RESOURCE_GROUP --name whanos-k8s-worker --query publicIps -o tsv 2>/dev/null || echo "N/A")
        
        echo ""
        echo -e "  Jenkins:       ${GREEN}$JENKINS_IP${NC}  →  http://$JENKINS_IP:8080"
        echo -e "  Registry:      ${GREEN}$REGISTRY_IP${NC}  →  http://$REGISTRY_IP:5000"
        echo -e "  K8s Master:    ${GREEN}$K8S_MASTER_IP${NC}"
        echo -e "  K8s Worker:    ${GREEN}$K8S_WORKER_IP${NC}"
        echo ""
        ;;
    
    5)
        echo -e "${RED}╔════════════════════════════════════════╗${NC}"
        echo -e "${RED}║              WARNING!                  ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════╝${NC}"
        echo ""
        echo "This will DELETE:"
        echo "  - All 4 Virtual Machines"
        echo "  - All disks and data"
        echo "  - All network interfaces"
        echo "  - All public IPs"
        echo "  - The entire resource group"
        echo ""
        echo -e "${RED}This action is IRREVERSIBLE!${NC}"
        echo ""
        read -p "Type 'DELETE' to confirm: " confirm
        
        if [ "$confirm" = "DELETE" ]; then
            echo -e "${YELLOW}Deleting resource group '$RESOURCE_GROUP'...${NC}"
            az group delete --name $RESOURCE_GROUP --yes --no-wait
            echo -e "${GREEN}✓ Deletion initiated (this takes 5-10 minutes)${NC}"
            echo "Check progress with: az group show --name $RESOURCE_GROUP"
        else
            echo -e "${GREEN}Deletion cancelled${NC}"
        fi
        ;;
    
    6)
        echo "Goodbye!"
        exit 0
        ;;
    
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
