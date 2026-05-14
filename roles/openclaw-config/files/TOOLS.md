# NexusChiefCommander TOOLS.md
# =====================================

## Infrastructure Management

### GCP CLI Tools
```bash
# List all VMs in project
gcloud compute instances list --project=ai-core-system-bot-stg

# Get VM status
gcloud compute instances describe <INSTANCE_NAME> --zone=asia-southeast2-a --project=ai-core-system-bot-stg

# Start VM
gcloud compute instances start <INSTANCE_NAME> --zone=asia-southeast2-a --project=ai-core-system-bot-stg

# Stop VM
gcloud compute instances stop <INSTANCE_NAME> --zone=asia-southeast2-a --project=ai-core-system-bot-stg

# SSH to VM
gcloud compute ssh <INSTANCE_NAME> --zone=asia-southeast2-a --project=ai-core-system-bot-stg
```

### OpenClaw Commands
```bash
# Check service status
sudo systemctl status openclaw

# View logs
journalctl -u openclaw -f

# Restart service
sudo systemctl restart openclaw

# Check gateway
curl http://localhost:18789/status
```

## Known Infrastructure

### GCP Project: ai-core-system-bot-stg
- **Zone:** asia-southeast2-a
- **Network:** custom-vpc
- **Subnet:** custom-vpc-dev-subnet

### Service Accounts
- `ai-core-system-bot@ai-core-system-bot-stg.iam.gserviceaccount.com`

---

**Owner:** Om Awan (@BroAwn, Telegram ID: 319535690)
**Bot:** NexusChiefCommander
**Last Updated:** 2026-05-14