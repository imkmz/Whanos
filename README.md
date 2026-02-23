# Whanos - DevOps Infrastructure Platform

**Whanos** is an automated CI/CD platform that containerizes and deploys applications across multiple programming languages. It provides a complete DevOps infrastructure with Jenkins, Docker, and Kubernetes integration.

## 🎯 Project Overview

Whanos automatically:
- **Detects** your application's language (C, Java, JavaScript, Python, Befunge)
- **Builds** Docker images using base images or custom Dockerfiles
- **Deploys** to Kubernetes clusters with optional configuration
- **Monitors** repositories for changes and triggers automatic builds

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Documentation](#documentation)
- [Supported Languages](#supported-languages)
- [Repository Structure](#repository-structure)
- [Architecture](#architecture)
- [Troubleshooting](#troubleshooting)

---

## 🚀 Quick Start

### Prerequisites

- Docker Desktop installed and running
- Docker Compose installed
- 8GB+ RAM and 20GB+ disk space
- Port 8080 available

### 1. Build and Start Jenkins

```bash
# Build Jenkins image (from project root!)
docker build -t whanos-jenkins -f jenkins/Dockerfile .

# Start Jenkins
docker compose up -d jenkins

# Fix Docker permissions (required after each restart)
docker exec -u root whanos-jenkins chmod 666 /var/run/docker.sock
```

### 2. Access Jenkins

Open your browser: **http://localhost:8080**

**Login:**
- Username: `admin`
- Password: `admin`

⚠️ **SECURITY WARNING**: The default credentials (`admin`/`admin`) are for **TESTING ONLY**. Always change them in production environments!

### 3. Build Base Images

In Jenkins:
1. Navigate to `Whanos base images` folder
2. Click on `Build all base images`
3. Click "Build Now"
4. Wait 5-10 minutes for all images to build

### 4. Link a Project

1. Click on `link-project` (at root)
2. "Build with Parameters"
3. Enter:
   - **DISPLAY_NAME**: Your project name
   - **GIT_URL**: Your repository URL
4. Click "Build"

**Note:** If you see "script not yet approved" error, go to **Manage Jenkins** → **In-process Script Approval** → **Approve** the script.

---

## 📚 Documentation

Complete guides are available in the `docs/` folder:

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System architecture, components, and workflows
- **[BUILD_AND_TEST.md](docs/BUILD_AND_TEST.md)** - Detailed build and testing instructions
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Common problems and solutions
- **[JENKINS_SETUP.md](docs/JENKINS_SETUP.md)** - Jenkins Configuration as Code setup
- **[JOB_DSL_DEBUGGING.md](docs/JOB_DSL_DEBUGGING.md)** - Job DSL variable escaping guide

### Security & Contributing

- **[SECURITY.md](SECURITY.md)** - 🔒 Security best practices and production deployment guide
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - 🤝 How to contribute to the project
- **[LICENSE](LICENSE)** - 📄 MIT License and educational notice

---

## 🌐 Supported Languages

| Language | Build Tool | Detection File | Base Image Size |
|----------|-----------|----------------|-----------------|
| **Befunge** | Custom interpreter | `*.bf` | 203MB |
| **C** | GCC + Make | `Makefile` | 1.91GB |
| **Java** | Maven | `pom.xml` | 828MB |
| **JavaScript** | npm | `package.json` | 199MB |
| **Python** | pip | `requirements.txt` | 1.63GB |

---

## 📁 Repository Structure

---

## 📁 Repository Structure

### Your Application Repository

For compatibility with Whanos, structure your repository like this:

```
my-app/                        ← Repository root
├── package.json              ← Language-specific dependency file (at root!)
├── app/                      ← Application code (at root!)
│   ├── index.js
│   └── utils.js
├── whanos.yml               ← Optional: Kubernetes deployment config
└── Dockerfile               ← Optional: Custom Docker configuration
```

⚠️ **Common Mistake:** Don't put files in a subdirectory like `test-app/`. They must be at the repository root.

### Whanos Project Structure

```
whanos/
├── ansible/              # Infrastructure automation
├── app/                  # Test applications
├── docs/                 # Documentation
│   ├── ARCHITECTURE.md
│   ├── BUILD_AND_TEST.md
│   └── TROUBLESHOOTING.md
├── images/               # Language base images
│   ├── befunge/
│   ├── c/
│   ├── java/
│   ├── javascript/
│   └── python/
├── jenkins/              # Jenkins configuration
│   ├── Dockerfile
│   ├── jenkins.yaml
│   ├── jobs.groovy
│   └── docker-compose.yml
├── kubernetes/           # K8s templates
│   ├── deployment-template.yaml
│   └── service-template.yaml
└── README.md
```

---

## 🏗️ Architecture

### Jenkins Jobs

```
Jenkins
├── Whanos base images/           [Folder]
│   ├── Build all base images     Triggers all 5 image builds
│   ├── whanos-befunge           Build Befunge base image
│   ├── whanos-c                 Build C base image
│   ├── whanos-java              Build Java base image
│   ├── whanos-javascript        Build JavaScript base image
│   └── whanos-python            Build Python base image
├── Projects/                     [Folder]
│   └── [your-projects]          Dynamically created project jobs
└── link-project                  Create new project jobs
```

### Build Workflow

1. **Base Images** → Built once, reused for all projects
2. **link-project** → Creates a Jenkins job for your repository
3. **Project Job** → Detects language → Builds Docker image → Deploys to K8s
4. **Auto-trigger** → Polls repository every minute, rebuilds on changes

---

## 🔧 Configuration

### whanos.yml (Optional)

Add this file to your repository root for Kubernetes deployment:

```yaml
deployment:
  replicas: 2
  resources:
    limits:
      memory: "512Mi"
      cpu: "1000m"
  ports:
    - 8080
```

### Custom Dockerfile (Optional)

If you need custom build steps, add a `Dockerfile` at your repository root. Whanos will use it instead of the standalone image.

---

## 🛠️ Development Commands

### Build Individual Base Images

```bash
docker build -t whanos-python -f images/python/Dockerfile.base images/python
docker build -t whanos-javascript -f images/javascript/Dockerfile.base images/javascript
docker build -t whanos-java -f images/java/Dockerfile.base images/java
docker build -t whanos-c -f images/c/Dockerfile.base images/c
docker build -t whanos-befunge -f images/befunge/Dockerfile.base images/befunge
```

### Test Applications Manually

```bash
# Example: Python
cd app/test-python-app
docker build -t test-app -f ../../images/python/Dockerfile.standalone .
docker run --rm test-app

# Example: JavaScript
cd app/test-javascript-app
docker build -t test-app -f ../../images/javascript/Dockerfile.standalone .
docker run --rm -p 3000:3000 test-app
```

### Jenkins Management

```bash
# View logs
docker logs -f whanos-jenkins

# Restart
docker compose restart jenkins
docker exec -u root whanos-jenkins chmod 666 /var/run/docker.sock

# Stop
docker compose down

# Clean everything
docker compose down -v
docker system prune -a
```

## Deploying the Whanos infrastructure with Ansible

This repository includes an Ansible playbook and roles to provision the minimal Whanos
infrastructure (Docker registry, Jenkins and a small Kubernetes cluster using k3s).

Basic usage (from project root):

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-become-pass
```

What this does:
- Installs a Docker registry container on the host in the `docker_registry` group.
- Builds and runs the `whanos-jenkins` container on the host in the `jenkins_server` group.
- Installs k3s on hosts in the `kubernetes_cluster` group (control plane + workers) and
  exports the kubeconfig to `/opt/whanos/kubeconfig` on the control plane host.

Notes:
- The current registry is deployed without authentication and listens on port 5000 by default.
  The `link-project` job supports a `REGISTRY_URL` parameter (default: `localhost:5000`) to
  push images after building them.
- The playbook is intended to be idempotent for basic redeploys. If you customize hosts or
  networking, update `ansible/inventory.ini` accordingly.


---

## 🐛 Troubleshooting

### Quick Fixes

**Problem:** Permission denied connecting to Docker daemon
**Solution:** `docker exec -u root whanos-jenkins chmod 666 /var/run/docker.sock`

**Problem:** Script not yet approved
**Solution:** Manage Jenkins → In-process Script Approval → Approve

**Problem:** Build fails "Cannot find Dockerfile"
**Solution:** Make sure you're building from project root: `docker build -f jenkins/Dockerfile .`

**Problem:** Repository structure not recognized
**Solution:** Ensure `package.json` / `requirements.txt` / etc. are at repository **root**, not in a subdirectory

**Problem:** Jobs not updating after changing `jobs.groovy`
**Solution:** Old configs persist on volume. Full rebuild required:
```bash
cd jenkins
docker-compose down
docker volume rm jenkins_jenkins_home
docker-compose build --no-cache
docker-compose up -d
```

### Deep Dive Guides
- 👉 **General issues:** [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- 👉 **Job DSL errors:** [docs/JOB_DSL_DEBUGGING.md](docs/JOB_DSL_DEBUGGING.md)

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Educational Purpose**: This project was created for Epitech's DevOps program (G-DOP-500) and is intended for learning purposes.

⚠️ **Production Warning**: Default configurations are simplified for education. See [SECURITY.md](SECURITY.md) for production hardening guidelines.

---

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to contribute to this project.

---

## 🔒 Security

For security considerations and production deployment guidelines, please read [SECURITY.md](SECURITY.md).

**Default Credentials**: `admin`/`admin` - **CHANGE IN PRODUCTION!**

---

## 👥 Contributors

DevOps Team - G-DOP-500-STG-5-1
