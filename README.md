# Hawk Hello World CI/CD Challenge

This project demonstrates a complete CI/CD pipeline for a simple Java application that prints "Hello World" every two seconds.

## Project Structure

- `src/main/java/com/example/HelloWorld.java`: The main application
- `src/test/java/com/example/HelloWorldTest.java`: Unit tests
- `Dockerfile`: Multi-stage build for creating the application container
- `helm/`: Helm chart for Kubernetes deployment with blue-green strategy
- `.github/workflows/`: GitHub Actions workflows for CI/CD
- `ephemeral-check.sh`: Script for testing the ephemeral environment

## CI/CD Pipeline

The pipeline includes the following steps:

1. Build the Java application with Gradle
2. Run tests with JUnit and measure code coverage with JaCoCo (min 40%)
3. Perform static code analysis with Checkstyle
4. Build a Docker image (running as non-root `appuser`)
5. Scan the Docker image for vulnerabilities with Trivy
6. Push the Docker image to Docker Hub
7. Deploy to an ephemeral environment using kind (Kubernetes in Docker)
8. Run smoke tests on the ephemeral environment (checks logs)
9. Update the Helm chart (`values.yaml`) with the new image tag and switch deployment color using `yq`.
10. Push the updated `values.yaml` back to the Git repository (triggers ArgoCD in a real scenario).

## Blue-Green Deployment

The Helm chart is configured for blue-green deployments using a `color` value (`blue` or `green`) in `helm/values.yaml`. The pipeline automatically determines the *next* color, updates the `image.tag` and `deployment.color` in `values.yaml`, and pushes the change. The Kubernetes Service selector (`app.kubernetes.io/color`) ensures traffic only goes to the active color's deployment. The Deployment includes basic `exec` based liveness and readiness probes.

## Weekly Security Scans

A separate workflow runs weekly to scan the latest Docker image for newly discovered vulnerabilities.

## Local Development

To build and run the application locally:

```bash
./gradlew build
java -jar build/libs/hello-world-1.0-SNAPSHOT.jar
```

To build and run the Docker image locally:

```bash
docker build -t hello-world .
docker run hello-world
```

## GitHub Actions Setup

Before running the pipeline on GitHub Actions, you need to set up the following secrets in your repository (`Settings -> Secrets and variables -> Actions`):

- `DOCKER_USERNAME`: Your Docker Hub username.
- `DOCKER_PASSWORD`: Your Docker Hub password or access token.
- `GIT_PUSH_TOKEN`: A GitHub Personal Access Token (Classic or Fine-Grained) with `contents: write` permission for this repository. This is required for the pipeline to push the updated `helm/values.yaml` back to the repository for the GitOps workflow.

The pipeline uses `yq` to update YAML files; this is installed automatically during the workflow.

## Prerequisites

- Java 17 or later
- Docker
- Kubernetes (like `kind` or Minikube for local deployment testing)
- `kubectl` (Kubernetes CLI)
- `helm` (Helm v3+ CLI)
- `yq` (v4+, needed if manually simulating the pipeline's Helm update step locally)

## Local Setup & Testing

### 1. Build and Run Locally (Java/Docker)

```bash
# Ensure Java 17 and Docker are installed and running

# Build the application and run tests
./gradlew build

# Run the Java application directly
# java -jar build/libs/hello-world-1.0-SNAPSHOT.jar

# Build the Docker image
docker build -t hawk-hello-world:local .

# Run the Docker container
docker run --rm hawk-hello-world:local
```

### 2. Full Local GitOps Flow with kind and ArgoCD

This setup replicates the core GitOps deployment flow locally.

**Prerequisites:** `kind`, `kubectl`, `helm`.

```bash
# --- Setup (Only needs to be done once) ---

# 1. Create a local kind cluster
kind create cluster --name hawk-challenge

# 2. Install ArgoCD into the cluster
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD pods to be ready (check with `kubectl get pods -n argocd`)
# This might take a few minutes.

# 3. (Optional) Access ArgoCD UI - requires port-forwarding
# kubectl port-forward svc/argocd-server -n argocd 8080:443 &
# # Get initial admin password:
# kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
# # Access UI at https://localhost:8080 (login as admin with the password)

# 4. Configure ArgoCD to manage the application
#    EDIT `argocd/application.yaml` first:
#    Replace 'REPO_URL_PLACEHOLDER' with the HTTPS URL of YOUR GitHub repository.
#    Example: repoURL: 'https://github.com/your-username/your-repo-name.git'

# Apply the ArgoCD Application manifest to your cluster
kubectl apply -f argocd/application.yaml

# --- Testing the Flow ---

# Now, whenever the GitHub Actions pipeline completes a successful run on the `main` branch:
# 1. The pipeline pushes an updated `helm/values.yaml` to your Git repository.
# 2. ArgoCD (running in your local `kind` cluster) automatically detects this change.
# 3. ArgoCD syncs the change, applying the updated Helm chart to the `default` namespace in your `kind` cluster.

# You can monitor the deployment in your local cluster:
kubectl get deployments -n default
kubectl get pods -n default -w # Watch pods
# Check logs of a specific pod
# kubectl logs <pod-name> -n default

# --- Cleanup ---
# Delete the kind cluster when done
# kind delete cluster --name hawk-challenge
```

