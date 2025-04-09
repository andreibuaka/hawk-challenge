# Stage 1: Build the application using Gradle
FROM gradle:7.4.2-jdk17 AS builder
WORKDIR /app
COPY . .
RUN gradle build --no-daemon

# Stage 2: Create the final lightweight image
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
# Copy the built jar from the builder stage
COPY --from=builder /app/build/libs/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
