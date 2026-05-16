# SigNoz Monitoring Setup

## Overview

This directory contains configuration and documentation for SigNoz monitoring on `ocl-worker-devops-002-stg`.

## Infrastructure

| Component | Port | Description |
|-----------|------|-------------|
| SigNoz UI | 3301 | Web dashboard |
| OTLP gRPC | 4317 | Metrics/logs receiver |
| OTLP HTTP | 4318 | Metrics/logs receiver |

## Services

| Service | Type | Port | Status |
|---------|------|------|--------|
| signoz | Docker | 3301 | UI |
| signoz-otel-collector | Docker | 4317/4318 | OTLP receiver |
| signoz-clickhouse | Docker | 9000 | Storage |
| signoz-zookeeper | Docker | 2181 | Coordination |
| otelcol-contrib | Systemd | - | Metrics collector |

## Metrics Collected

### Host Metrics (via hostmetrics receiver)
- CPU: `system_cpu_time`, `system_cpu_utilization`
- Memory: `system_memory_usage`
- Disk: `system_filesystem_usage`, `system_disk_io`
- Network: `system_network_io`, `system_network_packets`
- Load: `system_load_average`

### Docker Container Metrics (via docker_stats receiver)
- CPU: `container_cpu_utilization`
- Memory: `container_memory_percent`, `container_memory_usage_total`
- Network: `container_network_io_usage_rx_bytes`, `container_network_io_usage_tx_bytes`

## Configuration Files

- `/etc/otelcol-contrib/config.yaml` - OpenTelemetry Collector config
- `/opt/signoz/deploy/docker/docker-compose.yaml` - SigNoz Docker config

## Dashboard Import

1. Open SigNoz UI: `http://34.101.152.17:3301`
2. Go to Dashboards → Import
3. Upload `infrastructure-dashboard.json`

## Alerts Setup

1. Go to Alerts → New Alert
2. Create alerts from `alerts.json` definitions

## Commands Reference

```bash
# Check SigNoz status
docker ps | grep signoz

# Check OpenTelemetry Collector status
systemctl status otelcol-contrib

# View collector logs
journalctl -u otelcol-contrib -f

# Query metrics in ClickHouse
docker exec signoz-clickhouse clickhouse-client -q "
  SELECT metric_name, count() 
  FROM signoz_metrics.time_series_v4 
  GROUP BY metric_name 
  ORDER BY count() DESC 
  LIMIT 10"

# Restart services
systemctl restart otelcol-contrib
docker restart signoz
```

## Troubleshooting

### Collector not starting
```bash
# Check for errors
journalctl -u otelcol-contrib -n 50

# Verify Docker API version (must be >= 1.40)
docker version --format '{{.Server.APIVersion}}'
```

### No metrics appearing
```bash
# Check collector is running
systemctl status otelcol-contrib

# Check SigNoz OTLP receiver is accessible
curl http://localhost:4317/v1/metrics
```

### High memory usage
```bash
# Check container resources
docker stats --no-stream

# Restart SigNoz if needed
cd /opt/signoz/deploy/docker
docker compose restart
```

---

**Created:** 2026-05-16
**VM:** ocl-worker-devops-002-stg (34.101.152.17)
**Owner:** Om Awan (@BroAwn)