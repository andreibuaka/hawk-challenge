# Hawk Hello World CI/CD Challenge

This project demonstrates a complete CI/CD pipeline for a simple Java application that prints "Hello World" every two seconds, with a focus on GitOps, blue-green deployments, and security best practices.

## Project Structure

- `src/main/java/com/example/HelloWorld.java`: The main application with SLF4J logging
- `src/test/java/com/example/HelloWorldTest.java`: Unit tests with JUnit 5
- `Dockerfile`: Multi-stage build for creating a secure, optimized container
- `helm/`: Helm chart for Kubernetes deployment with blue-green strategy
- `.github/workflows/`: GitHub Actions workflows for CI/CD and security scanning
- `argocd/`: ArgoCD configuration for GitOps deployment
- `ephemeral-check.sh`: Script for testing the ephemeral environment

## CI/CD Pipeline Features

The pipeline implements modern DevOps practices:

1. **Build & Test**: Java application built with Gradle
   - JUnit 5 tests with minimum 40% code coverage via JaCoCo
   - Static code analysis with Checkstyle

2. **Container Security**:
   - Multi-stage Docker build with minimal final image
   - Non-root user execution (`appuser`)
   - Trivy vulnerability scanning with fail-on-critical policy
   - Weekly scheduled security scans for newly discovered CVEs

3. **Deployment Strategy**:
   - Blue-Green deployment via Helm chart
   - Ephemeral testing environment using kind (Kubernetes in Docker)
   - Automated smoke tests on ephemeral environment
   - GitOps workflow with ArgoCD

4. **Observability**:
   - Structured logging with SLF4J and Logback
   - Kubernetes liveness and readiness probes

## Blue-Green Deployment

The Helm chart implements blue-green deployments by:

1. Maintaining two identical deployments (blue and green)
2. The CI/CD pipeline automatically toggles between colors for each deployment
3. Only the active color receives traffic via the Kubernetes Service selector
4. Zero-downtime deployments with gradual traffic shifting

## Setting Up the Pipeline

### GitHub Actions Configuration

Set up these repository secrets:

- `DOCKER_USERNAME`: Your Docker Hub username
- `DOCKER_PASSWORD`: Your Docker Hub password or access token
- `GIT_PUSH_TOKEN`: GitHub Personal Access Token with `contents: write` permission

### Local Development & Testing

#### Quick Start

```bash
# Build and run locally
./gradlew build
java -jar build/libs/hello-world-1.0-SNAPSHOT.jar

# Build and run Docker container
docker build -t hawk-hello-world:local .
docker run --rm hawk-hello-world:local
```

#### Complete Local GitOps Flow

```bash
# Create local Kubernetes cluster
kind create cluster --name hawk-challenge

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access ArgoCD UI (in a separate terminal)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get ArgoCD admin password
ARGO_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Password: $ARGO_PASSWORD"

# Configure ArgoCD application
# First edit argocd/application.yaml to set your repository URL
kubectl apply -f argocd/application.yaml

# Verify deployment
kubectl get deployments,pods -n default
kubectl logs -f $(kubectl get pods -n default -l app.kubernetes.io/instance=hello-world-app-hello-world -o jsonpath='{.items[0].metadata.name}')
```

## Verification & Troubleshooting

### Common Issues

- **ArgoCD not syncing**: Ensure repository is public or credentials are configured
- **Port-forward issues**: Check for existing processes using port 8080
- **Pipeline failures**: Verify all required secrets are configured

### Verification Commands

```bash
# Check deployment status
kubectl get deployments -n default -o wide

# Verify pod logs
POD_NAME=$(kubectl get pods -n default -l app.kubernetes.io/instance=hello-world-app-hello-world -o jsonpath='{.items[0].metadata.name}')
kubectl logs $POD_NAME -n default

# Test blue-green switch by triggering a new deployment
# Make a small change to the repo, commit and push to main
```

## Prerequisites

- Java 17+
- Docker
- Kubernetes tools: kubectl, helm, kind
- yq v4+ (for local testing of Helm updates)

