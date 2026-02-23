# Whanos Jenkins Instance with Job DSL
# Based on official Jenkins LTS image
FROM jenkins/jenkins:lts

# Use bash for all build instructions
SHELL ["/bin/bash", "-c"]

# Switch to root to install Docker
USER root

# Install Docker CLI and kubectl
RUN apt-get update && \
    apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    gettext-base && \
    ARCH=$(dpkg --print-architecture) && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl && \
    rm -rf /var/lib/apt/lists/*

# Create docker group with GID 123 (matches host) and add jenkins user to it
RUN groupadd -f -g 123 docker && usermod -aG docker jenkins

# Switch back to jenkins user
USER jenkins

# Install Jenkins plugins
RUN jenkins-plugin-cli --plugins \
    configuration-as-code:latest \
    job-dsl:latest \
    git:latest \
    docker-workflow:latest \
    workflow-aggregator:latest \
    matrix-auth:latest \
    parameterized-trigger:latest

# Copy Jenkins Configuration as Code
COPY jenkins/jenkins.yaml /var/jenkins_home/jenkins.yaml
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/jenkins.yaml

# Copy Job DSL script
COPY jenkins/jobs.groovy /var/jenkins_home/jobs.groovy

# Create Whanos directory and copy language images and Kubernetes templates
USER root
RUN mkdir -p /whanos/images /whanos/kubernetes
COPY images /whanos/images/
COPY kubernetes /whanos/kubernetes/
RUN chown -R jenkins:jenkins /whanos
USER jenkins

# Expose Jenkins port
EXPOSE 8080

# Skip initial setup wizard
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
