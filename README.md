# Local Monitoring Platform — WildFly + Prometheus + Grafana + Loki

A production-like, fully local observability stack for a Java application running on
**WildFly 39**. It collects infrastructure, container, JVM and application metrics,
ships application logs, and visualizes everything in Grafana with alerting.

> Status: implemented **step by step**. Currently done: the WildFly application image
> (multi-stage build of the `kitchensink` quickstart + JMX Exporter). The Compose stack
> (Prometheus, Grafana, Loki, Promtail, cAdvisor, windows_exporter) is added next.

## Architecture

**Metrics**

```
WildFly (JVM + app MBeans) ──> JMX Exporter (:9404) ─┐
cAdvisor (containers) ───────────────────────────────┼──> Prometheus (:9090) ──> Grafana (:3000)
windows_exporter (Windows host) ─────────────────────┘
```

**Logs**

```
WildFly logs ──> Promtail ──> Loki (:3100) ──> Grafana (:3000)
```

## Stack (pinned versions, official images only)

| Component        | Image / Artifact                                   | Version           |
|------------------|----------------------------------------------------|-------------------|
| WildFly runtime  | `quay.io/wildfly/wildfly`                           | `39.0.0.Final-jdk21` |
| Maven builder    | `maven`                                            | `3.9-eclipse-temurin-21` |
| JMX Exporter     | `io.prometheus.jmx:jmx_prometheus_javaagent`       | `1.6.0`           |
| Prometheus       | _added in the Compose step_                         | pinned            |
| Grafana          | _added in the Compose step_                         | pinned            |
| Loki / Promtail  | _added in the Compose step_                         | pinned            |
| cAdvisor         | _added in the Compose step_                         | pinned            |
| windows_exporter | runs on the Windows host (not in Docker)           | pinned            |

No `latest` tags are used anywhere.

## Repository layout (two SEPARATE local projects)

The application source (WildFly Quickstarts) and this monitoring project are kept in
**separate repositories that live side by side** under a common parent folder:

```
Projects/
├── monitoring/                         # THIS repository (the deliverable)
│   ├── README.md
│   ├── docker-compose.yml              # (added in the Compose step)
│   └── wildfly/
│       ├── Dockerfile                  # multi-stage build (JDK 21)
│       ├── .dockerignore               # standard name, lives inside this repo
│       └── jmx/
│           └── config.yml              # JMX Exporter rules
└── wildfly-39.0.0.Final-quickstarts/   # SEPARATE local repo (never modified)
    └── kitchensink/                    # application source built from Maven
        ├── pom.xml
        └── src/
```

The Quickstarts repository is **never moved into or modified by** this project.
No prebuilt WAR is stored in Git — it is always built from source during the image build.

## How the WildFly image is built

The image uses a **multi-stage build** plus **BuildKit named additional contexts** so that:

- the **primary build context** is `monitoring/wildfly/` (so a standard `.dockerignore`
  lives inside this repo), and
- the application source is supplied as a **named context `kitchensink`** pointing to the
  **local** Quickstarts folder — no `git clone`, no copying source into this repo.

Build flow:

1. **Stage 1 (builder, JDK 21):** `mvn package` compiles `kitchensink.war` from the local
   source (the default `provisioned-server` profile is disabled — we only need the WAR).
   The JMX Exporter agent jar is downloaded from GitHub Releases at a pinned version,
   verified by SHA-256 (independent of the app's Maven repositories).
2. **Stage 2 (runtime, JDK 21):** the official WildFly image receives only the built WAR,
   the JMX agent jar, and `config.yml`. The agent is attached via `MODULE_OPTS` (the
   WildFly-native way to add a java agent) so it loads only after JBoss Modules installs
   `org.jboss.logmanager` — this avoids the "LogManager was not properly installed" boot
   failure that a plain `-javaagent`/`-Xbootclasspath` attachment causes with WildFly.
   Maven, the JDK toolchain, the source and the `.m2` cache stay in the builder and never
   reach the final image.

## Prerequisites

- **Docker Desktop** (Docker Engine ≥ 23, BuildKit enabled — default on Windows/Mac).
- The **WildFly Quickstarts 39** folder present next to `monitoring/` exactly as shown in
  the layout above (this project builds from that local source).

## Build & run the WildFly image (current step)

Run from the `monitoring/` directory:

```bash
docker build \
  --build-context kitchensink=../wildfly-39.0.0.Final-quickstarts/kitchensink \
  -t kitchensink-wildfly:39.0.0.Final \
  ./wildfly
```

Run it:

```bash
docker run --rm -p 8080:8080 -p 9404:9404 kitchensink-wildfly:39.0.0.Final
```

Verify:

- Application: <http://localhost:8080/kitchensink>
- Metrics: <http://localhost:9404/metrics> (JVM `java.lang:*` and WildFly `jboss.as:*`)

## Ports

| Port | Service                         |
|------|--------------------------------|
| 8080 | WildFly application            |
| 9404 | JMX Exporter (Prometheus)      |
| 9990 | WildFly management (exposed, used later) |
| 9090 | Prometheus (Compose step)      |
| 3000 | Grafana (Compose step)         |
| 3100 | Loki (Compose step)            |

## Roadmap

- [x] WildFly application image (multi-stage, JDK 21, JMX Exporter)
- [ ] `docker-compose.yml` — WildFly service (healthcheck, volumes, restart policy)
- [ ] Prometheus + scrape config
- [ ] cAdvisor + windows_exporter targets
- [ ] Loki + Promtail (WildFly log shipping)
- [ ] Grafana (datasources + dashboards)
- [ ] PromQL / LogQL panels and alert rules
