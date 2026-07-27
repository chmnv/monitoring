# Local Monitoring Platform — WildFly + Prometheus + Grafana + Loki

Production-style, fully local observability stack for a Java app on **WildFly 39**.
Infrastructure, JVM, application and business metrics go to Prometheus; logs and
management audit go to Loki; Grafana visualizes and alerts via **Telegram + Jira**
(email contact point exists but is not on the active notification route).

## Architecture

**Metrics**

```
WildFly JMX Exporter (:9404) ──────────────┐
WildFly native /metrics (:9990) ───────────┤
kitchensink /metrics (:8080) ──────────────┼──> Prometheus (:9090) ──> Grafana (:3000)
windows_exporter (Windows host :9182) ─────┘
```

**Logs**

```
WildFly server.log + audit-log.log ──> Promtail ──> Loki (:3100) ──> Grafana (:3000)
```

**Alerts**

```
Grafana Unified Alerting ──> contact point "telegram"
                              ├─ Telegram bot (FIRING / RESOLVED)
                              └─ jira-bridge webhook (FIRING → Jira issue)
```

Contact point `email-admin` is provisioned but **not** attached to the active policy
(Telegram + Jira is the demo path).
cAdvisor was evaluated and **dropped**: on Docker Desktop / WSL2 it cannot expose
reliable per-container metrics. Host metrics come from `windows_exporter` instead.

## Stack (pinned versions, official images only)

| Component          | Image / Artifact                             | Version              |
|--------------------|----------------------------------------------|----------------------|
| WildFly runtime    | `quay.io/wildfly/wildfly`                    | `39.0.0.Final-jdk21` |
| Maven builder      | `maven`                                      | `3.9-eclipse-temurin-21` |
| JMX Exporter       | `jmx_prometheus_javaagent`                   | `1.6.0`              |
| Prometheus         | `prom/prometheus`                            | `v3.5.0`             |
| Grafana            | `grafana/grafana`                            | `11.6.1`             |
| Loki / Promtail    | `grafana/loki`, `grafana/promtail`           | `3.5.1`              |
| windows_exporter   | runs on the Windows host (not in Docker)     | host install         |
| kitchensink app    | built from `./kitchensink` into the WildFly image | in-repo source   |

No `:latest` tags.

## Repository layout

Everything needed to build and run lives in **this** repository:

```
monitoring/
├── README.md
├── docker-compose.yml
├── smtp.example.env              # copy to .env (git-ignored) for Gmail SMTP
├── kitchensink/                  # app source (vendored; business metrics live here)
├── wildfly/
│   ├── Dockerfile                # multi-stage: Maven WAR + WildFly + JMX agent
│   └── jmx/config.yml
├── scripts/
│   ├── demo-all.ps1              # drive ALL dashboards (traffic + mgmt/audit)
│   ├── load-traffic.ps1          # HTTP + DB + business load (parallel workers)
│   ├── mgmt-activity.ps1         # management read+write ops for Security & Audit
│   └── demo-burst.ps1            # short burst for live demos
├── prometheus/prometheus.yml
├── loki/loki-config.yml
├── promtail/promtail-config.yml
└── grafana/
    ├── provisioning/
    │   ├── datasources/          # Prometheus + Loki
    │   ├── dashboards/           # provider
    │   └── alerting/             # contact point, policy, alert rules (as code)
    └── dashboards/               # dashboards-as-code (JSON)
```

The WAR is **never** committed — it is always built from `./kitchensink` during the image build.

## Dashboards (provisioned)

| # | Dashboard | UID | Focus |
|---|-----------|-----|-------|
| 01 | Platform Overview | `afsypu2byt8u8b` | Single pane of glass + drill-downs |
| 02 | Windows Host | `windows-host` | CPU / RAM / disk / network |
| 03 | JVM Overview | `jvm-overview` | Heap, GC, threads, classes |
| 04 | WildFly HTTP & Datasources | `wildfly-http-db` | Undertow RED + datasource pool |
| 05 | Database & Query Timing | `wildfly-db` | ExampleDS pool + app DB ops |
| 06 | Application - Kitchensink Business | `kitchensink-app` | Registrations, failures, duration |
| 07 | WildFly Logs | `wildfly-logs` | Log volume, levels, live stream |
| 08 | WildFly Security & Audit | `wildfly-security` | Management audit trail |
| 09 | System Health & SLA | `system-health` | SLA, error budget, SLOs |
| 10 | Registration Quality & Validation | `registration-quality` | Field/constraint friction (deep dive) |
| 11 | Search & Discovery | `search-discovery` | Hit / zero / refine search quality |
| 12 | Authentication & Sessions | `auth-sessions` | App login outcomes + active sessions |
| 13 | Account Activation | `account-activation` | Pending → token → activated funnel |

Target for mentor deliverable: **15** (see private notes / roadmap). Current live set: **13**.

## Application / business metrics

`kitchensink` exposes Prometheus metrics at `/kitchensink/metrics` (scraped as job
`kitchensink-app`):

- `kitchensink_registrations_total` — successful registrations
- `kitchensink_registration_attempts_total` — every POST attempt (success + failure)
- `kitchensink_registration_failures_total{reason=...}` — validation / duplicate_email / error
- `kitchensink_registration_field_failures_total{field,constraint}` — per-field deep dive (dashboard 10)
- `kitchensink_searches_total{outcome}` — search hit / zero / empty / refine / error (dashboard 11)
- `kitchensink_search_duration_seconds` — search latency histogram
- `kitchensink_search_results` — result-set size histogram
- `kitchensink_auth_attempts_total{outcome}` — login success / bad_credentials / unknown_user / not_activated / error (dashboard 12)
- `kitchensink_auth_logouts_total` — application logouts
- `kitchensink_auth_duration_seconds` — login latency histogram
- `kitchensink_active_sessions` — authenticated app sessions gauge
- `kitchensink_activation_attempts_total{outcome}` — activation success / invalid_token / expired / already_activated / error (dashboard 13)
- `kitchensink_activation_duration_seconds` — activation latency histogram
- `kitchensink_accounts_pending` — pending (not yet activated) accounts
- `kitchensink_accounts_activated_total` — successful activations
- `kitchensink_registration_duration_seconds` — histogram (avg / p95 / p99)
- `kitchensink_db_operation_duration_seconds{operation}` — JPA/DB op timing
  (`findAll`, `findById`, `findByEmail`, `persist` after flush, `countAll`)

## Alerts (as code)

Provisioned under `grafana/provisioning/alerting/`:

| Rule                 | Condition                         | Severity |
|----------------------|-----------------------------------|----------|
| WildFly Down         | `up{job="wildfly-jmx"} < 1` for 1m | critical |
| High Host CPU        | CPU busy > 85% for 5m             | warning  |
| High Host Memory     | RAM used > 93% for 5m             | warning  |
| Disk C Almost Full   | C: used > 90% for 5m              | warning  |

SMTP / Telegram / Jira are wired via `.env` (see `smtp.example.env`). Active contact point
`telegram` notifies Telegram (HTML template) and posts a webhook to `jira-bridge`, which creates a
Jira Cloud issue (native Grafana Jira notifier hits a removed Atlassian search API).
`email-admin` remains available for optional use but is not on the default route.

## Prerequisites

- **Docker Desktop** (Engine ≥ 23, BuildKit on — default on Windows)
- **windows_exporter** listening on the host at `:9182` (for the Windows Host dashboard)
- For email alerts: Gmail + [App Password](https://myaccount.google.com/apppasswords)
  (2-Step Verification must be enabled)
- For Telegram + Jira: bot token / chat id + Atlassian API token (see `smtp.example.env`)

## Quick start

```powershell
cd monitoring

# 1) (optional) email alerts — copy template and fill real values
copy smtp.example.env .env

# 2) start the stack (builds WildFly from ./kitchensink on first run)
docker compose up -d --build

# 3) check
docker compose ps
```

Open:

| URL | What |
|-----|------|
| http://localhost:8080/kitchensink | Application |
| http://localhost:8080/kitchensink/search.html | Member search (dashboard 11) |
| http://localhost:8080/kitchensink/login.html | Member login (dashboard 12) |
| http://localhost:8080/kitchensink/activate.html | Account activation (dashboard 13) |
| http://localhost:9990 | WildFly Management (`admin` / `admin`) |
| http://localhost:9404/metrics | JMX Exporter |
| http://localhost:8080/kitchensink/metrics | Business metrics |
| http://localhost:9090/targets | Prometheus targets |
| http://localhost:3000 | Grafana (`admin` / `admin`) |
| http://localhost:3100/ready | Loki |

## Ports

| Port | Service |
|------|---------|
| 8080 | WildFly application + `/kitchensink/metrics` |
| 9404 | JMX Exporter |
| 9990 | WildFly management + native `/metrics` |
| 9090 | Prometheus |
| 3000 | Grafana |
| 3100 | Loki |
| 9182 | windows_exporter (host) |

## How the WildFly image is built

Multi-stage Dockerfile + BuildKit named context `kitchensink` → `./kitchensink`:

1. **Builder (JDK 21):** `mvn package` builds `kitchensink.war`; JMX agent jar is
   downloaded at a pinned version and SHA-256 verified.
2. **Runtime (WildFly 39):** WAR + agent + `jmx/config.yml`. Agent is attached via
   `MODULE_OPTS` (after JBoss LogManager is installed). The JMX config keeps
   DefaultExports only (`jvm_*` / `process_*`); WildFly MBeans are scraped via
   `:9990/metrics` instead (avoids high-cardinality `jboss_remoting_*` IDs).
   Management user, audit log (compact JSON into `standalone/log`), and
   `-Dwildfly.statistics-enabled=true` are configured at build/start so
   Undertow/datasource metrics and audit shipping work.

```powershell
# Rebuild only WildFly after app changes:
docker compose up -d --build wildfly
```

## Demo checks

```powershell
# Make EVERY dashboard live at once (traffic + management/audit activity)
.\scripts\demo-all.ps1 -DurationSec 300 -Workers 6

# Or just app traffic (HTTP + DB + business). Use -Workers for parallel requests.
.\scripts\load-traffic.ps1 -DurationSec 300 -DelayMs 80 -Workers 6 -Failures

# Only management/audit activity (Security & Audit dashboard)
.\scripts\mgmt-activity.ps1 -Rounds 40 -DelayMs 750

# Short burst for a live demo / screenshots
.\scripts\demo-burst.ps1

# Business metrics: register + force a validation failure
# then open http://localhost:3000/d/kitchensink-app

# Alert demo: stop WildFly → Telegram + Jira ticket; start → RESOLVED (TG)
docker stop wildfly
docker start wildfly
```

## Status / roadmap

- [x] WildFly image (multi-stage, JMX Exporter, management, audit log)
- [x] kitchensink vendored in-repo + business metrics endpoint
- [x] Prometheus (JMX + native `:9990` + kitchensink-app + windows)
- [x] Grafana datasources + dashboards-as-code (01–11)
- [x] Loki + Promtail (server.log + audit-log)
- [x] Email alerts (Gmail SMTP, rules as code)
- [x] Telegram + Jira tickets (`jira-bridge` webhook)
- [x] H2 / Database & Query Timing + System Health & SLA
- [x] JMX cardinality tighten (DefaultExports only)
- [ ] Optional report generation / presentation polish
