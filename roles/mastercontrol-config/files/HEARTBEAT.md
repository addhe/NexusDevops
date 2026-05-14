# HEARTBEAT.md - MasterControl

## Periodic Checks

### Every Heartbeat
- Check OpenClaw service status
- Verify gateway is responding
- Check for pending infrastructure alerts

### Every 6 Hours
- Check all worker VMs status
- Verify bot services are running
- Check GCP quota usage

### Daily
- Review security logs
- Check for unauthorized access attempts
- Verify backup integrity

## Alert Thresholds

| Metric | Warning | Critical |
|--------|---------|----------|
| CPU > 80% | 5 min | 15 min |
| Memory > 90% | 5 min | 15 min |
| Disk > 85% | 1 hour | 6 hours |
| Worker Down | 2 min | 10 min |

## Response Priority

1. **P0 - Critical:** Worker down, security breach
2. **P1 - High:** Service degraded, high resource usage
3. **P2 - Medium:** Non-critical warnings
4. **P3 - Low:** Informational, optimization opportunities

---

**Owner:** Om Awan (@BroAwn)
**Last Updated:** 2026-03-16