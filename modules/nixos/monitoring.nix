{ config, lib, pkgs, ... }:

{
  # SOPS secrets for monitoring
  sops.secrets = {
    "monitoring/grafana_admin_password" = {
      sopsFile = ../../secrets/monitoring.yaml;
      owner = "grafana";
      group = "grafana";
    };
    "monitoring/alertmanager_email_to" = {
      sopsFile = ../../secrets/monitoring.yaml;
    };
    "monitoring/alertmanager_smtp_host" = {
      sopsFile = ../../secrets/monitoring.yaml;
    };
    "monitoring/alertmanager_smtp_from" = {
      sopsFile = ../../secrets/monitoring.yaml;
    };
  };

  # Prometheus - Metrics Database
  services.prometheus = {
    enable = true;
    port = 9090;
    retentionTime = "30d";

    # Alert rules
    ruleFiles = [
      (pkgs.writeText "prometheus-alerts.yml" ''
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
      '')
    ];

    # Scrape configurations for all 6 systems
    scrapeConfigs = [
      # Local systems
      {
        job_name = "srv-01";
        static_configs = [{
          targets = [ "localhost:9100" ];
          labels = {
            environment = "local";
            platform = "nixos";
            arch = "x86_64";
          };
        }];
      }
      {
        job_name = "xbook";
        static_configs = [{
          targets = [ "xbook:9100" ];
          labels = {
            environment = "local";
            platform = "darwin";
            arch = "arm64";
          };
        }];
      }
      {
        job_name = "xmsi";
        static_configs = [{
          targets = [ "xmsi:9100" ];
          labels = {
            environment = "local";
            platform = "nixos";
            arch = "x86_64";
          };
        }];
      }

      # Hetzner Cloud VPS (private network)
      {
        job_name = "mail-1";
        static_configs = [{
          targets = [ "10.0.0.10:9100" ];
          labels = {
            environment = "prod";
            platform = "debian";
            arch = "arm64";
            datacenter = "nbg1";
          };
        }];
      }
      {
        job_name = "syncthing-1";
        static_configs = [{
          targets = [ "10.0.0.11:9100" ];
          labels = {
            environment = "prod";
            platform = "rocky";
            arch = "arm64";
            datacenter = "hel1";
          };
        }];
      }
      {
        job_name = "test-1";
        static_configs = [{
          targets = [ "10.0.0.20:9100" ];
          labels = {
            environment = "dev";
            platform = "ubuntu";
            arch = "arm64";
            datacenter = "nbg1";
          };
        }];
      }
    ];

    # Alertmanager configuration
    alertmanager = {
      enable = true;
      port = 9093;
      checkConfig = false;  # External credentials won't be visible to amtool validation

      # Environment file for secret injection via envsubst
      environmentFile = pkgs.writeText "alertmanager-env" ''
        ALERT_EMAIL_TO=$(cat ${config.sops.secrets."monitoring/alertmanager_email_to".path})
        ALERT_SMTP_HOST=$(cat ${config.sops.secrets."monitoring/alertmanager_smtp_host".path})
        ALERT_SMTP_FROM=$(cat ${config.sops.secrets."monitoring/alertmanager_smtp_from".path})
      '';

      configuration = {
        global = {
          smtp_smarthost = "$ALERT_SMTP_HOST";
          smtp_from = "$ALERT_SMTP_FROM";
        };
        route = {
          receiver = "default-email";
          group_by = [ "alertname" "environment" "instance" ];
          group_wait = "30s";
          group_interval = "5m";
          repeat_interval = "4h";
          routes = [
            {
              match = {
                severity = "critical";
              };
              receiver = "critical-email";
              repeat_interval = "1h";
            }
            {
              match = {
                severity = "warning";
              };
              receiver = "warning-email";
              repeat_interval = "4h";
            }
          ];
        };
        receivers = [
          {
            name = "default-email";
            email_configs = [{
              to = "$ALERT_EMAIL_TO";
              headers = {
                Subject = "[INFRA] {{ .GroupLabels.alertname }} - {{ .GroupLabels.environment }}";
              };
            }];
          }
          {
            name = "critical-email";
            email_configs = [{
              to = "$ALERT_EMAIL_TO";
              headers = {
                Subject = "[CRITICAL] {{ .GroupLabels.alertname }} - {{ .GroupLabels.environment }}";
              };
            }];
          }
          {
            name = "warning-email";
            email_configs = [{
              to = "$ALERT_EMAIL_TO";
              headers = {
                Subject = "[WARNING] {{ .GroupLabels.alertname }} - {{ .GroupLabels.environment }}";
              };
            }];
          }
        ];
      };
    };

    # Node exporter for srv-01 self-monitoring
    exporters.node = {
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
  };

  # Grafana - Visualization Platform
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
        admin_password = "$__file{${config.sops.secrets."monitoring/grafana_admin_password".path}}";
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

  # Loki - Log Aggregation
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
          final_sleep = "0s";
        };
        chunk_idle_period = "1h";
        max_chunk_age = "1h";
        chunk_target_size = 999999;
        chunk_retain_period = "30s";
      };

      schema_config = {
        configs = [{
          from = "2024-01-01";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }];
      };

      storage_config = {
        tsdb_shipper = {
          active_index_directory = "/var/lib/loki/tsdb-shipper-active";
          cache_location = "/var/lib/loki/tsdb-shipper-cache";
          cache_ttl = "24h";
        };
        filesystem.directory = "/var/lib/loki/chunks";
      };

      limits_config = {
        retention_period = "2160h";  # 90 days
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
      };

      compactor = {
        working_directory = "/var/lib/loki/compactor";
        compaction_interval = "10m";
        retention_enabled = true;
        retention_delete_delay = "2h";
        delete_request_store = "filesystem";
      };

      table_manager = {
        retention_deletes_enabled = true;
        retention_period = "2160h";
      };
    };
  };

  # Promtail - Log Shipper for srv-01
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
            source_labels = [ "__journal__systemd_unit" ];
            target_label = "unit";
          }];
        }
      ];
    };
  };

  # Firewall configuration - Allow Grafana access from operator workstation
  networking.firewall = {
    allowedTCPPorts = [
      3000  # Grafana
      9090  # Prometheus (for debugging)
    ];
  };
}
