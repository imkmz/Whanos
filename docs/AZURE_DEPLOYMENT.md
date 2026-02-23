# 🔷 Azure Deployment Guide

Complete guide to deploy Whanos infrastructure on Microsoft Azure.

---

## 📋 Prerequisites

- Azure account (get free student credits: https://azure.microsoft.com/free/students/)
- Fedora/Linux machine
- SSH keys configured

---

## Step 1: Install Azure CLI (One-time setup)

### On Fedora:
```bash
cd /home/johan/delivery/tek3/whanos/scripts
./install-azure-cli-fedora.sh
```

### Verify:
```bash
az --version
```

---

## Step 2: Login to Azure

```bash
az login
```

This opens your browser for authentication.

---

## Step 3: Deploy Infrastructure

### Create VMs:
```bash
cd /scripts
./azure-setup-budget.sh
```

**What it creates:**
- 2 VMs (4 cores total - fits free tier quota)
- VM 1: `whanos-services` (Jenkins + Registry + K8s Master)
- VM 2: `whanos-k8s-worker` (K8s Worker)
- Opens required ports (8080, 5000, 6443, 30000-32767)
- Generates `ansible/inventory.ini` with IPs

**Time:** ~5-8 minutes

---

## Step 4: Test Connection

```bash
ansible all -i ansible/inventory.ini -m ping
```

**Expected output:**
```
whanos-services | SUCCESS => {"ping": "pong"}
whanos-k8s-worker | SUCCESS => {"ping": "pong"}
```

---

## Step 5: Deploy Whanos (After Ansible roles are written)

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

---

## 🛠️ VM Management

### Stop VMs (save money):
```bash
cd /scripts
./azure-cleanup.sh
# Choose option 1
```

**Cost when stopped:** ~€5/month (storage only)

### Start VMs:
```bash
./azure-cleanup.sh
# Choose option 2
```

### Check status:
```bash
./azure-cleanup.sh
# Choose option 3
```

### View IPs:
```bash
./azure-cleanup.sh
# Choose option 4
```

### Delete everything:
```bash
./azure-cleanup.sh
# Choose option 5
```

---

## 📊 Infrastructure Details

### Architecture:
```
Internet
│
├── whanos-services (172.201.193.14)
│   ├── Jenkins :8080
│   ├── Docker Registry :5000
│   └── Kubernetes Master :6443
│
└── whanos-k8s-worker
    └── Kubernetes Worker (NodePort 30000-32767)
```

### VM Specifications:
- **Size:** Standard_B2s (2 vCPU, 4GB RAM each)
- **OS:** Ubuntu 22.04
- **Total cores:** 4 (fits free tier quota)
- **Public IPs:** 2

### Cost:
- **Running 24/7:** ~€40/month
- **Stopped:** ~€5/month (storage only)
- **With Azure Student:** FREE ($100 credit)

---

## 🔧 Troubleshooting

### "ResourceGroupBeingDeleted" error
Wait 3-5 minutes for deletion to complete:
```bash
az group show --name whanos-rg
```

### "Quota exceeded" error
You hit the 4-core limit. The budget script is designed for this.

### Can't SSH to VMs
```bash
# Check if VMs are running
./azure-cleanup.sh  # option 3

# Start VMs if stopped
./azure-cleanup.sh  # option 2
```

### Ansible ping fails
```bash
# Add SSH keys
ssh-keyscan -H <VM_IP> >> ~/.ssh/known_hosts

# Test manual SSH
ssh azureuser@<VM_IP>
```

---

## 📝 Files Created

After running `azure-setup-budget.sh`:

1. **`ansible/inventory.ini`** - Ansible inventory with VM IPs
2. **`~/.ssh/known_hosts`** - SSH keys added

---

## 🎯 Next Steps

1. ✅ VMs deployed
2. ✅ Ansible connection tested
3. ⏭️ Write Ansible roles (see PROJECT_STATUS.md)
4. ⏭️ Deploy with `ansible-playbook`
5. ⏭️ Access Jenkins at `http://<IP>:8080`

---

## 💡 Tips

- **Stop VMs when not using** to save money
- **Keep VMs for development** - don't delete until project is done
- **IPs are static** - they won't change when you stop/start VMs
- **Backup inventory.ini** - it contains your VM IPs

---

## 🚀 Quick Reference

```bash
# Deploy infrastructure
./scripts/azure-setup-budget.sh

# Test connection
ansible all -i ansible/inventory.ini -m ping

# Deploy Whanos
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml

# Stop VMs (save money)
./scripts/azure-cleanup.sh  # option 1

# Start VMs
./scripts/azure-cleanup.sh  # option 2

# Delete everything
./scripts/azure-cleanup.sh  # option 5
```

---

## 📞 Support

- Azure quota issues: https://portal.azure.com → Quotas
- Azure student credits: https://azure.microsoft.com/free/students/
- Azure CLI docs: https://docs.microsoft.com/cli/azure/

---

**Status:** Infrastructure deployed ✅  
**Next:** Write Ansible roles for deployment automation
