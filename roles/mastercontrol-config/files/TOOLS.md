# TOOLS.md - MasterControl Tools

## Infrastructure Management

### GCP CLI Tools
```bash
# List all VMs
gcloud compute instances list --project=awanmasterpiece

# Get VM status
gcloud compute instances describe <INSTANCE_NAME> --zone=<ZONE>

# Start VM
gcloud compute instances start <INSTANCE_NAME> --zone=<ZONE>

# Stop VM
gcloud compute instances stop <INSTANCE_NAME> --zone=<ZONE>

# SSH to VM
gcloud compute ssh <INSTANCE_NAME> --zone=<ZONE>
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
curl http://localhost:8080/status
```

### Ansible Commands
```bash
# Deploy MasterControl
cd /home/addheputra/openclaw-config-backup/ansible
ansible-playbook playbooks/mastercontrol/deploy.yml -i inventory/mastercontrol/hosts.yml --ask-vault-pass

# Deploy worker
ansible-playbook playbooks/deploy/openclaw.yml -i inventory/staging/hosts.yml --ask-vault-pass

# Provision VM
ansible-playbook playbooks/provision/openclaw-vm.yml -e "environment=staging"
```

## Known Infrastructure

### GCP Project: awanmasterpiece
- **Zone:** us-central1-b (primary), asia-southeast2-a (workers)
- **Network:** openclaw-staging-network
- **Subnet:** openclaw-staging-subnet

### Worker Fleet
| VM | Role | Zone | Status |
|----|------|------|--------|
| `ocl-worker-devops-001-stg` | DevOps | asia-southeast2-a | RUNNING |
| `ocl-worker-backend-001-stg` | Backend | asia-southeast2-a | RUNNING |
| `mastercontrol-001-stg` | Control | us-central1-b | TBD |

### Service Accounts
- `awan-master-service-account@awanmasterpiece.iam.gserviceaccount.com`

## Bot Tokens

| Bot | Token Location | Status |
|-----|---------------|--------|
| RandomOpsBot | `inventory/staging/group_vars/vault.yml` | Active |
| IrishEcho MasterControl | `inventory/mastercontrol/group_vars/vault.yml` | Pending |

## Quick Commands

### Check All Workers
```bash
for vm in $(gcloud compute instances list --project=awanmasterpiece --format='value(name)' --filter='name:ocl-worker'); do
  echo "=== $vm ==="
  gcloud compute ssh $vm --zone=asia-southeast2-a --command="sudo systemctl status openclaw --no-pager"
done
```

### Restart All Workers
```bash
for vm in $(gcloud compute instances list --project=awanmasterpiece --format='value(name)' --filter='name:ocl-worker'); do
  echo "Restarting $vm..."
  gcloud compute ssh $vm --zone=asia-southeast2-a --command="sudo systemctl restart openclaw"
done
```

### View Aggregated Logs
```bash
for vm in $(gcloud compute instances list --project=awanmasterpiece --format='value(name)' --filter='name:ocl-worker'); do
  echo "=== $vm ==="
  gcloud compute ssh $vm --zone=asia-southeast2-a --command="sudo journalctl -u openclaw -n 20 --no-pager"
done
```

---

**Owner:** Om Awan (@BroAwn, ID: 319535690)
**Bot:** IrishEcho MasterControl
**Last Updated:** 2026-03-16