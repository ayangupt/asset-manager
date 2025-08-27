# Build stage
FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /build

# Copy all pom files first for better caching
COPY pom.xml ./
COPY web/pom.xml ./web/
COPY worker/pom.xml ./worker/

# Copy source code
COPY web/src ./web/src

# Build the web application
RUN mvn clean package -pl web -am -DskipTests

# Runtime stage
FROM eclipse-temurin:21-jre
WORKDIR /app

# Copy the built jar from build stage
COPY --from=build /build/web/target/*.jar app.jar

# Expose port
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
