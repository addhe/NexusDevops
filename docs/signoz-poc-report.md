# Laporan POC SigNoz Infrastructure Monitoring

**Tanggal:** 2026-05-17
**Lokasi:** GCP asia-southeast2-a
**VM:** ocl-worker-devops-002-stg (34.101.152.17)
**Disiapkan oleh:** NexusChiefCommander

---

## 1. Ringkasan Eksekutif

POC SigNoz berhasil di-deploy di VM `ocl-worker-devops-002-stg` untuk monitoring infrastructure bot NexusDevOpsBot dan NexusByteBot. Sistem monitoring sudah aktif dan mengumpulkan metrics dari host dan container Docker.

**Status:** ✅ **BERHASIL**

---

## 2. Arsitektur Deployment

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ocl-worker-devops-002-stg                        │
│                      (34.101.152.17)                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐  │
│  │   OpenTelemetry  │    │    cAdvisor     │    │     SigNoz      │  │
│  │    Collector     │    │   (container    │    │    (Frontend)   │  │
│  │   (hostmetrics)  │    │    metrics)     │    │   Port: 3301    │  │
│  └────────┬────────┘    └────────┬────────┘    └────────┬────────┘  │
│           │                      │                       │           │
│           └──────────────────────┼───────────────────────┘           │
│                                  ▼                                   │
│                     ┌───────────────────────┐                        │
│                     │  SigNoz OTel Collector │                       │
│                     │     Port: 4317/4318    │                       │
│                     └───────────┬───────────┘                        │
│                                 ▼                                    │
│                     ┌───────────────────────┐                        │
│                     │     ClickHouse DB     │                        │
│                     │   (Metrics Storage)   │                        │
│                     └───────────────────────┘                        │
│                                                                      │
│  ┌─────────────────┐    ┌─────────────────┐                         │
│  │ NexusDevOpsBot  │    │  NexusByteBot   │                         │
│  │   (OpenClaw)    │    │   (OpenClaw)    │                         │
│  └─────────────────┘    └─────────────────┘                         │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. Komponen yang Di-deploy

### 3.1 SigNoz Stack (Docker)
| Komponen | Container Name | Port | Status |
|----------|---------------|------|--------|
| SigNoz Frontend | signoz | 3301:8080 | ✅ Running |
| SigNoz OTel Collector | signoz-otel-collector | 4317, 4318 | ✅ Running |
| ClickHouse | signoz-clickhouse | 9000, 8123 | ✅ Running |
| Zookeeper | signoz-zookeeper-1 | 2181 | ✅ Running |

### 3.2 Metrics Collection Stack
| Komponen | Container Name | Port | Status |
|----------|---------------|------|--------|
| OpenTelemetry Collector | otel-collector | 8889 | ✅ Running |
| cAdvisor | cadvisor | 8081:8080 | ✅ Running |

---

## 4. Metrics yang Di-collect

### 4.1 Host Metrics
| Metric | Deskripsi | Status |
|--------|-----------|--------|
| `process.cpu.time` | CPU time per process | ✅ Active |
| `process.memory.usage` | Memory usage per process | ✅ Active |
| `process.memory.virtual` | Virtual memory per process | ✅ Active |

### 4.2 Container Metrics (dari cAdvisor)
| Metric | Deskripsi | Status |
|--------|-----------|--------|
| `container_cpu_usage_seconds_total` | Container CPU usage | ✅ Active |
| `container_memory_usage_total` | Container memory usage | ✅ Active |
| `container_network_io_usage_rx_bytes` | Network RX bytes | ✅ Active |
| `container_network_io_usage_tx_bytes` | Network TX bytes | ✅ Active |
| `container_fs_io_time_seconds_total` | Disk I/O time | ✅ Active |

---

## 5. Akses SigNoz

### 5.1 Web UI
- **URL:** http://34.101.152.17:3301
- **Username:** addhe.warman@gmail.com
- **Password:** wWsR3bNV@PvZ4*9D8ezu

### 5.2 OTLP Endpoint (untuk aplikasi)
- **Endpoint:** http://34.101.152.17:4317 (gRPC)
- **Endpoint:** http://34.101.152.17:4318 (HTTP)

---

## 6. Cara Menggunakan

### 6.1 Login ke Dashboard
1. Buka http://34.101.152.17:3301
2. Login dengan credentials di atas
3. Klik **Dashboards** di sidebar

### 6.2 Membuat Dashboard Custom
1. Klik **New Dashboard**
2. Klik **Add Panel**
3. Pilih **Time Series**
4. Masukkan query PromQL:

**Contoh Query:**

```promql
# Host CPU Usage
rate(process.cpu.time{host_name!=""}[5m])

# Host Memory Usage
process.memory.usage{host_name!=""}

# Container CPU Usage
rate(container_cpu_usage_seconds_total{container_name!=""}[5m])

# Container Memory Usage
container_memory_usage_total{container_name!=""}

# Network I/O
rate(container_network_io_usage_rx_bytes{container_name!=""}[5m])
rate(container_network_io_usage_tx_bytes{container_name!=""}[5m])
```

### 6.3 Melihat Metrics di ClickHouse
```bash
# SSH ke VM
gcloud compute ssh ocl-worker-devops-002-stg --zone=asia-southeast2-a --project=ai-core-system-bot-stg

# Query metrics
sudo docker exec signoz-clickhouse clickhouse-client -q "
SELECT DISTINCT metric_name 
FROM signoz_metrics.time_series_v4 
LIMIT 20
"
```

---

## 7. Konfigurasi Files

### 7.1 Lokasi File di VM
```
~/monitoring/
├── docker-compose.metrics.yaml    # Docker Compose untuk metrics collection
├── otel-collector-config.yaml     # OpenTelemetry Collector config
├── infrastructure-dashboard.json  # Dashboard definition
└── alerts.json                    # Alert rules
```

### 7.2 Lokasi File di Git Repository
```
nexus-devops/monitoring/
├── README.md                      # Dokumentasi setup
├── docker-compose.metrics.yaml    # Docker Compose untuk metrics collection
├── otel-collector-config.yaml     # OpenTelemetry Collector config
├── infrastructure-dashboard.json  # Dashboard definition
├── dashboard-import.json          # Dashboard import format
└── alerts.json                    # Alert rules
```

---

## 8. Maintenance

### 8.1 Restart Metrics Collection Stack
```bash
cd ~/monitoring
sudo docker compose -f docker-compose.metrics.yaml restart
```

### 8.2 Restart SigNoz Stack
```bash
cd ~/signoz
sudo docker compose -f docker-compose.yaml restart
```

### 8.3 View Logs
```bash
# OpenTelemetry Collector logs
sudo docker logs otel-collector -f

# cAdvisor logs
sudo docker logs cadvisor -f

# SigNoz logs
sudo docker logs signoz -f
```

### 8.4 Check Container Status
```bash
sudo docker ps | grep -E 'otel|cadvisor|signoz'
```

---

## 9. Alert Configuration

### 9.1 Alert Rules yang Dikonfigurasi
| Alert Name | Condition | Severity |
|------------|-----------|----------|
| High CPU Usage | CPU > 80% for 5m | Warning |
| High Memory Usage | Memory > 10GB | Critical |
| Disk I/O High | I/O time > 0.1 | Warning |
| Container High CPU | Container CPU > 70% for 5m | Warning |
| Container High Memory | Container Memory > 1GB for 5m | Warning |

### 9.2 Cara Setup Alert di SigNoz
1. Go to **Alerts** → **New Alert**
2. Define alert name dan condition
3. Set evaluation interval
4. Add notification channel (email, Slack, PagerDuty)

---

## 10. Troubleshooting

### 10.1 Metrics Tidak Muncul
**Check OpenTelemetry Collector logs:**
```bash
sudo docker logs otel-collector --tail 50
```

**Check cAdvisor:**
```bash
curl http://localhost:8081/metrics
```

**Check SigNoz OTel Collector:**
```bash
sudo docker logs signoz-otel-collector --tail 50
```

### 10.2 Container Tidak Running
```bash
# Check all containers
sudo docker ps -a | grep -E 'otel|cadvisor|signoz'

# Restart specific container
sudo docker restart otel-collector
sudo docker restart cadvisor
```

### 10.3 DNS Resolution Error
Jika ada error `dns: A record lookup error`, cek network:
```bash
# Ensure containers are on same network
sudo docker network inspect signoz-net
```

---

## 11. Security Considerations

### 11.1 Firewall Ports
Port yang perlu di-buka di GCP Firewall:
- **3301/tcp** - SigNoz Web UI (dapat dibatasi ke IP tertentu)
- **4317/tcp** - OTLP gRPC (internal only)
- **4318/tcp** - OTLP HTTP (internal only)

### 11.2 Access Control
- SigNoz menggunakan login email/password
- Pastikan credentials disimpan dengan aman
- Rotate password secara berkala

---

## 12. Resource Usage

### 12.1 Container Resource Usage
```bash
# Check container stats
sudo docker stats --no-stream
```

### 12.2 Estimated Resource Consumption
| Komponen | CPU | Memory | Disk |
|----------|-----|--------|------|
| SigNoz Stack | ~500m | ~1GB | ~10GB |
| OpenTelemetry Collector | ~100m | ~256MB | - |
| cAdvisor | ~100m | ~128MB | - |
| **Total** | ~700m | ~1.4GB | ~10GB |

---

## 13. Next Steps & Recommendations

### 13.1 Yang Sudah Selesai
- ✅ SigNoz deployed dan running
- ✅ OpenTelemetry Collector untuk host metrics
- ✅ cAdvisor untuk container metrics
- ✅ Metrics mengalir ke ClickHouse
- ✅ Dashboard configuration files dibuat

### 13.2 Yang Perlu Dilakukan Selanjutnya
1. **Buat Dashboard Manual di SigNoz UI** - Import query yang sudah disiapkan
2. **Setup Alert Channels** - Konfigurasi notifikasi (email/Slack)
3. **Setup Application Metrics** - Tambah OpenTelemetry SDK di aplikasi bot
4. **Setup Traces** - Enable distributed tracing untuk request tracking
5. **Setup Logs** - Configure log collection dari containers

### 13.3 Optional Enhancements
- Setup Grafana untuk visualization alternatif
- Add custom business metrics dari bots
- Configure retention policy di ClickHouse
- Setup backup untuk ClickHouse data

---

## 14. Referensi

### 14.1 Dokumentasi
- SigNoz: https://signoz.io/docs/
- OpenTelemetry Collector: https://opentelemetry.io/docs/collector/
- cAdvisor: https://github.com/google/cadvisor

### 14.2 File Paths di Repository
- Repository: git@github.com:addhe/NexusDevops.git
- Branch: main
- Path: `/monitoring/`

---

## 15. Kesimpulan

POC SigNoz infrastructure monitoring berhasil di-deploy dan beroperasi dengan baik. Semua komponen berjalan dan metrics sudah mengalir ke ClickHouse. Dashboard dan alert configuration files sudah disiapkan di repository.

**Status Akhir:** ✅ **POC BERHASIL - SIAP DIGUNAKAN**

---

*Laporan dibuat oleh NexusChiefCommander*
*Tanggal: 2026-05-17*
*VM: ocl-worker-devops-002-stg (34.101.152.17)*