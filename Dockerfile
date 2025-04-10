# Stage 1: Build the application using Gradle
FROM gradle:7.4.2-jdk17 AS builder
WORKDIR /app
# Copy dependency-related files first
COPY build.gradle settings.gradle ./
COPY gradlew ./
COPY gradle ./gradle
# Download dependencies (leverages cache if above files unchanged)
# Build dependencies first to leverage Docker cache.
# This runs build excluding tests/checks; errors ignored to ensure deps are fetched even if code fails early.
RUN ./gradlew build --no-daemon --exclude-task test --exclude-task checkstyleMain || echo "Ignoring build failure for dependency download stage"
# Copy the rest of the source code
COPY src ./src
# Run the full build (will be faster as deps are likely cached)
RUN ./gradlew build --no-daemon

# Stage 2: Create the final lightweight image
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
# Create non-root user/group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
# Copy the built jar from the builder stage, changing ownership immediately
COPY --from=builder --chown=appuser:appgroup /app/build/libs/*.jar app.jar
# Switch to non-root user
USER appuser
ENTRYPOINT ["java", "-jar", "app.jar"]
