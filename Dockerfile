    # Stage 1: Build the application using Gradle
    FROM gradle:7.4.2-jdk17-focal AS builder
    WORKDIR /app

    # Copy dependency-related files first
    COPY build.gradle settings.gradle ./
    COPY gradlew ./
    COPY gradle ./gradle

    # Ensure gradlew is executable
    RUN chmod +x gradlew

    # Set Gradle options for better performance in containers
    ENV GRADLE_OPTS="-Dorg.gradle.daemon=false -Dorg.gradle.parallel=true -Dorg.gradle.caching=true"

    # Download dependencies (leverages cache if above files unchanged)
    # Build dependencies first to leverage Docker cache.
    # This runs build excluding tests/checks; errors ignored to ensure deps are fetched even if code fails early.
    RUN ./gradlew dependencies --no-daemon || echo "Ignoring build failure for dependency download stage"

    # Copy the rest of the source code
    COPY src ./src
    COPY config ./config

    # ---- Debug: Confirm working directory and cat the config file ----
    RUN pwd
    RUN cat /app/config/checkstyle.xml
    # ---------------------------------------------------------------

    # Run the full build (will be faster as deps are likely cached)
    RUN ./gradlew build --no-daemon

    # Stage 2: Create the final lightweight image
    FROM amazoncorretto:17-alpine
    WORKDIR /app

    # Add security patches and curl for health checks
    RUN apk update && \
        apk upgrade && \
        apk add --no-cache curl && \
        rm -rf /var/cache/apk/*

    # Create non-root user/group
    RUN addgroup -S appgroup && adduser -S appuser -G appgroup

    # Create directory for app with proper permissions
    RUN mkdir -p /app/logs && \
        chown -R appuser:appgroup /app

    # Copy the built jar from the builder stage, changing ownership immediately
    COPY --from=builder --chown=appuser:appgroup /app/build/libs/*.jar app.jar

    # Set security flags
    ENV JAVA_TOOL_OPTIONS="-Djava.security.egd=file:/dev/./urandom -Dfile.encoding=UTF-8"

    # Switch to non-root user
    USER appuser

    # Health check - check if Java process is running
    HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
      CMD ps -ef | grep java | grep app.jar || exit 1

    # Run with explicit memory limits for container awareness
    ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]