# Build da API dentro do Docker: evita depender de target/*.jar do host/Jenkins.
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /workspace

COPY pom.xml .
RUN mvn -B -q -DskipTests dependency:go-offline

COPY src ./src
RUN mvn -B -DskipTests clean package

FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

RUN groupadd --system app && useradd --system --gid app --no-create-home app
COPY --from=build /workspace/target/jogo-enigma-api-*.jar /app/app.jar

USER app
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
