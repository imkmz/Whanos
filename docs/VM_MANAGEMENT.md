# VM Management Guide

## Azure VM Information
- **VM Name**: `whanos-all` (or your VM name)
- **Resource Group**: `WHANOS` (or your resource group)
- **Location**: France Central (or your location)
- **Public IP**: `<YOUR_VM_PUBLIC_IP>` (use `az vm show` to get it)
- **SSH User**: `azureuser` (or your SSH user)

## Stop/Start VM

### Stop the VM (deallocate to save costs)
```bash
az vm deallocate --resource-group WHANOS --name whanos-all
```

**What happens:**
- VM stops running (no compute charges)
- All data is preserved on disk
- Public IP is released (may change on restart)
- Takes 2-3 minutes to complete

### Start the VM
```bash
az vm start --resource-group WHANOS --name whanos-all
```

**Wait time:** ~2-3 minutes for full boot

### Check VM Status
```bash
az vm get-instance-view --resource-group WHANOS --name whanos-all --query instanceView.statuses[1] --output table
```

## After VM Restart

### 1. Wait for Boot (2-3 minutes)
The VM needs time to:
- Start the OS
- Start system services (Docker, K3s)
- Initialize networking

### 2. Verify Services
```bash
# Connect via SSH
ssh azureuser@<YOUR_VM_PUBLIC_IP>

# Check Docker is running
docker ps

# Expected output: Jenkins and Registry containers
```

### 3. Start Services (if needed)
Services should auto-start with `restart: always`, but if not:

```bash
cd ~
docker-compose up -d
```

### 4. Verify Everything is Running
```bash
# Check all containers
docker ps

# Expected containers:
# - whanos-jenkins (ports 8080, 50000)
# - registry (port 5000)

# Check K3s (Kubernetes)
sudo systemctl status k3s

# Access Jenkins
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080
# Should return: 200 or 403 (means Jenkins is ready)
```

## What Persists After VM Restart

### ✅ Preserved
- **Jenkins Configuration**: All jobs, build history, plugins
- **Docker Registry**: All pushed images
- **Docker Volumes**: `jenkins_home`, `registry_data`
- **System Configuration**:
  - `/etc/docker/daemon.json` (insecure-registries)
  - `/etc/rancher/k3s/registries.yaml` (K3s registry config)
  - K3s cluster state
- **Kubernetes Deployments**: All running applications

### ❌ Lost
- **Running Containers**: Need to restart (but auto-restart with `restart: always`)
- **Docker Local Images**: Cache cleared, but images are in registry
- **RAM State**: Obviously, it's a reboot

## Access Points

### Jenkins
- **URL**: http://<YOUR_VM_PUBLIC_IP>:8080
- **Username**: `admin`
- **Password**: `admin` (⚠️ **CHANGE IN PRODUCTION!**)

### Docker Registry
- **URL**: http://<YOUR_VM_PUBLIC_IP>:5000
- **Catalog**: `curl http://<YOUR_VM_PUBLIC_IP>:5000/v2/_catalog`

### Kubernetes
```bash
# From VM
ssh azureuser@<YOUR_VM_PUBLIC_IP>
docker exec -u jenkins whanos-jenkins kubectl get all
```

## Troubleshooting After Restart

### Jenkins not accessible
```bash
# Check if container is running
docker ps | grep jenkins

# If not running, start it
cd ~
docker-compose up -d

# Check logs
docker logs whanos-jenkins --tail 50
```

### Registry not working
```bash
# Check container
docker ps | grep registry

# If not running
docker start registry

# Test registry
curl http://localhost:5000/v2/_catalog
```

### Kubernetes pods not starting
```bash
# Check K3s is running
sudo systemctl status k3s

# If not, restart
sudo systemctl restart k3s

# Wait 30s, then check
docker exec -u jenkins whanos-jenkins kubectl get nodes
```

### Images not pulling from registry
```bash
# Verify registry config
cat /etc/rancher/k3s/registries.yaml

# Should contain:
# mirrors:
#   "<YOUR_VM_PUBLIC_IP>:5000":
#     endpoint:
#       - "http://<YOUR_VM_PUBLIC_IP>:5000"

# If missing, recreate and restart K3s
echo 'mirrors:
  "<YOUR_VM_PUBLIC_IP>:5000":
    endpoint:
      - "http://<YOUR_VM_PUBLIC_IP>:5000"' | sudo tee /etc/rancher/k3s/registries.yaml

sudo systemctl restart k3s
```

## Quick Start Checklist After VM Restart

- [ ] Wait 2-3 minutes for VM to fully boot
- [ ] SSH into VM: `ssh azureuser@<YOUR_VM_PUBLIC_IP>`
- [ ] Verify Docker running: `docker ps`
- [ ] Check Jenkins accessible: http://<YOUR_VM_PUBLIC_IP>:8080
- [ ] Check Registry: `curl http://localhost:5000/v2/_catalog`
- [ ] Verify K3s: `sudo systemctl status k3s`
- [ ] Test a build: Create a project with `link-project` job

## Cost Optimization

**Important:** Always deallocate the VM when not in use to avoid charges!

```bash
# Stop VM when done working
az vm deallocate --resource-group WHANOS --name whanos-all

# Start VM when you need it
az vm start --resource-group WHANOS --name whanos-all
```

**Note:** Public IP may change after deallocate. Check new IP with:
```bash
az vm show --resource-group WHANOS --name whanos-all -d --query publicIps -o tsv
```
