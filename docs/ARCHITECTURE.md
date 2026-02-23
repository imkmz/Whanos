# Whanos Architecture

## Overview

Whanos is a CI/CD platform that automatically containerizes and deploys applications across multiple programming languages.

## Components

### 1. Docker Images (`images/`)

Base and standalone images for each supported language:

- **befunge/** - Befunge-93 interpreter (Python-based)
- **c/** - GCC compiler environment
- **java/** - Maven + OpenJDK
- **javascript/** - Node.js + npm
- **python/** - Python 3.12 + pip

Each language has two Dockerfiles:
- `Dockerfile.base` - Contains language runtime and build tools
- `Dockerfile.standalone` - Extends base image to build and run applications

### 2. Jenkins (`jenkins/`)

Jenkins configuration using Configuration as Code (CasC):

- `Dockerfile` - Jenkins image with Docker-in-Docker and kubectl
- `jenkins.yaml` - Jenkins configuration (users, security, jobs)
- `jobs.groovy` - Job DSL script defining all CI/CD jobs
- `docker-compose.yml` - Standalone Jenkins deployment

**Installed Plugins:**
- configuration-as-code
- job-dsl
- git
- docker-workflow
- workflow-aggregator
- matrix-auth
- parameterized-trigger

### 3. Kubernetes (`kubernetes/`)

Templates for Kubernetes deployments:

- `deployment-template.yaml` - Deployment configuration with environment variable substitution
- `service-template.yaml` - Service configuration for external access

### 4. Ansible (`ansible/`)

Infrastructure deployment automation:

- `playbook.yml` - Main playbook
- `inventory.ini` - Infrastructure inventory
- `roles/` - Ansible roles for Docker, Jenkins, Kubernetes

### 5. Test Applications (`app/`)

Sample applications for testing:

- `test-befunge-app/` - Befunge test
- `test-c-app/` - C compilation test
- `test-java-app/` - Maven Java project
- `test-javascript-app/` - Express.js application
- `test-python-app/` - Python module execution

## Jenkins Jobs Structure

```
Jenkins Root
├── Whanos base images/          [Folder]
│   ├── Build all base images    [Job] - Triggers all image builds
│   ├── whanos-befunge           [Job] - Build Befunge base image
│   ├── whanos-c                 [Job] - Build C base image
│   ├── whanos-java              [Job] - Build Java base image
│   ├── whanos-javascript        [Job] - Build JavaScript base image
│   └── whanos-python            [Job] - Build Python base image
├── Projects/                     [Folder] - Contains dynamically created jobs
└── link-project                  [Job] - Creates new project jobs
```

## Workflow

### 1. Base Image Build

```
User triggers "Build all base images"
  ↓
Triggers 5 parallel jobs (befunge, c, java, javascript, python)
  ↓
Each job builds its base image using Dockerfile.base
  ↓
Images available: whanos-{language}:latest
```

### 2. Project Linking

```
User executes "link-project" with parameters:
  - DISPLAY_NAME: project name
  - GIT_URL: repository URL
  ↓
Job DSL creates new job in "Projects/" folder
  ↓
New job configured with:
  - Git repository polling (every minute)
  - Language detection
  - Docker build
  - Optional Kubernetes deployment
```

### 3. Application Build & Deploy

```
Project job triggered (manual or SCM change)
  ↓
Clone Git repository
  ↓
Detect language (check for requirements.txt, package.json, pom.xml, Makefile, .bf)
  ↓
Build Docker image:
  - If Dockerfile exists: use it
  - Else: use whanos-{language} Dockerfile.standalone
  ↓
Tag image: {project-name}:{build-number}
  ↓
Check for whanos.yml
  ↓
If whanos.yml exists with deployment config:
  - Parse replicas, ports, resources
  - Apply deployment-template.yaml
  - Apply service-template.yaml
  - Deploy to Kubernetes
```

## Language Detection Logic

```groovy
if (package.json exists) → JavaScript
else if (pom.xml exists) → Java
else if (Makefile exists) → C
else if (requirements.txt exists) → Python
else if (*.bf exists) → Befunge
```

## whanos.yml Configuration

Optional file in project root for Kubernetes deployment:

```yaml
deployment:
  replicas: 2
  resources:
    limits:
      memory: "512Mi"
      cpu: "1000m"
    requests:
      memory: "256Mi"
      cpu: "500m"
  ports:
    - 8080
    - 8443
```

## Security

- Jenkins authentication: local user database
- Admin user: `admin` / `admin123` (configurable via JENKINS_ADMIN_PASSWORD)
- No anonymous access
- Script approval for Job DSL (configured in jenkins.yaml)
- Docker socket mounted with permissions management

## Network Architecture

```
User Browser
  ↓ HTTP :8080
Jenkins Container
  ↓ Docker Socket
Docker Daemon
  ↓ Builds
Application Containers
  ↓ kubectl
Kubernetes Cluster
```

## Data Persistence

- Jenkins home: Docker volume `jenkins_home`
- Docker images: Host Docker daemon
- Kubernetes state: External cluster

## Environment Variables

### Jenkins
- `JENKINS_ADMIN_PASSWORD` - Admin password (default: admin123)
- `JENKINS_URL` - Jenkins URL (default: http://localhost:8080/)
- `WHANOS_HOME` - Whanos files location in container (/whanos)

### Application Deployment
- `APP_NAME` - Application name
- `IMAGE_NAME` - Docker image name
- `REPLICAS` - Number of replicas
- `PORT` - Application port
- `SERVICE_TYPE` - Kubernetes service type (default: LoadBalancer)
