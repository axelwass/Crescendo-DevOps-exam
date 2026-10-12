# Stage 1: fetch the Magnolia CE webapp
FROM eclipse-temurin:17-jdk AS build
ARG MAGNOLIA_VERSION=6.3.28
ARG PG_DRIVER_VERSION=42.7.4

RUN apt-get update && apt-get install -y --no-install-recommends unzip curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN curl -fsSL -o magnolia.war \
      "https://nexus.magnolia-cms.com/repository/magnolia.public.releases/info/magnolia/bundle/magnolia-community-webapp/${MAGNOLIA_VERSION}/magnolia-community-webapp-${MAGNOLIA_VERSION}.war" \
    && unzip -q magnolia.war -d ROOT \
    && curl -fsSL -o postgresql.jar \
      "https://repo1.maven.org/maven2/org/postgresql/postgresql/${PG_DRIVER_VERSION}/postgresql-${PG_DRIVER_VERSION}.jar"

COPY config/magnolia.properties /build/magnolia.properties
RUN cat /build/magnolia.properties >> /build/ROOT/WEB-INF/config/default/magnolia.properties

# Stage 2: Tomcat runtime
FROM tomcat:9.0-jdk17-temurin
RUN apt-get update && apt-get install -y --no-install-recommends gettext-base \
    && rm -rf /var/lib/apt/lists/* /usr/local/tomcat/webapps/*

COPY --from=build /build/postgresql.jar /usr/local/tomcat/lib/
COPY --from=build /build/ROOT /usr/local/tomcat/webapps/ROOT
COPY config/jackrabbit-bundle-postgres-search.xml /opt/magnolia/config/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV JAVA_OPTS="-Xms512m -Xmx1536m" \
    DB_URL="jdbc:postgresql://db:5432/magnolia"

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
CMD ["catalina.sh", "run"]
