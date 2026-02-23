# Build and Test Guide

## Prerequisites

- Docker installed and running
- Docker Compose installed
- Git installed
- 8GB+ RAM recommended
- 20GB+ disk space

## Building All Base Images

### Option 1: Build Script (Recommended)

```bash
./build-all-images.sh
```

This script builds all 5 base images sequentially.

### Option 2: Manual Build

```bash
# Befunge
cd images/befunge
docker build -t whanos-befunge -f Dockerfile.base .

# C
cd ../c
docker build -t whanos-c -f Dockerfile.base .

# Java
cd ../java
docker build -t whanos-java -f Dockerfile.base .

# JavaScript
cd ../javascript
docker build -t whanos-javascript -f Dockerfile.base .

# Python
cd ../python
docker build -t whanos-python -f Dockerfile.base .
```

### Verify Images

```bash
docker images | grep whanos
```

Expected output:
```
whanos-befunge        latest    xxxxx   X minutes ago   203MB
whanos-c              latest    xxxxx   X minutes ago   1.91GB
whanos-java           latest    xxxxx   X minutes ago   828MB
whanos-javascript     latest    xxxxx   X minutes ago   199MB
whanos-python         latest    xxxxx   X minutes ago   1.63GB
```

## Testing Individual Languages

### Python Test

```bash
cd app/test-python-app
docker build -t test-python-app -f ../../images/python/Dockerfile.standalone .
docker run --rm test-python-app
```

Expected output:
```
[INFO] Hello from Whanos Python app!
[OK] Python module execution successful
```

### JavaScript Test

```bash
cd app/test-javascript-app
docker build -t test-javascript-app -f ../../images/javascript/Dockerfile.standalone .
docker run --rm -p 3000:3000 test-javascript-app
```

Test in browser: http://localhost:3000

### Java Test

```bash
cd app/test-java-app
docker build -t test-java-app -f ../../images/java/Dockerfile.standalone .
docker run --rm test-java-app
```

### C Test

```bash
cd app/test-c-app
docker build -t test-c-app -f ../../images/c/Dockerfile.standalone .
docker run --rm test-c-app
```

Expected output:
```
All C tests passed!
```

### Befunge Test

```bash
cd app/test-befunge-app
docker build -t test-befunge-app -f ../../images/befunge/Dockerfile.standalone .
docker run --rm test-befunge-app
```

Expected output:
```
Befunge test pased!
```

## Jenkins Setup

### Build Jenkins Image

```bash
docker build -t whanos-jenkins -f jenkins/Dockerfile .
```

**Important:** Build from project root, not jenkins/ directory!

### Start Jenkins

```bash
docker compose up -d jenkins
```

Wait 30-60 seconds for Jenkins to start.

### Verify Jenkins

```bash
docker compose ps
docker logs whanos-jenkins
```

Look for: `Jenkins is fully up and running`

### Access Jenkins

Open browser: http://localhost:8080

Login:
- Username: `admin`
- Password: `admin`

### Fix Docker Permissions (if needed)

If you see Docker permission errors:

```bash
docker exec -u root whanos-jenkins chmod 666 /var/run/docker.sock
```

## Testing Jenkins Jobs

### 1. Test "Build all base images"

1. Navigate to `Whanos base images` folder
2. Click on `Build all base images`
3. Click "Build Now"
4. Check Console Output

Expected: Should trigger all 5 language image builds

### 2. Test Individual Image Build

1. Navigate to `Whanos base images` folder
2. Click on any language job (e.g., `whanos-python`)
3. Click "Build Now"
4. Check Console Output

Expected: Should build that specific image

### 3. Verify Built Images in Jenkins

```bash
docker exec jenkins docker images | grep whanos
```

### 4. Test link-project

#### Prepare Test Repository

Option A - Local test:
```bash
cd app/test-javascript-app
git init
git add .
git commit -m "Test"
```

Option B - GitHub (recommended):
Create a public repository with one of the test apps

#### Create Project Job

1. Click on `link-project` at Jenkins root
2. Click "Build with Parameters"
3. Enter:
   - **DISPLAY_NAME**: `my-test-app`
   - **GIT_URL**: Your repository URL
4. Click "Build"

Expected: New job created in `Projects/` folder

### 5. Test Project Job

1. Navigate to `Projects/my-test-app`
2. Click "Build Now"
3. Check Console Output

Expected output should include:
- Git clone
- Language detection
- Docker image build
- Build success

### 6. Test SCM Polling

1. Go to your project job
2. Click "Git Polling Log" (left sidebar)
3. Should show checks every minute

Make a commit to your repository and wait up to 1 minute - the job should trigger automatically.

## Troubleshooting

### Jenkins won't start

```bash
# Check logs
docker logs whanos-jenkins

# Restart
docker compose restart jenkins

# Full reset
docker compose down
docker volume rm $(docker volume ls -q | grep jenkins)
docker compose up -d jenkins
```

### Docker permission denied

```bash
docker exec -u root whanos-jenkins chmod 666 /var/run/docker.sock
```

This is temporary. For permanent fix, it's handled in docker-compose.yml.

### Base images not found

Rebuild them:
```bash
./build-all-images.sh
```

Or use Jenkins "Build all base images" job.

### Job DSL script error

Check:
1. Jobs.groovy syntax
2. Jenkins logs: `docker logs whanos-jenkins`
3. Script approval: Manage Jenkins → In-process Script Approval

### kubectl not found (Kubernetes deployment)

Verify kubectl is installed in Jenkins:
```bash
docker exec whanos-jenkins kubectl version --client
```

Should show: `Client Version: v1.34.1`

### Port already in use

If port 8080 is busy:

Edit `docker-compose.yml`:
```yaml
ports:
  - "8081:8080"  # Change 8080 to 8081 or any free port
```

Then access Jenkins at http://localhost:8081

## Cleanup

### Stop Jenkins

```bash
docker compose down
```

### Remove all Whanos images

```bash
docker rmi $(docker images | grep whanos | awk '{print $3}')
```

### Remove test images

```bash
docker rmi $(docker images | grep test- | awk '{print $3}')
```

### Full cleanup

```bash
docker compose down -v
docker system prune -a
```

## Deploying the infrastructure with Ansible

Use the provided Ansible playbook to deploy the minimal Whanos stack (registry, Jenkins, k3s cluster):

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-become-pass
```

After the playbook completes the cluster kubeconfig is available on the control plane at:

```
/opt/whanos/kubeconfig
```

You can copy that file into your local ~/.kube/config or use it inside the Jenkins container
at `/var/jenkins_home/kubeconfig` (the playbook attempts to copy it there when possible).

## Performance Tips

### Build times (approximate)

- Befunge: ~30 seconds
- JavaScript: ~1 minute
- Python: ~2 minutes
- Java: ~3 minutes
- C: ~4 minutes

Total for all images: ~10 minutes

### Disk space usage

- Base images: ~5GB
- Jenkins image: ~1.3GB
- Jenkins data: ~500MB
- Test apps: ~200MB

Total: ~7GB

### Memory usage

- Jenkins idle: ~500MB
- Jenkins building: ~1-2GB
- Each build job: ~100-500MB
