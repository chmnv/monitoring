# syntax=docker/dockerfile:1

# =========================================================
# Stage 1 — builder: compile kitchensink.war from source
#   Source comes from the named build context "kitchensink"
#   (the local WildFly Quickstarts, passed via --build-context).
# =========================================================
FROM maven:3.9-eclipse-temurin-21 AS builder

WORKDIR /build

# Resolve dependencies first so this layer stays cached while only source changes.
# The "provisioned-server" profile (active by default) is disabled: we only need
# the WAR artifact, not a provisioned WildFly server under target/.
COPY --from=kitchensink pom.xml ./pom.xml
RUN mvn -B -ntp -P '!provisioned-server' -DskipTests dependency:go-offline

COPY --from=kitchensink src ./src
RUN mvn -B -ntp -P '!provisioned-server' -DskipTests clean package

# Fetch the JMX Exporter java agent from GitHub Releases (pinned + checksum-verified).
# Downloaded independently of the app's Maven build so it is not tied to the
# quickstart POM's repository configuration (which routes to the JBoss repo).
# --chmod=644: ADD-from-URL defaults to 0600 (root-only); WildFly runs as jboss.
ADD --chmod=644 --checksum=sha256:a95983fd96e865d2bcdf911cc500e7c82808c27ab9fd226bf96732b6c3d8c46e \
    https://github.com/prometheus/jmx_exporter/releases/download/v1.6.0/jmx_prometheus_javaagent-1.6.0.jar \
    /opt/jmx/jmx_prometheus_javaagent.jar

# =========================================================
# Stage 2 — runtime: official WildFly with app + JMX agent
# =========================================================
FROM quay.io/wildfly/wildfly:39.0.0.Final-jdk21 AS runtime

# JMX Exporter agent (from builder) + its config (from the primary context).
# --chmod=755 so the auto-created /opt/jmx dir keeps its execute (traverse) bit;
# WildFly runs as jboss and must read these files (ADD-from-URL/COPY default 0600).
COPY --from=builder --chmod=755 /opt/jmx/jmx_prometheus_javaagent.jar /opt/jmx/jmx_prometheus_javaagent.jar
COPY --chmod=755 jmx/config.yml /opt/jmx/config.yml

# Attach the agent via MODULE_OPTS (WildFly-native, read by standalone.sh) rather
# than JAVA_OPTS/-javaagent. WildFly applies MODULE_OPTS agents only AFTER JBoss
# Modules installs org.jboss.logmanager, so the agent no longer initializes JUL too
# early. This avoids the "LogManager was not properly installed" boot failure and
# needs no -Xbootclasspath (jboss-logmanager is a multi-release jar, which is
# incompatible with -Xbootclasspath/a on modern JDKs).
ENV MODULE_OPTS="-javaagent:/opt/jmx/jmx_prometheus_javaagent.jar=9404:/opt/jmx/config.yml"

# Deploy the application built in stage 1.
COPY --from=builder --chown=jboss:jboss /build/target/kitchensink.war \
     "$JBOSS_HOME/standalone/deployments/kitchensink.war"

# Pre-create the log directory owned by jboss. WildFly creates standalone/log at
# runtime, so it does not exist in the image; when we mount a named volume here
# (to share server.log with Promtail) Docker would initialize an EMPTY volume as
# root:root, and WildFly (running as jboss) could not create server.log
# ("Permission denied"). Creating it here as jboss makes Docker seed the volume
# with jboss ownership instead.
RUN mkdir -p "$JBOSS_HOME/standalone/log"

# Create a management user so the console/HTTP management API at :9990 accept a login
# (mgmt-users.properties is empty otherwise). Credentials come from build args so they
# are not hardcoded; --silent suppresses the interactive prompt.
ARG MGMT_USER=admin
ARG MGMT_PASSWORD=admin
RUN "$JBOSS_HOME/bin/add-user.sh" "$MGMT_USER" "$MGMT_PASSWORD" --silent

# Enable the MANAGEMENT AUDIT LOG at build time (edits standalone.xml offline via
# embed-server). WildFly ships it disabled; once on, every management operation is
# recorded as JSON (user, access type HTTP/CLI/NATIVE, remote address, success,
# read/write) — the data source for the Security & Audit dashboard.
#   - enabled=true            : turn the audit logger on
#   - log-read-only=true      : also record read operations (console browsing, reads),
#                               so the dashboard has activity to show, not only changes
#   - file-handler relative-to=jboss.server.log.dir : write audit-log.log into
#                               standalone/log (the volume shared with Promtail) instead
#                               of standalone/data (which Promtail does not mount)
#   - json-formatter compact=true : write each record as ONE line of JSON so Promtail
#                               can parse it (default is pretty-printed multi-line JSON)
RUN "$JBOSS_HOME/bin/jboss-cli.sh" --commands="embed-server --server-config=standalone.xml,/core-service=management/access=audit/logger=audit-log:write-attribute(name=enabled,value=true),/core-service=management/access=audit/logger=audit-log:write-attribute(name=log-read-only,value=true),/core-service=management/access=audit/file-handler=file:write-attribute(name=relative-to,value=jboss.server.log.dir),/core-service=management/access=audit/json-formatter=json-formatter:write-attribute(name=compact,value=true),stop-embedded-server"

# 8080 = app | 9990 = management | 9404 = Prometheus metrics (JMX Exporter)
EXPOSE 8080 9990 9404

# Bind BOTH interfaces to all addresses so the management port is reachable from the host:
#   -b 0.0.0.0            -> public interface (app :8080), same as the base image default
#   -bmanagement 0.0.0.0  -> management interface (:9990); default is 127.0.0.1, so
#                            without it WildFly listens only on loopback inside the
#                            container and the published port is refused.
# MODULE_OPTS (JMX agent on :9404) is read by standalone.sh independently and is unaffected.
# -Dwildfly.statistics-enabled=true turns on subsystem statistics (Undertow requests,
# datasource pools, transactions, EJB) so the native :9990/metrics counters are non-zero.
CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0", "-bmanagement", "0.0.0.0", "-Dwildfly.statistics-enabled=true"]
