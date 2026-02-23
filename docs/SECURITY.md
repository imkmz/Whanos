# Security Policy

## 🔒 Security Overview

Whanos is an educational DevOps platform. This document outlines security considerations for production deployments.

## 🚨 Reporting Security Issues

If you discover a security vulnerability in this project, please report it by:

1. **Email**: Create an issue on GitHub with the label `security`
2. **Response Time**: We aim to respond within 48 hours
3. **Disclosure**: Please allow us time to fix the issue before public disclosure

## ⚠️ Default Credentials

### Jenkins
- **Default Username**: `admin`
- **Default Password**: `admin`

🚨 **CRITICAL**: These credentials are for **TESTING AND DEVELOPMENT ONLY**. 

### Production Security Checklist

Before deploying to production, you **MUST**:

- [ ] Change Jenkins admin password
- [ ] Enable HTTPS for Jenkins (use reverse proxy like Nginx)
- [ ] Enable authentication on Docker Registry
- [ ] Configure firewall rules (restrict ports 8080, 5000, 50000)
- [ ] Use secrets management (Azure Key Vault, HashiCorp Vault)
- [ ] Rotate credentials regularly
- [ ] Enable audit logging
- [ ] Use non-root Docker user where possible
- [ ] Scan Docker images for vulnerabilities
- [ ] Keep all components updated

## 🔐 Jenkins Security

### Change Admin Password

**Option 1: Via Jenkins UI**
1. Go to: Manage Jenkins → Manage Users → admin → Configure
2. Set a strong password
3. Save

**Option 2: Via Environment Variable**
```bash
# In docker-compose.yml or .env
JENKINS_ADMIN_PASSWORD=your-strong-password-here
```

**Option 3: Via Jenkins Configuration as Code**
Edit `jenkins/jenkins.yaml`:
```yaml
jenkins:
  securityRealm:
    local:
      users:
        - id: "admin"
          password: "${JENKINS_ADMIN_PASSWORD:-changeMe123!}"
```

### Enable HTTPS

Use a reverse proxy (Nginx/Traefik) with Let's Encrypt:

```nginx
server {
    listen 443 ssl;
    server_name jenkins.yourdomain.com;
    
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 🐳 Docker Registry Security

### Enable Authentication

**Option 1: Basic Auth with htpasswd**
```bash
# Create htpasswd file
docker run --rm --entrypoint htpasswd httpd:2 -Bbn username password > auth/htpasswd

# Update docker-compose.yml
services:
  registry:
    environment:
      REGISTRY_AUTH: htpasswd
      REGISTRY_AUTH_HTPASSWD_PATH: /auth/htpasswd
      REGISTRY_AUTH_HTPASSWD_REALM: Registry Realm
    volumes:
      - ./auth:/auth
```

**Option 2: Use a Managed Registry**
- Azure Container Registry (ACR)
- Docker Hub
- GitHub Container Registry (ghcr.io)

### Enable HTTPS for Registry

Docker Registry should **always** use HTTPS in production:

```bash
# Generate self-signed cert (testing only)
openssl req -newkey rsa:4096 -nodes -sha256 -keyout registry.key -x509 -days 365 -out registry.crt

# Update docker-compose.yml
services:
  registry:
    environment:
      REGISTRY_HTTP_TLS_CERTIFICATE: /certs/registry.crt
      REGISTRY_HTTP_TLS_KEY: /certs/registry.key
    volumes:
      - ./certs:/certs
```

## 🔥 Firewall Configuration

### Azure Network Security Group

```bash
# Allow SSH (restrict to your IP)
az network nsg rule create --resource-group WHANOS \
  --nsg-name whanos-nsg --name AllowSSH \
  --priority 100 --source-address-prefixes YOUR_IP/32 \
  --destination-port-ranges 22 --access Allow --protocol Tcp

# Allow Jenkins (restrict to your IP or VPN)
az network nsg rule create --resource-group WHANOS \
  --nsg-name whanos-nsg --name AllowJenkins \
  --priority 110 --source-address-prefixes YOUR_IP/32 \
  --destination-port-ranges 8080 --access Allow --protocol Tcp

# Deny all other inbound by default
az network nsg rule create --resource-group WHANOS \
  --nsg-name whanos-nsg --name DenyAllInbound \
  --priority 4096 --source-address-prefixes '*' \
  --destination-port-ranges '*' --access Deny --protocol '*'
```

### iptables (Linux)

```bash
# Allow SSH
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow Jenkins (from specific IP only)
sudo iptables -A INPUT -p tcp -s YOUR_IP --dport 8080 -j ACCEPT

# Allow Docker Registry (internal only)
sudo iptables -A INPUT -p tcp -s 10.0.0.0/8 --dport 5000 -j ACCEPT

# Default deny
sudo iptables -A INPUT -j DROP
```

## 🔑 Secrets Management

### Never Commit Secrets

Add to `.gitignore`:
```
.env
*.key
*.pem
*.crt
auth/htpasswd
kubeconfig
*.bak
*secret*
```

### Use Environment Variables

Instead of hardcoding:
```groovy
// ❌ BAD
REGISTRY_HOST="1.2.3.4:5000"

// ✅ GOOD
REGISTRY_HOST="${REGISTRY_URL}"
```

### Use Azure Key Vault

```bash
# Store secret
az keyvault secret set --vault-name whanos-vault \
  --name jenkins-admin-password --value "SecurePassword123!"

# Retrieve in script
JENKINS_PASSWORD=$(az keyvault secret show --vault-name whanos-vault \
  --name jenkins-admin-password --query value -o tsv)
```

## 🛡️ Kubernetes Security

### Use RBAC

Create service accounts with minimal permissions:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: whanos-deployer
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: whanos-deployer-role
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: whanos-deployer-binding
subjects:
- kind: ServiceAccount
  name: whanos-deployer
roleRef:
  kind: Role
  name: whanos-deployer-role
  apiGroup: rbac.authorization.k8s.io
```

### Use Network Policies

Restrict pod-to-pod communication:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

## 🔍 Monitoring & Auditing

### Enable Jenkins Audit Trail

1. Install "Audit Trail" plugin
2. Configure: Manage Jenkins → Configure System → Audit Trail
3. Log to: `/var/jenkins_home/logs/audit.log`

### Monitor Docker Registry

```bash
# Enable debug logging
REGISTRY_LOG_LEVEL=debug
```

### Kubernetes Audit Logs

Enable in K3s:
```bash
sudo k3s server --kube-apiserver-arg audit-log-path=/var/log/k8s-audit.log
```

## 📦 Docker Image Security

### Scan for Vulnerabilities

```bash
# Using Trivy
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image whanos-jenkins:latest

# Using Docker Scout
docker scout cves whanos-jenkins:latest
```

### Use Minimal Base Images

Prefer Alpine-based images:
```dockerfile
FROM python:3.11-alpine  # Instead of python:3.11
```

### Don't Run as Root

```dockerfile
RUN adduser -D appuser
USER appuser
```

## 🔄 Update Policy

- **Security patches**: Applied within 24 hours
- **Dependencies**: Review monthly
- **Base images**: Update quarterly

## 📚 Resources

- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Jenkins Security Best Practices](https://www.jenkins.io/doc/book/security/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/security-checklist/)
- [Azure Security Baseline](https://docs.microsoft.com/en-us/security/benchmark/azure/)

---

## ⚖️ Disclaimer

This project is for **educational purposes**. The default configuration is intentionally simplified for learning. **DO NOT** use default configurations in production environments without implementing proper security measures as outlined in this document.
