# SigNoz Automation Scripts

Automation scripts for SigNoz backup, restore, and configuration.

## Overview

These scripts provide:

1. **Automated Backup** - Backup SigNoz database (dashboards, alerts, settings)
2. **Fast Restore** - Restore from backup when server fails
3. **Configuration Management** - Version control dashboards and alerts in Git

## Files

```
scripts/
├── signoz-automation.sh    # Main automation script
├── signoz-backup.sh        # Backup script
└── signoz-restore.sh       # Restore script

signoz-backup/
├── dashboards/
│   └── infrastructure-overview.json
├── alerts/
│   └── infrastructure-alerts.json
└── manifest.json           # Backup metadata
```

## Quick Start

### Check Status
```bash
./scripts/signoz-automation.sh status
```

### Initialize with Default Dashboards
```bash
./scripts/signoz-automation.sh init
```

### Create Backup
```bash
./scripts/signoz-automation.sh backup
```

### Restore from Backup
```bash
./scripts/signoz-automation.sh restore
```

## How It Works

### Backup Process
1. Stops SigNoz container for consistent backup
2. Copies SQLite database files (including WAL)
3. Creates timestamped backup file
4. Saves manifest with version info
5. Restarts SigNoz

### Restore Process
1. Stops SigNoz container
2. Copies backup database to container
3. Restarts SigNoz
4. Verifies SigNoz is running

### Database Location
- Container: `/var/lib/signoz/signoz.db`
- Backup: `./signoz-backup/signoz-backup-YYYYMMDD_HHMMSS.db`

## SigNoz Architecture Notes

### Why Manual Import?

SigNoz uses a React frontend with backend authentication. All API endpoints require:
1. Login session, or
2. API key (not available in open-source version)

The SQLite database stores:
- Dashboard definitions
- Alert rules
- User sessions
- Settings

### Alternative Approaches

#### Option 1: Database Backup/Restore (Recommended)
- Backup entire SQLite database
- Restore database when server fails
- Preserves all dashboards, alerts, and settings

#### Option 2: JSON Definitions (Manual)
- Store dashboard definitions in JSON
- Manually import via SigNoz UI
- Use for initial setup only

#### Option 3: API Authentication (Future)
If SigNoz adds API key support:
```bash
# Get API token from SigNoz settings
export SIGNOZ_API_TOKEN="your-token"

# Import dashboard via API
curl -X POST "http://localhost:3301/api/v1/dashboards" \
  -H "Authorization: Bearer $SIGNOZ_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d @dashboards/infrastructure-overview.json
```

## Predefined Dashboards

### Infrastructure Overview

File: `signoz-backup/dashboards/infrastructure-overview.json`

Panels:
1. Host CPU Usage - `rate(process.cpu.time[5m])`
2. Host Memory Usage - `process.memory.usage`
3. Container CPU Usage - `rate(container_cpu_usage_seconds_total[5m])`
4. Container Memory Usage - `container_memory_usage_total`
5. Network I/O - `rate(container_network_io_usage_rx_bytes[5m])`

## Predefined Alerts

### Infrastructure Alerts

File: `signoz-backup/alerts/infrastructure-alerts.json`

Alerts:
- HighCPUUsage - CPU > 80% for 5m
- HighMemoryUsage - Memory > 10GB
- ContainerHighCPU - Container CPU > 70% for 5m
- ContainerHighMemory - Container memory > 1GB for 5m
- ContainerDown - No metrics for 2m

## Disaster Recovery

### Full Backup
```bash
# On production server
./scripts/signoz-automation.sh backup

# Copy backup to safe location
scp -r ./signoz-backup user@backup-server:/backups/signoz/
```

### Full Restore
```bash
# On new server
git clone <repo>
cd <repo>

# Copy backup
scp -r user@backup-server:/backups/signoz/* ./signoz-backup/

# Restore
./scripts/signoz-automation.sh restore
```

## Cron Job for Automatic Backups

```bash
# Add to crontab
# Backup every 6 hours
0 */6 * * * /home/user/nexus-devops/scripts/signoz-automation.sh backup >> /var/log/signoz-backup.log 2>&1
```

## Troubleshooting

### SigNoz won't start after restore
```bash
# Check logs
sudo docker logs signoz

# Revert to previous database
sudo docker cp /path/to/previous/signoz.db signoz:/var/lib/signoz/signoz.db
sudo docker restart signoz
```

### No metrics after restore
```bash
# Check OpenTelemetry Collector
sudo docker logs otel-collector

# Check ClickHouse
sudo docker exec signoz-clickhouse clickhouse-client -q "SELECT count(*) FROM signoz_metrics.time_series_v4"
```

### Database locked
```bash
# Stop all containers using the database
sudo docker stop signoz signoz-otel-collector

# Check for locked files
sudo rm -f /tmp/signoz.db-*

# Start containers
sudo docker start signoz-otel-collector signoz
```

## Related Files

- `docs/signoz-poc-report.md` - POC documentation
- `monitoring/otel-collector-config.yaml` - OpenTelemetry configuration
- `monitoring/docker-compose.metrics.yaml` - Metrics stack deployment