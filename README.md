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
2. Run tests with JUnit and measure code coverage with JaCoCo
3. Perform static code analysis with Checkstyle
4. Build a Docker image
5. Scan the Docker image for vulnerabilities with Trivy
6. Push the Docker image to Docker Hub
7. Deploy to an ephemeral environment using kind (Kubernetes in Docker)
8. Run smoke tests on the ephemeral environment
9. Update the Helm chart with the new image tag and switch deployment color
10. ArgoCD will detect the change and deploy to production (not included in this demo)

## Blue-Green Deployment

The Helm chart is configured for blue-green deployments. The pipeline automatically switches between blue and green deployments with each successful build.

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

Before running the pipeline, you need to set up the following secrets in your GitHub repository:

- `DOCKER_USERNAME`: Your Docker Hub username
- `DOCKER_PASSWORD`: Your Docker Hub password or access token

## Prerequisites

- Java 17 or later
- Docker
- Kubernetes (for deployment)
- Helm (for Kubernetes package management)
