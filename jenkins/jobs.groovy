folder('Whanos base images') {
    displayName('Whanos base images')
    description('Whanos base images')
}

freeStyleJob('Whanos base images/Build all base images') {
    description('Build all Whanos base images')
    steps {
        downstreamParameterized {
            trigger('Whanos base images/whanos-c, Whanos base images/whanos-java, Whanos base images/whanos-javascript, Whanos base images/whanos-python, Whanos base images/whanos-befunge') {
                block {
                    buildStepFailure('FAILURE')
                    failure('FAILURE')
                    unstable('UNSTABLE')
                }
            }
        }
    }
}

freeStyleJob('Whanos base images/whanos-c') {
    description('Build whanos-c base image')
    steps {
        shell('''#!/bin/bash
echo "[BUILD] Building whanos-c"
cd /whanos/images/c
docker build -t whanos-c -f Dockerfile.base .
''')
    }
}

freeStyleJob('Whanos base images/whanos-java') {
    description('Build whanos-java base image')
    steps {
        shell('''#!/bin/bash
echo "[BUILD] Building whanos-java"
cd /whanos/images/java
docker build -t whanos-java -f Dockerfile.base .
''')
    }
}

freeStyleJob('Whanos base images/whanos-javascript') {
    description('Build whanos-javascript base image')
    steps {
        shell('''#!/bin/bash
echo "[BUILD] Building whanos-javascript"
cd /whanos/images/javascript
docker build -t whanos-javascript -f Dockerfile.base .
''')
    }
}

freeStyleJob('Whanos base images/whanos-python') {
    description('Build whanos-python base image')
    steps {
        shell('''#!/bin/bash
echo "[BUILD] Building whanos-python"
cd /whanos/images/python
docker build -t whanos-python -f Dockerfile.base .
''')
    }
}

freeStyleJob('Whanos base images/whanos-befunge') {
    description('Build whanos-befunge base image')
    steps {
        shell('''#!/bin/bash
echo "[BUILD] Building whanos-befunge"
cd /whanos/images/befunge
docker build -t whanos-befunge -f Dockerfile.base .
''')
    }
}

folder('Projects') {
    displayName('Projects')
    description('Projects')
}

freeStyleJob('link-project') {
    description('Link a project repository to Whanos')
    parameters {
        stringParam('REPOSITORY_URL', '', 'Git repository URL')
        stringParam('PROJECT_NAME', '', 'Project name')
        stringParam('BRANCH', 'main', 'Branch to monitor')
        stringParam('REGISTRY_URL', 'localhost:5000', 'Docker registry URL (e.g. localhost:5000)')
    }
    steps {
        dsl {
            text('''
folder('Projects')

freeStyleJob("Projects/${PROJECT_NAME}") {
    description("Whanos project: ${PROJECT_NAME}")
    
    scm {
        git {
            remote {
                url("${REPOSITORY_URL}")
            }
            branch("*/${BRANCH}")
        }
    }
    
    triggers {
        scm('* * * * *')
    }
    
    steps {
        shell("""#!/bin/bash
set -e

echo "[INFO] Starting build for ${PROJECT_NAME}"
echo "[DETECT] Detecting language"

LANGUAGE="unknown"
if [ -f "requirements.txt" ] && [ -d "app" ]; then
    LANGUAGE="python"
elif [ -f "package.json" ] && [ -d "app" ]; then
    LANGUAGE="javascript"
elif [ -f "pom.xml" ]; then
    LANGUAGE="java"
elif [ -f "Makefile" ] && [ -d "app" ]; then
    LANGUAGE="c"
elif [ -f "app/main.bf" ]; then
    LANGUAGE="befunge"
fi

echo "[LANGUAGE] Detected: \\$LANGUAGE"

if [ "\\$LANGUAGE" = "unknown" ]; then
    echo "[ERROR] Repository is not Whanos-compatible"
    exit 1
fi

IMAGE_NAME="${PROJECT_NAME}:\\$BUILD_NUMBER"

echo "[BUILD] Building Docker image..."
if [ -f "Dockerfile" ]; then
    echo "[BUILD] Using custom Dockerfile"
    docker build -t \\$IMAGE_NAME .
else
    echo "[BUILD] Using Whanos standalone image for \\$LANGUAGE"
    docker build -f /whanos/images/\\$LANGUAGE/Dockerfile.standalone -t \\$IMAGE_NAME .
fi

echo "[SUCCESS] Image built: \\$IMAGE_NAME"

# Push to registry
REGISTRY_HOST="${REGISTRY_URL}"
REGISTRY_IMAGE="\\$REGISTRY_HOST/${PROJECT_NAME}:\\$BUILD_NUMBER"

echo "[PUSH] Tagging image for registry: \\$REGISTRY_IMAGE"
docker tag \\$IMAGE_NAME \\$REGISTRY_IMAGE

echo "[PUSH] Pushing to registry..."
if docker push \\$REGISTRY_IMAGE; then
    echo "[SUCCESS] Image pushed: \\$REGISTRY_IMAGE"
    docker tag \\$IMAGE_NAME \\$REGISTRY_HOST/${PROJECT_NAME}:latest
    docker push \\$REGISTRY_HOST/${PROJECT_NAME}:latest
    echo "[SUCCESS] Latest tag pushed"
else
    echo "[ERROR] Failed to push to registry"
    exit 1
fi

# Check for Kubernetes deployment
if [ -f "whanos.yml" ]; then
    echo "[K8S] Found whanos.yml, checking for deployment configuration..."
    
    # Parse whanos.yml for deployment section
    if grep -q "deployment:" whanos.yml; then
        echo "[K8S] Deployment configuration found, deploying to Kubernetes..."
        
        # Extract values from whanos.yml (with defaults)
        REPLICAS=\\$(grep -A 10 "deployment:" whanos.yml | grep "replicas:" | awk '{print \\$2}' | head -1)
        REPLICAS=\\${REPLICAS:-1}
        
        # Extract ports (can be multiple)
        PORTS=\\$(grep -A 10 "deployment:" whanos.yml | grep "ports:" -A 20 | grep "^[[:space:]]*-" | awk '{print \\$2}' | tr '\\n' ',' | sed 's/,\\$//')
        PORT=\\${PORTS%%,*}  # First port as main port
        PORT=\\${PORT:-8080}
        
        # Export variables for envsubst
        export APP_NAME="${PROJECT_NAME}"
        export IMAGE_NAME="\\$REGISTRY_IMAGE"
        export REPLICAS=\\$REPLICAS
        export PORT=\\$PORT
        export SERVICE_TYPE="LoadBalancer"
        
        echo "[K8S] Deployment config:"
        echo "[K8S]   App: \\$APP_NAME"
        echo "[K8S]   Image: \\$IMAGE_NAME"
        echo "[K8S]   Replicas: \\$REPLICAS"
        echo "[K8S]   Port: \\$PORT"
        
        # Apply deployment
        envsubst < /whanos/kubernetes/deployment-template.yaml | kubectl apply -f -
        
        # Apply service if ports are defined
        if [ -n "\\$PORTS" ]; then
            echo "[K8S] Creating service with ports: \\$PORTS"
            envsubst < /whanos/kubernetes/service-template.yaml | kubectl apply -f -
            echo "[K8S] Service created, application accessible from outside"
        fi
        
        echo "[SUCCESS] Deployed to Kubernetes!"
        
        # Show deployment status
        kubectl get deployment \\$APP_NAME
        kubectl get pods -l app=\\$APP_NAME
        kubectl get service \\$APP_NAME 2>/dev/null || true
    else
        echo "[K8S] No deployment section in whanos.yml, skipping Kubernetes deployment"
    fi
else
    echo "[INFO] No whanos.yml found, skipping Kubernetes deployment"
fi

echo "[SUCCESS] Build and deployment completed!"
""")
    }
}
            '''.stripIndent())
            removeAction('DELETE')
        }
    }
}
