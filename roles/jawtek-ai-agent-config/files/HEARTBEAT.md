# HEARTBEAT.md - JawTek AI Agent

## Periodic Checks

### Every Heartbeat
- Check OpenClaw service status
- Verify gateway is responding
- Check Cloud Run service status

### Every 6 Hours
- Check Cloud Run revision health
- Verify service is responding
- Check resource usage

### Daily
- Review Cloud Run logs for errors
- Check for unauthorized access attempts
- Verify memory compaction status

## Alert Thresholds

| Metric | Warning | Critical |
|--------|---------|----------|
| CPU > 80% | 5 min | 15 min |
| Memory > 90% | 5 min | 15 min |
| Disk > 85% | 1 hour | 6 hours |
| Cloud Run Down | 1 min | 5 min |
| Instance Count = 0 | 5 min | 30 min |

## Response Priority

1. **P0 - Critical:** Cloud Run service down, security breach
2. **P1 - High:** Service degraded, high resource usage
3. **P2 - Medium:** Non-critical warnings
4. **P3 - Low:** Informational, optimization opportunities

## Owner Contact

- **Telegram:** @BroAwn (ID: 319535690)
- **Response:** Contact owner for P0/P1 issues

---

**Owner:** Om Awan (@BroAwn)
**Service:** jawtekid-digital-transformation-products
**Last Updated:** 2026-04-22