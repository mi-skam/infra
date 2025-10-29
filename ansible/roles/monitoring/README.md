# Ansible Role: monitoring

Deploy and configure Prometheus node_exporter and Promtail monitoring agents for comprehensive system observability.

## Description

This role installs and configures two essential monitoring components:

- **node_exporter**: Prometheus agent that exposes hardware and OS metrics (CPU, memory, disk, network)
- **Promtail**: Log shipping agent that forwards system logs to Grafana Loki

The role handles binary downloads, user/group creation, systemd service setup, firewall configuration, and ensures services are running and enabled.

## Requirements

- Ansible 2.12 or higher
- Supported platforms: Debian 11+, Ubuntu 20.04+, RHEL/Rocky 8+
- systemd-based system
- Internet connectivity for downloading binaries from GitHub releases
- Firewall management: firewalld (RHEL) or ufw (Debian/Ubuntu)

## Role Variables

### node_exporter Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `node_exporter_version` | `"1.8.2"` | Version of node_exporter to install |
| `node_exporter_port` | `9100` | Port for metrics endpoint |
| `node_exporter_user` | `node-exporter` | System user for service |
| `node_exporter_group` | `node-exporter` | System group for service |
| `node_exporter_install_dir` | `/usr/local/bin` | Installation directory for binary |
| `node_exporter_additional_args` | `""` | Additional command-line arguments |

### Promtail Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `promtail_version` | `"2.9.3"` | Version of Promtail to install |
| `promtail_port` | `9080` | Port for Promtail HTTP server |
| `promtail_user` | `promtail` | System user for service |
| `promtail_group` | `promtail` | System group for service |
| `promtail_install_dir` | `/usr/local/bin` | Installation directory for binary |
| `promtail_config_dir` | `/etc/promtail` | Configuration directory |
| `promtail_data_dir` | `/var/lib/promtail` | Data directory for positions file |

### Loki Server Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `loki_url` | `"http://localhost:3100"` | Loki server endpoint URL |

### Log Collection

| Variable | Default | Description |
|----------|---------|-------------|
| `promtail_log_paths` | See below | List of log file paths to monitor |

Default log paths:
```yaml
promtail_log_paths:
  - /var/log/syslog
  - /var/log/auth.log
  - /var/log/kern.log
```

### Firewall Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `monitoring_enable_firewall` | `true` | Enable firewall configuration |
| `monitoring_firewall_zones` | `["public"]` | Firewall zones (firewalld only) |

## Dependencies

- `common` role (provides base system configuration)

## Example Playbook

### Basic Usage

```yaml
- hosts: monitoring_servers
  roles:
    - role: monitoring
```

### Custom Configuration

```yaml
- hosts: monitoring_servers
  roles:
    - role: monitoring
      vars:
        loki_url: "http://loki.example.com:3100"
        promtail_log_paths:
          - /var/log/syslog
          - /var/log/auth.log
          - /var/log/nginx/access.log
          - /var/log/nginx/error.log
        node_exporter_additional_args: "--collector.systemd"
```

### Production Setup

```yaml
- hosts: prod_servers
  roles:
    - role: common
    - role: monitoring
      vars:
        loki_url: "https://loki.prod.example.com:3100"
        monitoring_enable_firewall: true
        node_exporter_port: 9100
        promtail_log_paths:
          - /var/log/syslog
          - /var/log/auth.log
          - /var/log/application/*.log
```

## Idempotency

This role is fully idempotent. Running it multiple times will not change the system state after the initial deployment, unless configuration variables are modified.

**Testing idempotency:**
```bash
# First run - should make changes
ansible-playbook playbooks/deploy.yaml --limit test-server

# Second run - should show changed=0
ansible-playbook playbooks/deploy.yaml --limit test-server
```

## Tags

The following tags are available for selective execution:

- `monitoring` - All monitoring tasks
- `install` - Installation tasks only
- `configure` - Configuration tasks only
- `node_exporter` - Only node_exporter tasks
- `promtail` - Only Promtail tasks
- `firewall` - Firewall configuration only
- `cleanup` - Cleanup temporary files

**Examples:**
```bash
# Install only node_exporter
ansible-playbook playbooks/deploy.yaml --tags "node_exporter"

# Configure Promtail only
ansible-playbook playbooks/deploy.yaml --tags "promtail,configure"

# Skip firewall configuration
ansible-playbook playbooks/deploy.yaml --skip-tags "firewall"
```

## Architecture Detection

The role automatically detects system architecture and downloads the appropriate binary:
- ARM64 (`aarch64`) - Downloads `arm64` binaries
- x86_64 (`x86_64`) - Downloads `amd64` binaries

## Service Management

Both services are managed via systemd:

```bash
# Check service status
systemctl status node_exporter
systemctl status promtail

# View logs
journalctl -u node_exporter -f
journalctl -u promtail -f

# Restart services
systemctl restart node_exporter
systemctl restart promtail
```

## Verification

After deployment, verify the services are running:

```bash
# Check node_exporter metrics
curl http://localhost:9100/metrics

# Check Promtail is running
systemctl is-active promtail

# Verify Promtail configuration
promtail -config.file=/etc/promtail/promtail.yaml -check-syntax
```

## Firewall Configuration

The role automatically opens port 9100 for node_exporter metrics collection:

- **firewalld** (RHEL/Rocky): Opens port in specified zones
- **ufw** (Debian/Ubuntu): Adds allow rule for port 9100

Promtail port (9080) is not exposed externally as it only needs to communicate outbound to Loki.

## Security Considerations

- Both services run as unprivileged system users
- Binaries are downloaded from official GitHub releases (verify checksums in production)
- node_exporter exposes system metrics on port 9100 - restrict access via firewall
- Promtail reads system logs - ensure proper file permissions
- Consider TLS encryption for Loki communication in production

## Troubleshooting

### node_exporter not starting
```bash
# Check service status
systemctl status node_exporter

# View detailed logs
journalctl -u node_exporter -xe

# Verify binary exists and is executable
ls -l /usr/local/bin/node_exporter
```

### Promtail not shipping logs
```bash
# Check Promtail configuration
promtail -config.file=/etc/promtail/promtail.yaml -check-syntax

# Verify Loki connectivity
curl {{ loki_url }}/ready

# Check positions file
cat /var/lib/promtail/positions.yaml
```

### Firewall blocking metrics
```bash
# Check firewall rules (firewalld)
firewall-cmd --list-all

# Check firewall rules (ufw)
ufw status

# Test local connectivity
curl http://localhost:9100/metrics
```

## Integration with Monitoring Stack

This role prepares servers for monitoring by Prometheus and log aggregation by Loki. Complete monitoring stack requires:

1. **This role** - Deploy agents (node_exporter, Promtail)
2. **Prometheus** - Scrape metrics from node_exporter endpoints
3. **Loki** - Receive logs from Promtail agents
4. **Grafana** - Visualize metrics and logs

Update `loki_url` to point to your Loki instance, and configure Prometheus to scrape `http://<server>:9100/metrics`.

## License

MIT

## Author Information

This role was created by mi-skam as part of the homelab infrastructure project.

For issues or contributions, please visit the project repository.
