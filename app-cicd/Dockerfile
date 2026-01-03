# syntax=docker/dockerfile:1
FROM public.ecr.aws/docker/library/maven:3.9.6-eclipse-temurin-17 AS build
WORKDIR /workspace
COPY pom.xml ./
COPY checkstyle.xml ./
COPY src ./src
RUN mvn -B -DskipTests package

FROM public.ecr.aws/docker/library/eclipse-temurin:17-jre-alpine
RUN addgroup --system app && adduser --system --ingroup app app
USER app
WORKDIR /home/app
COPY --from=build /workspace/target/devsecops-demo-1.0.0.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
