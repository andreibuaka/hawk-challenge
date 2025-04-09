# Stage 1: Build the application using Gradle
FROM gradle:7.4-jdk17 AS builder
WORKDIR /app
COPY build.gradle settings.gradle /app/
COPY src /app/src
# Grant execute permission for gradlew
RUN chmod +x ./gradlew || true # Allow failure if gradlew doesn't exist initially
COPY gradlew gradlew.bat /app/
RUN ./gradlew build --no-daemon

# Stage 2: Create the final lightweight image
FROM openjdk:17-jdk-slim
WORKDIR /app
# Copy the built jar from the builder stage
COPY --from=builder /app/build/libs/*.jar app.jar
# Expose port if needed (not strictly needed for console output)
# EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"] 