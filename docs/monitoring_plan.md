# Monitoring Infrastructure Plan

**Document Version:** 1.0
**Iteration:** I7 - Deploy monitoring infrastructure
**Last Updated:** 2025-11-01
**Owner:** Infrastructure Team

## 1. Executive Summary

This document defines the monitoring architecture for the hybrid infrastructure managed via Nix Flakes (local systems), OpenTofu (Hetzner VPS provisioning), and Ansible (VPS configuration). The monitoring stack provides centralized observability for 6 managed systems (3 local, 3 cloud VPS) through metrics collection, log aggregation, visualization, and alerting.

**Key Decisions:**
- **Deployment Location:** srv-01 (x86_64 NixOS local server) - see Section 2.1 for rationale
- **Monitoring Stack:** Prometheus, Grafana, Loki, Alertmanager (all deployed on srv-01)
- **Monitoring Agents:** node_exporter (metrics) and Promtail (logs) on all 6 systems
- **Network Topology:** Private network (10.0.0.0/16) for Hetzner VPS, localhost for local systems
- **Retention Policies:** Metrics 30 days, logs 30 days hot / 90 days cold, alerts 90 days

**Implementation Phases:**
1. **Phase 1 (Task I7.T2):** Deploy monitoring stack on srv-01 (NixOS modules)
2. **Phase 2 (Task I7.T3):** Deploy monitoring agents to test-1.dev.nbg (testing)
3. **Phase 3 (Future):** Deploy monitoring agents to production VPS (mail-1, syncthing-1)

## 2. Architecture Overview

### 2.1. Deployment Location Decision

**Recommendation: srv-01 (NixOS local server)**

| Factor | srv-01 | Dedicated VPS |
|--------|--------|---------------|
| **Cost** | $0 (existing hardware) | ~$5-10/month (CAX11 instance) |
| **Management** | NixOS declarative config | Ansible imperative config |
| **Reproducibility** | Full (Nix flake) | Limited (Ansible idempotence) |
| **Scalability** | Suitable for <10 systems | Suitable for 10-50 systems |
| **Availability** | Requires always-on srv-01 | 99.9% SLA (Hetzner Cloud) |
| **Network Access** | Local network + VPN/SSH tunnel for VPS | Native private network (10.0.0.0/16) |

**Decision Rationale:**
- **Current scale:** 6 systems is well within srv-01 capacity (Prometheus ~1GB RAM, Grafana ~500MB, Loki ~1GB)
- **Cost efficiency:** No additional cloud costs
- **Operational simplicity:** NixOS declarative configuration aligns with existing local system management
- **Migration path:** Easy to migrate to dedicated VPS if scale exceeds srv-01 capacity (export Prometheus/Loki data, redeploy stack)

**Critical Constraint:** srv-01 is described as "configuration only, not deployed" in CLAUDE.md. **Before Phase 1 implementation, verify srv-01 is deployed and always-on.** If not, either:
1. Deploy srv-01 as always-on local server, OR
2. Provision dedicated monitoring VPS (mail-1 has sufficient capacity: CAX21, 8GB RAM)

### 2.2. Monitoring Stack Components

#### 2.2.1. Prometheus (Metrics Database)

- **Version:** 2.x (latest stable from nixpkgs)
- **Purpose:** Time-series metrics storage and querying
- **Port:** 9090 (HTTP API, web UI)
- **Storage:** `/var/lib/prometheus` (NixOS default)
- **Retention:** 30 days (configurable via `--storage.tsdb.retention.time=30d`)
- **Scrape Interval:** 15 seconds (balances resolution vs. storage)
- **High Availability:** Single instance (sufficient for current scale)

**Scrape Configuration:**
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # Local systems (localhost, local network)
  - job_name: 'srv-01'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          environment: 'local'
          platform: 'nixos'
          arch: 'x86_64'

  - job_name: 'xbook'
    static_configs:
      - targets: ['xbook:9100']
        labels:
          environment: 'local'
          platform: 'darwin'
          arch: 'arm64'

  - job_name: 'xmsi'
    static_configs:
      - targets: ['xmsi:9100']
        labels:
          environment: 'local'
          platform: 'nixos'
          arch: 'x86_64'

  # Hetzner Cloud VPS (private network)
  - job_name: 'mail-1'
    static_configs:
      - targets: ['10.0.0.10:9100']
        labels:
          environment: 'prod'
          platform: 'debian'
          arch: 'arm64'
          datacenter: 'nbg1'

  - job_name: 'syncthing-1'
    static_configs:
      - targets: ['10.0.0.11:9100']
        labels:
          environment: 'prod'
          platform: 'rocky'
          arch: 'arm64'
          datacenter: 'hel1'

  - job_name: 'test-1'
    static_configs:
      - targets: ['10.0.0.20:9100']
        labels:
          environment: 'dev'
          platform: 'ubuntu'
          arch: 'arm64'
          datacenter: 'nbg1'
```

**NixOS Configuration (srv-01):**
```nix
services.prometheus = {
  enable = true;
  port = 9090;
  retention = "30d";
  scrapeConfigs = [
    # See YAML above for full configuration
  ];
};
```

#### 2.2.2. Grafana (Visualization Platform)

- **Version:** 10.x (latest stable from nixpkgs)
- **Purpose:** Dashboards and visualization for metrics and logs
- **Port:** 3000 (HTTP web UI)
- **Storage:** `/var/lib/grafana` (dashboards, user settings)
- **Access:** Restricted to operator workstation (firewall rules, no public exposure)
- **Authentication:** Local admin account (initial setup), future: OAuth/SSO

**Data Sources:**
1. **Prometheus:** `http://localhost:9090` (metrics)
2. **Loki:** `http://localhost:3100` (logs)

**NixOS Configuration (srv-01):**
```nix
services.grafana = {
  enable = true;
  settings = {
    server = {
      http_addr = "0.0.0.0";
      http_port = 3000;
      domain = "srv-01.dev.zz";
    };
    security = {
      admin_user = "admin";
      admin_password = "$__file{/run/secrets/grafana_admin_password}";
    };
  };
  provision = {
    enable = true;
    datasources.settings.datasources = [
      {
        name = "Prometheus";
        type = "prometheus";
        url = "http://localhost:9090";
        isDefault = true;
      }
      {
        name = "Loki";
        type = "loki";
        url = "http://localhost:3100";
      }
    ];
  };
};
```

**Firewall Configuration:**
- **Allow:** Operator workstation IP only (configure via nixos firewall rules)
- **Deny:** All other sources (default deny)

#### 2.2.3. Loki (Log Aggregation)

- **Version:** 2.9.x (latest stable from nixpkgs)
- **Purpose:** Centralized log storage and querying (like Prometheus, but for logs)
- **Port:** 3100 (HTTP API for Promtail ingestion and Grafana queries)
- **Storage:** `/var/lib/loki` (chunks and index)
- **Retention:**
  - **Hot storage:** 30 days (recent logs, fast queries)
  - **Cold storage:** 90 days (archived logs, slower queries)
- **Ingestion Rate:** ~100KB/s (sufficient for 6 systems)

**Retention Configuration:**
```yaml
limits_config:
  retention_period: 2160h  # 90 days total retention

table_manager:
  retention_deletes_enabled: true
  retention_period: 2160h

chunk_store_config:
  max_look_back_period: 720h  # 30 days hot storage

compactor:
  working_directory: /var/lib/loki/compactor
  shared_store: filesystem
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150
```

**NixOS Configuration (srv-01):**
```nix
services.loki = {
  enable = true;
  configuration = {
    server.http_listen_port = 3100;
    auth_enabled = false;

    ingester = {
      lifecycler = {
        address = "127.0.0.1";
        ring = {
          kvstore.store = "inmemory";
          replication_factor = 1;
        };
      };
      chunk_idle_period = "1h";
      max_chunk_age = "1h";
      chunk_target_size = 999999;
      chunk_retain_period = "30s";
    };

    schema_config = {
      configs = [{
        from = "2024-01-01";
        store = "boltdb-shipper";
        object_store = "filesystem";
        schema = "v11";
        index = {
          prefix = "index_";
          period = "24h";
        };
      }];
    };

    storage_config = {
      boltdb_shipper = {
        active_index_directory = "/var/lib/loki/boltdb-shipper-active";
        cache_location = "/var/lib/loki/boltdb-shipper-cache";
        cache_ttl = "24h";
        shared_store = "filesystem";
      };
      filesystem.directory = "/var/lib/loki/chunks";
    };

    limits_config = {
      retention_period = "2160h";  # 90 days
    };

    compactor = {
      working_directory = "/var/lib/loki/compactor";
      shared_store = "filesystem";
      compaction_interval = "10m";
      retention_enabled = true;
      retention_delete_delay = "2h";
    };
  };
};
```

#### 2.2.4. Alertmanager (Alert Routing)

- **Version:** 0.27.x (latest stable from nixpkgs)
- **Purpose:** Alert deduplication, grouping, routing, and notifications
- **Port:** 9093 (HTTP API, web UI)
- **Storage:** `/var/lib/alertmanager` (alert state, silences)
- **Retention:** 90 days (alert history)
- **Notification Channels:**
  1. **Email:** SMTP relay (initial implementation)
  2. **Matrix:** Matrix homeserver API (future enhancement)

**Routing Configuration:**
```yaml
global:
  smtp_smarthost: 'localhost:25'
  smtp_from: 'alertmanager@srv-01.dev.zz'

route:
  receiver: 'default-email'
  group_by: ['alertname', 'environment', 'instance']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
    - match:
        severity: critical
      receiver: 'critical-email'
      repeat_interval: 1h
    - match:
        severity: warning
      receiver: 'warning-email'
      repeat_interval: 4h

receivers:
  - name: 'default-email'
    email_configs:
      - to: 'operator@example.com'
        headers:
          Subject: '[INFRA] {{ .GroupLabels.alertname }} - {{ .GroupLabels.environment }}'

  - name: 'critical-email'
    email_configs:
      - to: 'operator@example.com'
        headers:
          Subject: '[CRITICAL] {{ .GroupLabels.alertname }} - {{ .GroupLabels.environment }}'

  - name: 'warning-email'
    email_configs:
      - to: 'operator@example.com'
        headers:
          Subject: '[WARNING] {{ .GroupLabels.alertname }} - {{ .GroupLabels.environment }}'
```

**NixOS Configuration (srv-01):**
```nix
services.prometheus.alertmanager = {
  enable = true;
  port = 9093;
  configuration = {
    # See YAML above for full configuration
  };
};
```

### 2.3. Monitoring Agents

#### 2.3.1. node_exporter (Metrics Exporter)

- **Version:** 1.8.2 (defined in `ansible/roles/monitoring/defaults/main.yaml`)
- **Purpose:** Exports system metrics (CPU, memory, disk, network) in Prometheus format
- **Port:** 9100 (HTTP metrics endpoint)
- **Installation:**
  - **Local NixOS/Darwin systems:** NixOS/Nix Darwin service module
  - **Hetzner VPS:** Ansible role `monitoring` (tasks/main.yaml)
- **Architecture Support:** ARM64 and AMD64 (critical for Hetzner CAX instances)

**Exported Metrics (subset):**
- `node_cpu_seconds_total` - CPU time per mode (idle, user, system, iowait)
- `node_memory_MemTotal_bytes` / `node_memory_MemAvailable_bytes` - Memory usage
- `node_filesystem_avail_bytes` / `node_filesystem_size_bytes` - Disk usage
- `node_network_receive_bytes_total` / `node_network_transmit_bytes_total` - Network throughput
- `node_systemd_unit_state` - Systemd service status (NixOS, Debian, Rocky, Ubuntu)

**Firewall Configuration:**
- **Hetzner VPS:** Configured automatically by Ansible role (firewalld for RedHat, ufw for Debian)
- **Local systems:** Allow on localhost only (no external access required)

**NixOS Configuration (srv-01, xmsi):**
```nix
services.prometheus.exporters.node = {
  enable = true;
  port = 9100;
  enabledCollectors = [
    "systemd"
    "cpu"
    "meminfo"
    "diskstats"
    "filesystem"
    "netdev"
  ];
};
```

**Ansible Deployment (Hetzner VPS):**
- Role: `ansible/roles/monitoring` (tasks/main.yaml:1-86)
- Variables: `ansible/roles/monitoring/defaults/main.yaml` (node_exporter_* variables)
- Systemd service: Managed automatically by role
- Installation path: `/usr/local/bin/node_exporter`

#### 2.3.2. Promtail (Log Shipper)

- **Version:** 2.9.3 (defined in `ansible/roles/monitoring/defaults/main.yaml`)
- **Purpose:** Tails log files and ships to Loki for aggregation
- **Port:** 9080 (HTTP metrics endpoint for Promtail itself)
- **Installation:** Same as node_exporter (NixOS modules for local, Ansible for VPS)
- **Architecture Support:** ARM64 and AMD64

**Log Sources (per system):**

| System | Log Paths | Format |
|--------|-----------|--------|
| **srv-01** | `/var/log/syslog`, `/var/log/auth.log` | syslog |
| **xbook** | `/var/log/system.log` | macOS unified logging |
| **xmsi** | `/var/log/syslog` | syslog |
| **mail-1** | `/var/log/mail.log`, `/var/log/syslog`, `/var/log/auth.log` | syslog |
| **syncthing-1** | systemd journal | journald |
| **test-1** | `/var/log/syslog`, `/var/log/auth.log`, `/var/log/kern.log` | syslog |

**Promtail Configuration (example for mail-1):**
```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: http://srv-01:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          host: mail-1
          environment: prod
          platform: debian
          __path__: /var/log/syslog

  - job_name: mail
    static_configs:
      - targets:
          - localhost
        labels:
          job: mail
          host: mail-1
          environment: prod
          __path__: /var/log/mail.log

  - job_name: auth
    static_configs:
      - targets:
          - localhost
        labels:
          job: auth
          host: mail-1
          environment: prod
          __path__: /var/log/auth.log
```

**CRITICAL Configuration Update Required:**
- Current default: `loki_url: "http://localhost:3100"` (ansible/roles/monitoring/defaults/main.yaml:22)
- **MUST update to:** `loki_url: "http://srv-01:3100"` (or srv-01's IP address)
- **Reason:** VPS Promtail must ship logs to srv-01, not localhost

**NixOS Configuration (srv-01, xmsi):**
```nix
services.promtail = {
  enable = true;
  configuration = {
    server = {
      http_listen_port = 9080;
      grpc_listen_port = 0;
    };
    positions.filename = "/var/lib/promtail/positions.yaml";
    clients = [{
      url = "http://localhost:3100/loki/api/v1/push";
    }];
    scrape_configs = [
      {
        job_name = "journal";
        journal = {
          max_age = "12h";
          labels = {
            job = "systemd-journal";
            host = config.networking.hostName;
          };
        };
        relabel_configs = [{
          source_labels = ["__journal__systemd_unit"];
          target_label = "unit";
        }];
      }
    ];
  };
};
```

**Ansible Deployment (Hetzner VPS):**
- Role: `ansible/roles/monitoring` (tasks/main.yaml:87-177)
- Variables: `ansible/roles/monitoring/defaults/main.yaml` (promtail_* variables)
- **Variable Override Required:** Set `loki_url: "http://srv-01:3100"` in inventory group_vars
- Installation path: `/usr/local/bin/promtail`

## 3. Data Flow Architecture

### 3.1. Metrics Collection Flow

```
node_exporter (all systems)
  ↓ (exports metrics on :9100)
Prometheus (srv-01)
  ↓ (scrapes every 15s via HTTP GET)
  ↓ (stores in /var/lib/prometheus)
  ↓ (evaluates alert rules)
Grafana (srv-01) ← Operator queries dashboards
  ↓
Alertmanager (srv-01) ← Prometheus sends alerts
  ↓ (routes based on severity)
Email / Matrix ← Notifications
```

**Network Paths:**
- **Local systems → Prometheus:** HTTP GET to `localhost:9100` or `hostname:9100`
- **Hetzner VPS → Prometheus:** HTTP GET to `10.0.0.10:9100`, `10.0.0.11:9100`, `10.0.0.20:9100` (private network)
- **Prometheus → Grafana:** HTTP queries to `http://localhost:9090/api/v1/query`
- **Prometheus → Alertmanager:** HTTP POST to `http://localhost:9093/api/v2/alerts`

### 3.2. Log Shipping Flow

```
Promtail (all systems)
  ↓ (tails log files: /var/log/*, systemd journal)
  ↓ (parses and labels logs)
Loki (srv-01)
  ↓ (receives logs via HTTP POST :3100)
  ↓ (stores in /var/lib/loki)
  ↓ (indexes for fast queries)
Grafana (srv-01) ← Operator queries logs
```

**Network Paths:**
- **Local systems → Loki:** HTTP POST to `http://srv-01:3100/loki/api/v1/push`
- **Hetzner VPS → Loki:** HTTP POST to `http://srv-01:3100/loki/api/v1/push` (requires srv-01 accessible from VPS)
- **Loki → Grafana:** HTTP queries to `http://localhost:3100/loki/api/v1/query`

**Network Connectivity Requirement:**
- **srv-01 must be accessible from Hetzner VPS private network (10.0.0.0/16)**
- Options:
  1. Connect srv-01 to Hetzner private network via VPN (WireGuard, Tailscale)
  2. Expose Loki port 3100 via public IP with authentication (not recommended)
  3. Use SSH tunnel from VPS to srv-01 (performance overhead)
  4. **Alternative:** Deploy Loki on dedicated Hetzner VPS instead of srv-01

### 3.3. Alert Routing Flow

```
Prometheus (srv-01)
  ↓ (evaluates alert rules every 15s)
  ↓ (alert triggers: ServiceDown, DiskFull, HighCPU, etc.)
Alertmanager (srv-01)
  ↓ (receives alert via HTTP POST)
  ↓ (groups, deduplicates, routes based on severity)
  ↓
  ├─→ Email (critical, warning)
  └─→ Matrix (future)
```

**Alert States:**
1. **Pending:** Alert condition met but not yet firing (wait time: 5 minutes for ServiceDown)
2. **Firing:** Alert actively sending notifications
3. **Resolved:** Alert condition no longer met (notification sent)

## 4. Dashboards Design

### 4.1. Infrastructure Overview Dashboard

**Purpose:** High-level status of all managed systems at a glance.

**Panels:**

1. **System Status Panel (Single Stat)**
   - **Query:** `up{job=~"srv-01|xbook|xmsi|mail-1|syncthing-1|test-1"}`
   - **Visualization:** Colored status indicators (green = up, red = down)
   - **Layout:** 6 single stat panels (one per system)

2. **Critical Alerts Count (Single Stat)**
   - **Query:** `ALERTS{alertstate="firing", severity="critical"}`
   - **Visualization:** Large number with red background if > 0

3. **Total Systems Monitored (Single Stat)**
   - **Query:** `count(up{job=~"srv-01|xbook|xmsi|mail-1|syncthing-1|test-1"})`
   - **Visualization:** Number with target count (6)

4. **System Uptime (Table)**
   - **Query:** `(time() - node_boot_time_seconds{job=~".*"})`
   - **Visualization:** Table with system name, uptime (human-readable)
   - **Columns:** System, Uptime, Last Boot Time

5. **Prometheus Health (Graph)**
   - **Query:** `prometheus_tsdb_storage_blocks_bytes`
   - **Visualization:** Storage usage over time

**Variables:** None (static overview)

**Refresh:** 30 seconds (auto-refresh)

### 4.2. System Metrics Dashboard

**Purpose:** Detailed system performance metrics per host.

**Panels:**

1. **CPU Usage (Graph)**
   - **Query:** `100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`
   - **Visualization:** Multi-line graph (one line per system)
   - **Y-axis:** Percentage (0-100%)
   - **Legend:** System name

2. **Memory Usage (Graph)**
   - **Query:** `(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100`
   - **Visualization:** Multi-line graph (one line per system)
   - **Y-axis:** Percentage (0-100%)

3. **Disk Usage (Graph)**
   - **Query:** `(node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_avail_bytes{mountpoint="/"}) / node_filesystem_size_bytes{mountpoint="/"} * 100`
   - **Visualization:** Multi-line graph (one line per system, per mountpoint)
   - **Y-axis:** Percentage (0-100%)
   - **Alert threshold:** 85% (horizontal line)

4. **Network Throughput (Graph)**
   - **Query:**
     - **Receive:** `irate(node_network_receive_bytes_total{device!~"lo|veth.*"}[5m])`
     - **Transmit:** `irate(node_network_transmit_bytes_total{device!~"lo|veth.*"}[5m])`
   - **Visualization:** Multi-line graph (receive and transmit per system)
   - **Y-axis:** Bytes/second

5. **Load Average (Graph)**
   - **Query:** `node_load1`, `node_load5`, `node_load15`
   - **Visualization:** Multi-line graph (1m, 5m, 15m load)

**Variables:**
- `$instance` (dropdown): Select specific system or "All"
  - Query: `label_values(up, instance)`
  - Multi-select: Yes

**Refresh:** 15 seconds (matches Prometheus scrape interval)

### 4.3. Deployment Metrics Dashboard (Placeholder)

**Purpose:** Track infrastructure deployment operations and success rates.

**Status:** **Future enhancement** - requires instrumentation of deployment scripts.

**Planned Panels:**

1. **NixOS Rebuild Duration (Graph)**
   - **Metric:** `nixos_rebuild_duration_seconds` (custom metric, not yet instrumented)
   - **Query:** `nixos_rebuild_duration_seconds{host=~"$instance"}`
   - **Visualization:** Bar graph per system

2. **Ansible Playbook Duration (Graph)**
   - **Metric:** `ansible_play_duration_seconds` (custom metric, not yet instrumented)
   - **Query:** `ansible_play_duration_seconds{playbook=~"$playbook"}`
   - **Visualization:** Histogram

3. **Terraform Apply Duration (Graph)**
   - **Metric:** `terraform_apply_duration_seconds` (custom metric, not yet instrumented)
   - **Query:** `terraform_apply_duration_seconds`

4. **Deployment Success Rate (Single Stat)**
   - **Metric:** `deployment_exit_code` (custom metric, not yet instrumented)
   - **Query:** `sum(deployment_exit_code == 0) / count(deployment_exit_code) * 100`
   - **Visualization:** Percentage gauge

**Variables:**
- `$playbook` (dropdown): Select Ansible playbook
- `$instance` (dropdown): Select system

**Instrumentation Requirements:**
- Add Prometheus Pushgateway for one-off deployment metrics
- Instrument `justfile` recipes to push metrics after deployments
- Export metrics: deployment type, host, duration, exit code, timestamp

## 5. Alert Rules

### 5.1. Alert Rule Definitions

All alert rules are defined in Prometheus configuration. Alert severity levels:
- **critical:** Immediate action required (service down, disk full)
- **warning:** Attention needed (high CPU, approaching disk full)
- **info:** Informational (deployment completed)

#### 5.1.1. ServiceDown (Critical)

**Purpose:** Detect when node_exporter on any system stops responding.

**PromQL:**
```yaml
- alert: ServiceDown
  expr: up == 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Service {{ $labels.job }} on {{ $labels.instance }} is down"
    description: "node_exporter has not responded to Prometheus scrapes for more than 5 minutes. System may be offline or node_exporter service crashed."
```

**Trigger Condition:** `up == 0` for >5 minutes
**Notification:** Email (critical) - immediate notification
**Action:** SSH to system, check node_exporter service status, investigate system availability

#### 5.1.2. DiskFull (Critical)

**Purpose:** Detect when disk usage exceeds 85% on any filesystem.

**PromQL:**
```yaml
- alert: DiskFull
  expr: |
    (node_filesystem_avail_bytes / node_filesystem_size_bytes * 100) < 15
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Disk {{ $labels.mountpoint }} on {{ $labels.instance }} is 85% full"
    description: "Filesystem {{ $labels.mountpoint }} has less than 15% available space ({{ $value }}% free). Immediate cleanup required."
```

**Trigger Condition:** Available space <15% (85% full) for >5 minutes
**Notification:** Email (critical)
**Action:** Investigate disk usage, clean up logs/cache, expand storage if needed

#### 5.1.3. HighCPU (Warning)

**Purpose:** Detect sustained high CPU usage that may impact performance.

**PromQL:**
```yaml
- alert: HighCPU
  expr: |
    100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "High CPU usage on {{ $labels.instance }}"
    description: "CPU usage has been above 90% for more than 10 minutes (current: {{ $value }}%). Investigate running processes."
```

**Trigger Condition:** CPU >90% for >10 minutes
**Notification:** Email (warning)
**Action:** SSH to system, run `top` or `htop`, identify resource-intensive processes

#### 5.1.4. DeploymentFailure (Warning)

**Purpose:** Detect when infrastructure deployments fail.

**Status:** **Future enhancement** - requires custom metric instrumentation.

**PromQL (Planned):**
```yaml
- alert: DeploymentFailure
  expr: |
    deployment_exit_code > 0
  for: 1m
  labels:
    severity: warning
  annotations:
    summary: "Deployment failed on {{ $labels.instance }}"
    description: "Recent {{ $labels.deployment_type }} deployment exited with code {{ $value }}. Check logs for details."
```

**Trigger Condition:** `deployment_exit_code > 0` (non-zero exit code)
**Notification:** Email (warning)
**Action:** Review deployment logs, re-run deployment with debug logging

### 5.2. Alert Routing Matrix

| Alert | Severity | Repeat Interval | Notification Channels | Escalation |
|-------|----------|-----------------|----------------------|------------|
| **ServiceDown** | critical | 1 hour | Email (immediate) | Manual escalation if unresolved >4 hours |
| **DiskFull** | critical | 1 hour | Email (immediate) | Auto-escalation if >95% full |
| **HighCPU** | warning | 4 hours | Email (batched) | Escalate to critical if >6 hours |
| **DeploymentFailure** | warning | 4 hours | Email (batched) | Manual review required |

### 5.3. Retention Policy

**Alert History:** 90 days (stored in Alertmanager)
**Alert Metrics:** 30 days (stored in Prometheus, same as other metrics)
**Silences:** 90 days (configurable in Alertmanager)

## 6. Retention Policies

### 6.1. Metrics Retention (Prometheus)

- **Duration:** 30 days
- **Configuration:** `--storage.tsdb.retention.time=30d`
- **Storage Size (estimated):**
  - 6 systems × ~1000 metrics/system × 15s scrape interval × 30 days ≈ 2GB
- **Cleanup:** Automatic (Prometheus TSDB compaction)

**Rationale:** 30 days provides sufficient history for troubleshooting and trend analysis without excessive storage costs.

### 6.2. Logs Retention (Loki)

**Hot Storage (30 days):**
- **Purpose:** Recent logs for fast queries and alerting
- **Storage:** `/var/lib/loki/chunks` (local disk)
- **Query Performance:** <1 second for typical queries

**Cold Storage (90 days):**
- **Purpose:** Archived logs for compliance and long-term analysis
- **Storage:** Same filesystem (future: S3-compatible object storage)
- **Query Performance:** 5-10 seconds for typical queries

**Total Retention:** 90 days
**Configuration:** `retention_period: 2160h` (90 days)

**Storage Size (estimated):**
- 6 systems × ~10KB/s logs × 90 days ≈ 50GB

**Cleanup:** Automatic (Loki compactor with `retention_enabled: true`)

### 6.3. Alert History Retention (Alertmanager)

- **Duration:** 90 days
- **Storage:** `/var/lib/alertmanager` (alert state, silences, notifications history)
- **Cleanup:** Manual (no automatic retention policy in Alertmanager <0.28)

**Future Enhancement:** Integrate with long-term storage (S3, PostgreSQL) for compliance.

## 7. Network Topology and Connectivity

### 7.1. Network Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Local Network                               │
│                                                                 │
│  ┌───────────┐       ┌───────────┐       ┌───────────────────┐ │
│  │  xbook    │       │   xmsi    │       │     srv-01        │ │
│  │  (Darwin) │       │  (NixOS)  │       │    (NixOS)        │ │
│  │           │       │           │       │                   │ │
│  │ node_exp  │       │ node_exp  │       │ node_exp          │ │
│  │ promtail  │       │ promtail  │       │ promtail          │ │
│  └─────┬─────┘       └─────┬─────┘       │                   │ │
│        │                   │             │ ┌───────────────┐ │ │
│        │                   │             │ │  Prometheus   │ │ │
│        │                   │             │ │  Grafana      │ │ │
│        │                   │             │ │  Loki         │ │ │
│        │                   │             │ │  Alertmanager │ │ │
│        └───────────────────┼─────────────┤ └───────────────┘ │ │
│                            │             └───────────────────┘ │
└────────────────────────────┼───────────────────────────────────┘
                             │
                             │ (VPN/SSH Tunnel)
                             │
┌────────────────────────────┼───────────────────────────────────┐
│            Hetzner Private Network (10.0.0.0/16)                │
│                            │                                    │
│  ┌─────────────────────┐   │   ┌─────────────────────────┐     │
│  │  mail-1.prod.nbg    │   │   │ syncthing-1.prod.hel    │     │
│  │  10.0.0.10          │───┼───│ 10.0.0.11               │     │
│  │  (Debian 12)        │   │   │ (Rocky Linux 9)         │     │
│  │                     │   │   │                         │     │
│  │  node_exporter:9100 │   │   │ node_exporter:9100      │     │
│  │  promtail:9080      │   │   │ promtail:9080           │     │
│  └─────────────────────┘   │   └─────────────────────────┘     │
│                            │                                    │
│  ┌─────────────────────┐   │                                    │
│  │  test-1.dev.nbg     │   │                                    │
│  │  10.0.0.20          │───┘                                    │
│  │  (Ubuntu 24.04)     │                                        │
│  │                     │                                        │
│  │  node_exporter:9100 │                                        │
│  │  promtail:9080      │                                        │
│  └─────────────────────┘                                        │
└─────────────────────────────────────────────────────────────────┘
```

### 7.2. Connectivity Requirements

**Local Systems → srv-01:**
- **Protocol:** HTTP (Prometheus scrape, Loki ingestion)
- **Network:** Local network (same subnet or reachable via hostname)
- **Firewall:** No firewall rules required (trusted local network)

**Hetzner VPS → srv-01:**
- **Protocol:** HTTP (Loki ingestion for Promtail logs)
- **Network:** **VPN or SSH tunnel required** (srv-01 not on Hetzner private network)
- **Options:**
  1. **WireGuard VPN:** Connect srv-01 to Hetzner private network (10.0.0.0/16)
  2. **Tailscale:** Zero-config mesh VPN (simplest option)
  3. **SSH Tunnel:** `ssh -L 3100:localhost:3100 srv-01` from each VPS (performance overhead)
  4. **Public Exposure:** Expose Loki port 3100 via public IP with authentication (NOT recommended)

**srv-01 → Hetzner VPS:**
- **Protocol:** HTTP (Prometheus scrape of node_exporter)
- **Network:** **VPN or SSH tunnel required** (same as above)
- **Firewall (VPS):** Allow incoming connections on port 9100 from srv-01 (configured by Ansible monitoring role)

**Operator → Grafana (srv-01):**
- **Protocol:** HTTPS (web UI)
- **Network:** Local network or VPN
- **Firewall (srv-01):** Restrict to operator workstation IP only

**Recommended Solution:** **Deploy Tailscale on all systems** for zero-config mesh VPN.
- NixOS: `services.tailscale.enable = true;`
- Debian/Rocky/Ubuntu: Install via Ansible (`apt install tailscale` / `yum install tailscale`)
- Benefits: Encrypted, NAT traversal, no manual firewall rules, works across local and cloud

## 8. Implementation Phases

### 8.1. Phase 1: Deploy Monitoring Stack on srv-01 (Task I7.T2)

**Objective:** Deploy Prometheus, Grafana, Loki, Alertmanager on srv-01 via NixOS modules.

**Prerequisites:**
1. Verify srv-01 is deployed and always-on (check with `just ansible-ping`)
2. Ensure srv-01 has sufficient disk space (minimum 100GB recommended for logs/metrics)
3. Configure SOPS secret for Grafana admin password

**Tasks:**
1. Create NixOS module `modules/nixos/monitoring.nix`:
   - Enable Prometheus with scrape configuration (Section 2.2.1)
   - Enable Grafana with Prometheus/Loki data sources (Section 2.2.2)
   - Enable Loki with retention policy (Section 2.2.3)
   - Enable Alertmanager with email routing (Section 2.2.4)
   - Enable node_exporter and Promtail on srv-01 (Section 2.3)
   - Configure firewall rules (Grafana port 3000 restricted to operator IP)

2. Import module in `hosts/srv-01/configuration.nix`:
   ```nix
   imports = [
     ./hardware-configuration.nix
     ../../modules/nixos/server.nix
     ../../modules/nixos/monitoring.nix  # Add this line
   ];
   ```

3. Add Grafana admin password to SOPS:
   ```bash
   sops secrets/monitoring.yaml
   # Add: grafana_admin_password: "<strong-password>"
   ```

4. Deploy to srv-01:
   ```bash
   sudo nixos-rebuild switch --flake .#srv-01
   ```

5. Verify services running:
   ```bash
   ssh srv-01
   systemctl status prometheus grafana loki alertmanager node_exporter promtail
   ```

6. Access Grafana web UI:
   - URL: `http://srv-01:3000`
   - Login: `admin` / `<password-from-sops>`
   - Verify Prometheus and Loki data sources connected

**Acceptance Criteria:**
- All monitoring stack services running on srv-01
- Grafana accessible from operator workstation
- Prometheus scraping srv-01 node_exporter successfully
- Loki receiving logs from srv-01 Promtail

**Estimated Duration:** 4-6 hours

### 8.2. Phase 2: Deploy Monitoring Agents to test-1.dev.nbg (Task I7.T3)

**Objective:** Deploy node_exporter and Promtail to test-1 via Ansible for validation.

**Prerequisites:**
1. Phase 1 completed (monitoring stack operational on srv-01)
2. Network connectivity established (VPN/SSH tunnel between srv-01 and test-1)
3. Ansible inventory updated with test-1 host

**Tasks:**
1. Configure Ansible inventory group variables:
   ```yaml
   # ansible/inventory/group_vars/dev.yaml
   loki_url: "http://srv-01:3100"  # Or Tailscale IP if using VPN
   ```

2. Deploy monitoring role to test-1:
   ```bash
   just ansible-deploy-env dev
   # Or directly:
   ansible-playbook ansible/playbooks/deploy.yaml --limit test-1.dev.nbg
   ```

3. Verify connectivity from test-1:
   ```bash
   ssh test-1.dev.nbg

   # Check node_exporter metrics
   curl http://localhost:9100/metrics | head

   # Check Promtail logs shipping
   journalctl -u promtail -f

   # Verify Loki reachable
   curl http://srv-01:3100/ready
   ```

4. Verify in Grafana:
   - Navigate to Explore → Loki
   - Query: `{host="test-1"}`
   - Verify logs appearing from test-1
   - Navigate to Explore → Prometheus
   - Query: `up{job="test-1"}`
   - Verify metric value = 1 (up)

5. Create test alert to validate alerting:
   - Stop node_exporter on test-1: `sudo systemctl stop node_exporter`
   - Wait 5 minutes
   - Verify ServiceDown alert fires in Alertmanager UI (`http://srv-01:9093`)
   - Verify email notification received
   - Restart node_exporter: `sudo systemctl start node_exporter`
   - Verify alert resolves

**Acceptance Criteria:**
- node_exporter and Promtail services running on test-1
- Prometheus successfully scraping test-1 metrics (via private IP 10.0.0.20)
- Loki receiving logs from test-1 Promtail
- ServiceDown alert fires and resolves correctly
- Email notification received for test alert

**Estimated Duration:** 2-3 hours

### 8.3. Phase 3: Deploy Monitoring Agents to Production VPS (Future)

**Objective:** Deploy monitoring agents to mail-1 and syncthing-1 after successful test-1 validation.

**Prerequisites:**
1. Phase 2 completed successfully (test-1 monitored for 1+ week without issues)
2. Production change window scheduled

**Tasks:**
1. Update Ansible inventory group variables:
   ```yaml
   # ansible/inventory/group_vars/prod.yaml
   loki_url: "http://srv-01:3100"
   ```

2. Deploy monitoring role to production:
   ```bash
   # Deploy to mail-1 first (canary)
   ansible-playbook ansible/playbooks/deploy.yaml --limit mail-1.prod.nbg --check
   ansible-playbook ansible/playbooks/deploy.yaml --limit mail-1.prod.nbg

   # Verify mail-1 for 24 hours, then deploy to syncthing-1
   ansible-playbook ansible/playbooks/deploy.yaml --limit syncthing-1.prod.hel --check
   ansible-playbook ansible/playbooks/deploy.yaml --limit syncthing-1.prod.hel
   ```

3. Update Grafana dashboards to include production systems
4. Configure production-specific alert rules (mail queue depth, Syncthing sync status)
5. Document monitoring runbook for on-call engineers

**Acceptance Criteria:**
- All production VPS monitored with no performance impact
- Production dashboards operational
- Production alerts configured and tested
- Monitoring runbook documented

**Estimated Duration:** 4 hours (spread over 1 week for staged rollout)

## 9. Security Considerations

### 9.1. Access Control

**Grafana Authentication:**
- **Initial:** Local admin account (admin / SOPS-encrypted password)
- **Future:** OAuth/SSO integration (GitHub, Google, or self-hosted)
- **Authorization:** Read-only viewers, admin editors

**Prometheus/Loki API:**
- **Access:** Localhost only (no authentication required for local access)
- **Public Exposure:** NEVER expose Prometheus/Loki directly to internet without authentication

**Alertmanager:**
- **Access:** Localhost only
- **Notifications:** Email credentials stored in SOPS

### 9.2. Network Security

**Firewall Rules (srv-01):**
- **Grafana (port 3000):** Allow from operator workstation IP only, deny all others
- **Prometheus (port 9090):** Allow from localhost only
- **Loki (port 3100):** Allow from localhost + VPN (Tailscale, WireGuard)
- **Alertmanager (port 9093):** Allow from localhost only

**Firewall Rules (Hetzner VPS):**
- **node_exporter (port 9100):** Allow from srv-01 IP (via private network), deny public
- **Promtail (port 9080):** Allow from localhost only (no external access required)

**VPN Security:**
- **Tailscale:** MagicDNS enabled, ACLs to restrict srv-01 access to VPS only
- **WireGuard:** Pre-shared keys, allowed IPs restricted to monitoring stack

### 9.3. Secrets Management

**Secrets in SOPS:**
- `secrets/monitoring.yaml`:
  - `grafana_admin_password`: Grafana admin account password
  - `alertmanager_email_password`: SMTP relay password (if required)
  - `tailscale_auth_key`: Tailscale pre-authenticated key (if using Tailscale)

**Deployment:**
- Secrets decrypted at build time (NixOS) or deployment time (Ansible)
- Never commit decrypted secrets to Git

## 10. Operational Procedures

### 10.1. Dashboard Access

**URL:** `http://srv-01:3000` (or Tailscale hostname: `http://srv-01.tail-xxxxx.ts.net:3000`)
**Login:** admin / `<password-from-sops>`

**Common Tasks:**
1. **View system status:** Navigate to "Infrastructure Overview" dashboard
2. **Investigate high CPU:** Navigate to "System Metrics" dashboard, select system from dropdown
3. **Search logs:** Navigate to Explore → Loki, use query `{host="mail-1"} |= "error"`
4. **View alerts:** Navigate to Alerting → Alert Rules

### 10.2. Alert Response Procedures

**ServiceDown Alert:**
1. Check Grafana dashboard for system status
2. SSH to affected system: `ssh <system>`
3. Check node_exporter service: `sudo systemctl status node_exporter`
4. If service crashed, check logs: `sudo journalctl -u node_exporter -n 100`
5. Restart service: `sudo systemctl restart node_exporter`
6. If system unreachable, check network connectivity, VPS console (Hetzner Cloud Console)

**DiskFull Alert:**
1. SSH to affected system
2. Check disk usage: `df -h`
3. Identify large files: `sudo du -sh /* | sort -h`
4. Clean up logs: `sudo journalctl --vacuum-time=7d`
5. Clean up package caches: `sudo apt clean` (Debian) or `sudo yum clean all` (Rocky)
6. If issue persists, expand disk or add volume

**HighCPU Alert:**
1. SSH to affected system
2. Check running processes: `top` or `htop`
3. Identify resource-intensive process
4. Investigate process legitimacy (application load vs. malware)
5. Optimize application or scale resources

### 10.3. Maintenance Windows

**Weekly Maintenance (Sunday 02:00 UTC):**
- Silence alerts in Alertmanager: Silences → Add Silence → Duration: 2 hours
- Apply system updates via Ansible: `just ansible-deploy`
- Verify monitoring stack health after updates

**Monthly Maintenance (First Sunday 02:00 UTC):**
- Review dashboard usage and optimize queries
- Archive old logs to cold storage (manual process until automated)
- Update Prometheus/Grafana/Loki versions via NixOS flake update

## 11. Future Enhancements

### 11.1. Short-term (1-3 months)

1. **Deployment Metrics Instrumentation (Iteration I8)**
   - Add Prometheus Pushgateway to monitoring stack
   - Instrument `justfile` recipes to push deployment metrics
   - Create "Deployment Metrics" dashboard (Section 4.3)

2. **Tailscale VPN Integration**
   - Deploy Tailscale on all systems for mesh VPN
   - Simplify network connectivity (no manual SSH tunnels)
   - Update Prometheus scrape configs to use Tailscale hostnames

3. **Additional Dashboards**
   - Mail server dashboard (mail queue depth, delivery times, spam scores)
   - Syncthing dashboard (sync status, conflict rate, bandwidth)
   - NixOS generations dashboard (track system state over time)

### 11.2. Medium-term (3-6 months)

1. **Centralized Logging Enhancements**
   - Add structured logging (JSON logs) for applications
   - Create log-based alerts (SSH brute-force, mail server errors)
   - Implement log sampling for high-volume services

2. **Application Performance Monitoring**
   - Deploy custom exporters for mail server (Postfix exporter)
   - Deploy custom exporters for Syncthing (Syncthing API exporter)
   - Create service-level dashboards

3. **High Availability (if scale increases)**
   - Deploy Prometheus in HA mode (2+ instances with remote storage)
   - Deploy Loki with replication
   - Use external Alertmanager cluster

### 11.3. Long-term (6-12 months)

1. **Observability Platform Migration**
   - Evaluate managed observability platforms (Grafana Cloud, Datadog, New Relic)
   - Cost-benefit analysis: self-hosted vs. managed
   - Migration plan if moving to managed platform

2. **Advanced Alerting**
   - Anomaly detection (machine learning-based alerts)
   - Predictive alerts (disk full in 7 days based on growth rate)
   - Alert fatigue reduction (smart grouping, auto-remediation)

3. **Compliance and Audit Logging**
   - Long-term log retention in S3-compatible storage (1+ year)
   - Audit log separation (security events, access logs)
   - Compliance reporting dashboards (for GDPR, SOC2, etc.)

## 12. References

### 12.1. Documentation

- **Prometheus Documentation:** https://prometheus.io/docs/
- **Grafana Documentation:** https://grafana.com/docs/grafana/latest/
- **Loki Documentation:** https://grafana.com/docs/loki/latest/
- **Alertmanager Documentation:** https://prometheus.io/docs/alerting/latest/alertmanager/
- **node_exporter GitHub:** https://github.com/prometheus/node_exporter
- **Promtail Documentation:** https://grafana.com/docs/loki/latest/send-data/promtail/

### 12.2. Codebase References

- **Ansible Monitoring Role:** `ansible/roles/monitoring/tasks/main.yaml`
- **Monitoring Role Defaults:** `ansible/roles/monitoring/defaults/main.yaml`
- **srv-01 Configuration:** `hosts/srv-01/configuration.nix`
- **Architecture Document:** `docs/05_Operational_Architecture.md` (Section 3.8.2)
- **Evolution Plan:** `docs/06_Rationale_and_Future.md` (Section 5.1.1)

### 12.3. External Tools

- **Tailscale:** https://tailscale.com/ (mesh VPN for simplified connectivity)
- **Prometheus Pushgateway:** https://github.com/prometheus/pushgateway (for batch job metrics)
- **PlantUML:** https://plantuml.com/ (for architecture diagrams)

## 13. Appendix

### 13.1. Glossary

- **node_exporter:** Prometheus exporter for hardware and OS metrics (CPU, memory, disk, network)
- **Promtail:** Log shipping agent that tails log files and sends to Loki
- **Scrape:** Prometheus operation of pulling metrics from exporters via HTTP GET
- **PromQL:** Prometheus Query Language for querying time-series metrics
- **LogQL:** Loki Query Language for querying logs (similar to PromQL)
- **TSDB:** Time-Series Database (Prometheus storage backend)
- **Retention:** Duration to keep metrics/logs before automatic deletion
- **Compaction:** Process of merging and optimizing time-series data blocks

### 13.2. Prometheus Scrape Configuration Template

**Full YAML configuration for copy-paste into NixOS module:**

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - localhost:9093

rule_files:
  - /etc/prometheus/alerts.yml

scrape_configs:
  - job_name: 'srv-01'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          environment: 'local'
          platform: 'nixos'
          arch: 'x86_64'

  - job_name: 'xbook'
    static_configs:
      - targets: ['xbook:9100']
        labels:
          environment: 'local'
          platform: 'darwin'
          arch: 'arm64'

  - job_name: 'xmsi'
    static_configs:
      - targets: ['xmsi:9100']
        labels:
          environment: 'local'
          platform: 'nixos'
          arch: 'x86_64'

  - job_name: 'mail-1'
    static_configs:
      - targets: ['10.0.0.10:9100']
        labels:
          environment: 'prod'
          platform: 'debian'
          arch: 'arm64'
          datacenter: 'nbg1'

  - job_name: 'syncthing-1'
    static_configs:
      - targets: ['10.0.0.11:9100']
        labels:
          environment: 'prod'
          platform: 'rocky'
          arch: 'arm64'
          datacenter: 'hel1'

  - job_name: 'test-1'
    static_configs:
      - targets: ['10.0.0.20:9100']
        labels:
          environment: 'dev'
          platform: 'ubuntu'
          arch: 'arm64'
          datacenter: 'nbg1'
```

### 13.3. Prometheus Alert Rules Template

**Full YAML configuration for `/etc/prometheus/alerts.yml`:**

```yaml
groups:
  - name: infrastructure_alerts
    interval: 15s
    rules:
      - alert: ServiceDown
        expr: up == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} on {{ $labels.instance }} is down"
          description: "node_exporter has not responded to Prometheus scrapes for more than 5 minutes."

      - alert: DiskFull
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes * 100) < 15
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Disk {{ $labels.mountpoint }} on {{ $labels.instance }} is 85% full"
          description: "Filesystem {{ $labels.mountpoint }} has less than 15% available space."

      - alert: HighCPU
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage has been above 90% for more than 10 minutes."
```

---

**Document Status:** Ready for implementation (Phase 1: Task I7.T2)
**Next Steps:** Deploy monitoring stack on srv-01, validate connectivity, proceed to Phase 2
