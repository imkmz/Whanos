# Jenkins Setup Documentation

## Overview
Jenkins is configured using Configuration as Code (JCasC) with the Job DSL plugin for dynamic job creation.

## Architecture

### Configuration Files
- **`jenkins/jenkins.yaml`**: Main Jenkins configuration (users, security, tool locations, job loading)
- **`jenkins/jobs.groovy`**: Job DSL definitions for all Jenkins jobs
- **`jenkins/Dockerfile`**: Custom Jenkins image with Docker, kubectl, and required plugins
- **`jenkins/docker-compose.yml`**: Docker Compose setup for Jenkins deployment

### Key Features
1. **Configuration as Code**: No manual Jenkins UI configuration needed
2. **Dynamic Job Creation**: `link-project` job creates project jobs on-demand
3. **Docker-in-Docker**: Jenkins can build Docker images
4. **Kubernetes Integration**: kubectl installed for K8s deployments

## Jobs Structure

### 1. Whanos Base Images
Folder containing jobs to build language-specific base images:
- `whanos-c`, `whanos-java`, `whanos-javascript`, `whanos-python`, `whanos-befunge`
- Each job builds a base image from `images/<language>/Dockerfile.base`

### 2. link-project Job
**Purpose**: Dynamically create new project jobs

**Parameters**:
- `REPOSITORY_URL`: Git repository URL
- `PROJECT_NAME`: Name for the new job
- `BRANCH`: Git branch to monitor (default: main)
- `REGISTRY_URL`: Docker registry URL (currently unused)

**Workflow**:
1. User provides repository details via Jenkins UI
2. Job uses Job DSL to create a new freestyle job in `Projects/` folder
3. Created job includes:
   - Git SCM configuration
   - SCM polling trigger (every minute: `* * * * *`)
   - Build shell script with language detection and Docker build

### 3. Project Jobs (Dynamically Created)
Each project job automatically:

#### Language Detection
Detects project language based on files:
- **Python**: `requirements.txt` + `app/` directory
- **JavaScript**: `package.json` + `app/` directory
- **Java**: `pom.xml`
- **C**: `Makefile` + `app/` directory
- **Befunge**: `app/main.bf`

#### Docker Build
- If custom `Dockerfile` exists: uses it
- Otherwise: uses Whanos standalone image from `/whanos/images/<language>/Dockerfile.standalone`
- Tags image as: `<project-name>:<BUILD_NUMBER>`

#### Kubernetes Deployment (Optional)
If `whanos.yml` exists in repository root with `deployment:` section:
1. Parses configuration (replicas, ports)
2. Uses `envsubst` to populate K8s templates
3. Applies deployment and service to cluster
4. Shows deployment status

## DSL Syntax Gotchas

### Triple Escaping Problem
The Job DSL creates jobs that generate shell scripts, requiring careful variable escaping:

1. **Groovy DSL Level** (jobs.groovy):
   - Uses `'''` (triple single quotes) for literal strings
   - `${PROJECT_NAME}` → Interpolated by Groovy at DSL parse time

2. **Job DSL Level** (generated Jenkins job XML):
   - Uses `"""` (triple double quotes) for shell script
   - `\\$VARIABLE` → Becomes `\$VARIABLE` in XML

3. **Bash Level** (actual shell execution):
   - `\$VARIABLE` → Becomes `$VARIABLE` in bash
   - `$VARIABLE` → Evaluated by bash at runtime

### Working Pattern
```groovy
// Outer DSL (creates job)
text('''
freeStyleJob("Projects/${PROJECT_NAME}") {  // Groovy interpolation
    steps {
        shell("""#!/bin/bash               // Shell script starts
            IMAGE_NAME="${PROJECT_NAME}:\\$BUILD_NUMBER"  // Mixed: Groovy + Bash
            docker build -t \\$IMAGE_NAME .               // Pure Bash variable
        """)
    }
}
''')
```

**Key Rules**:
- `${VAR}` in `'''` → Interpolated by Groovy (use for job parameters)
- `\\$VAR` in `"""` → Becomes `$VAR` in bash (use for shell variables)
- `$BUILD_NUMBER` is Jenkins environment variable, needs `\\$` to reach bash

## Deployment

### Initial Setup
```bash
cd jenkins
docker-compose up -d
```

### Rebuild After Changes
```bash
docker-compose down
docker volume rm jenkins_jenkins_home  # Clears old config
docker-compose build --no-cache
docker-compose up -d
```

**Note**: Volume removal is necessary because:
- Jenkins persists job configs to disk at runtime
- Old XML configs override new DSL definitions
- Fresh volume ensures clean state with updated jobs.groovy

### Verify Deployment
```bash
# Wait ~50s for Jenkins to fully initialize
sleep 50

# Check logs
docker logs whanos-jenkins

# Access UI
open http://<JENKINS_IP>:8080
```

## Authentication
- **Username**: `admin`
- **Password**: `admin`

Configured in `jenkins.yaml` under `securityRealm` section.

## Troubleshooting

### Jobs Not Updating
**Symptom**: Changes to `jobs.groovy` don't appear in Jenkins UI

**Solution**: 
1. Old job configs persist on volume
2. Must remove volume and rebuild:
   ```bash
   docker-compose down
   docker volume rm jenkins_jenkins_home
   docker-compose build --no-cache
   docker-compose up -d
   ```

### DSL Syntax Errors
**Symptom**: `link-project` fails with "No such property" or "illegal string body character"

**Common Causes**:
- Wrong quote type (`"""` vs `'''`)
- Incorrect escape count (`\$` vs `\\$`)
- Missing variable interpolation (`${VAR}` not used)

**Debug Approach**:
1. Check error line number in Jenkins console output
2. Verify quote matching (each `'''` needs closing `'''`)
3. Count backslashes (Groovy → Job DSL → Bash = 3 levels)

### Build Failures
**Symptom**: Project job fails with "invalid tag" or "command not found"

**Check**:
- Language detection logic in jobs.groovy
- Whanos base images exist: `docker images | grep whanos`
- Repository structure matches expected (e.g., `app/` directory)

## Advanced Customization

### Adding New Languages
1. Create `images/<language>/Dockerfile.base` and `Dockerfile.standalone`
2. Add language detection logic to jobs.groovy:
   ```groovy
   elif [ -f "<language-marker-file>" ]; then
       LANGUAGE="<language>"
   ```
3. Add base image build job in `Whanos base images` folder

### Modifying Kubernetes Templates
Edit files in `kubernetes/`:
- `deployment-template.yaml`: Pod/container configuration
- `service-template.yaml`: Service exposure configuration

Variables available via `envsubst`:
- `$APP_NAME`: Project name
- `$IMAGE_NAME`: Built Docker image tag
- `$REPLICAS`: Number of replicas
- `$PORT`: Container port
- `$SERVICE_TYPE`: Kubernetes service type

## References
- [Jenkins Configuration as Code](https://plugins.jenkins.io/configuration-as-code/)
- [Job DSL Plugin](https://plugins.jenkins.io/job-dsl/)
- [Jenkins Docker Official Image](https://hub.docker.com/r/jenkins/jenkins)
