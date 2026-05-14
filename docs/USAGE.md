# Ansible Usage Guide

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Provisioning](#provisioning)
4. [Deployment](#deployment)
5. [Fast Provisioning from Snapshots](#fast-provisioning-from-snapshots)
6. [Operations](#operations)
7. [Troubleshooting](#troubleshooting)

---

## Deployment Statistics (2026-03-07)

### Timing Benchmarks

| Phase | Duration | Description |
|-------|----------|-------------|
| Phase 1: Provision VMs | ~2 min | GCP spot instances creation |
| Phase 2: Bootstrap | ~2 min | Base packages, SSH, UFW, fail2ban |
| Phase 3: Deploy OpenClaw | ~7 min | Node.js, Ollama, OpenClaw, persona |
| Phase 4: Create Snapshots | ~4 min | Preserve state for fast provisioning |
| **TOTAL (Full Deploy)** | **~15 min** | From scratch to running |
| **From Snapshot** | **~2 min** | Create VM + config only |

---

## Prerequisites

### Install Ansible Collections

```bash
cd ansible/
ansible-galaxy collection install google.cloud
ansible-galaxy collection install ansible.builtin
ansible-galaxy collection install community.general
```

### Install Python Dependencies

```bash
pip install google-auth google-auth-httplib2 google-api-python-client requests
```

### Install GCP CLI

```bash
# Ubuntu/Debian
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
sudo apt update && sudo apt install google-cloud-sdk

# Authenticate
gcloud auth login
gcloud auth application-default login
```

---

## Initial Setup

### 1. Clone Repository

```bash
git clone git@github.com:addhe/openclaw-config-backup.git
cd openclaw-config-backup/ansible
```

### 2. Create Vault Password Files

```bash
# Staging
echo "your-staging-password" > .vault_password_staging
chmod 600 .vault_password_staging

# Production
echo "your-production-password" > .vault_password_production
chmod 600 .vault_password_production
```

### 3. Create Vault Files

```bash
# Staging vault
ansible-vault create inventory/staging/group_vars/vault.yml
```

Fill with:
```yaml
---
# GCP Configuration
vault_gcp_project_id: "your-project-id"
vault_gcp_auth_kind: "application"

# Telegram Bot Tokens (per worker)
# Each worker needs a unique bot token
vault_telegram_bot_tokens:
  devops:
    "001": "DEVOPS_BOT_TOKEN_001"
    "002": "DEVOPS_BOT_TOKEN_002"
  backend:
    "001": "BACKEND_BOT_TOKEN_001"
    "002": "BACKEND_BOT_TOKEN_002"
  frontend:
    "001": "FRONTEND_BOT_TOKEN_001"
  # Add more roles as needed

# Telegram Allowed Users (whitelist)
vault_telegram_allowed_users:
  - 319535690  # @BroAwn numeric ID

# Ollama Cloud API Key
vault_ollama_cloud_api_key: "YOUR_OLLAMA_CLOUD_API_KEY"

# Gateway Token (optional)
vault_gateway_token: ""

# OpenAI API Key (optional)
vault_openai_api_key: ""
```

**Important:** Each worker role+ID combination needs its own Telegram bot token. Create bots via [@BotFather](https://t.me/botfather) and add tokens to `vault_telegram_bot_tokens` above.

### 4. Configure GCP Credentials

```bash
# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
export GCP_PROJECT_ID="your-project-id"
```

### 5. Verify Setup

```bash
# Test GCP connectivity
ansible localhost -m google.cloud.gcp_compute_instance_info -a "project=your-project-id zone=asia-southeast2-a"

# Test inventory
ansible-inventory -i inventory/staging/gcp_compute.yml --list
```

---

## Provisioning

### Provision Worker VM

VM naming convention: `ocl-worker-{role}-{numeric-id}-{env}`

**Available Roles:**
- `devops` - DevOps / Platform Engineer
- `backend` - Backend Engineer
- `frontend` - Frontend Engineer
- `test-engineer` - QA / Test Engineer
- `infosec` - Security Engineer
- `pm` - Product Manager
- `tpm` - Technical Program Manager
- `mobile-engineer` - Mobile Developer

```bash
# Provision DevOps worker (staging)
ansible-playbook playbooks/provision/openclaw-vm.yml \
  -e "deploy_env=staging gcp_worker_role=devops gcp_worker_id=001"

# Provision Backend worker (staging)
ansible-playbook playbooks/provision/openclaw-vm.yml \
  -e "deploy_env=staging gcp_worker_role=backend gcp_worker_id=001"

# Provision InfoSec worker (production)
ansible-playbook playbooks/provision/openclaw-vm.yml \
  -e "deploy_env=production gcp_worker_role=infosec gcp_worker_id=001"

# With custom machine type
ansible-playbook playbooks/provision/openclaw-vm.yml \
  -e "deploy_env=staging gcp_worker_role=devops gcp_worker_id=001" \
  -e "gcp_machine_type_spot=e2-standard-2" \
  -e "gcp_disk_size_gb=50"

# Dry run
ansible-playbook playbooks/provision/openclaw-vm.yml \
  -e "deploy_env=staging gcp_worker_role=devops gcp_worker_id=001" \
  --check
```

---

## Fast Provisioning from Snapshots

### Available Base Snapshots

| Snapshot | Role | Persona | Size | Version |
|----------|------|---------|------|---------|
| `openclaw-worker-devops-base-stg-v3` | DevOps | Senior DevOps Engineer | 20GB | v3 (2026-03-07) |
| `openclaw-worker-backend-base-stg-v3` | Backend | Senior Backend Engineer | 20GB | v3 (2026-03-07) |

**v3 Changes:** Includes `auth-profiles.json` for Ollama Cloud API authentication

### Fast Provision (~2 min vs ~15 min)

```bash
# Step 1: Create VM from snapshot (~1 min)
gcloud compute instances create ocl-worker-devops-002-stg \
  --project=awanmasterpiece \
  --zone=asia-southeast2-a \
  --machine-type=e2-medium \
  --source-snapshot=openclaw-worker-devops-base-stg-v2 \
  --tags=staging \
  --labels="environment=staging,managed_by=ansible,role=devops"

# Step 2: Add to inventory
# Update inventory/staging/hosts.yml with new IP

# Step 3: Deploy only config (~1 min)
ansible-playbook playbooks/deploy/openclaw.yml \
  -i inventory/staging/hosts.yml \
  -e "deploy_env=staging gcp_worker_role=devops gcp_worker_id=002" \
  --limit=ocl-worker-devops-002-stg \
  --tags=config
```

### What's Included in Snapshots

- Ubuntu 22.04 LTS
- Node.js v22.x
- OpenClaw installed
- Ollama installed with local model (llama3.2:1b)
- Base persona files (AGENTS.md, TOOLS.md, HEARTBEAT.md)
- Systemd service configured
- UFW firewall configured
- SSH hardened

### What's NOT Included (must redeploy)

- `IDENTITY.md` - Role-specific persona
- `SOUL.md` - Worker personality
- `USER.md` - Worker context
- `openclaw.json` - Config with unique bot token
- `.env` - Environment variables with Ollama API key

### Snapshot Naming Convention

```
openclaw-worker-{role}-base-{env}-v{version}

Examples:
- openclaw-worker-devops-base-stg-v2
- openclaw-worker-backend-base-stg-v2
- openclaw-worker-frontend-base-prd-v1
```

---

## Expected Output

```
PLAY [Provision OpenClaw Worker VM] *******************************************

TASK [Display environment] ****************************************************
ok: [localhost] => {
    "msg": "Provisioning for environment: staging, project: awanmasterpiece"
}

TASK [Validate worker role] ***************************************************
ok: [localhost] => {
    "msg": "Worker role validated: devops"
}

TASK [Validate worker ID] *****************************************************
ok: [localhost] => {
    "msg": "Worker ID validated: 001"
}

...

TASK [Display created instance] ***********************************************
ok: [localhost] => {
    "msg": [
        "Instance created: ocl-worker-devops-001-stg",
        "External IP: 34.128.xxx.xxx",
        "Internal IP: 10.20.0.2",
        "Status: RUNNING"
    ]
}

PLAY RECAP ********************************************************************
localhost                  : ok=28   changed=12   unreachable=0    failed=0
```

---

## Deployment

### Full Deployment (Recommended)

```bash
# Staging
ansible-playbook -i inventory/staging playbooks/site.yml

# Production
ansible-playbook -i inventory/production playbooks/site.yml
```

### Step-by-Step Deployment

```bash
# 1. Apply base role (security, packages, etc.)
ansible-playbook -i inventory/staging playbooks/deploy/base.yml

# 2. Deploy OpenClaw
ansible-playbook -i inventory/staging playbooks/deploy/openclaw.yml
```

### Deploy Specific Components

```bash
# Only OpenClaw prerequisites
ansible-playbook -i inventory/staging playbooks/deploy/openclaw.yml --tags prereq

# Only OpenClaw installation
ansible-playbook -i inventory/staging playbooks/deploy/openclaw.yml --tags install

# Only OpenClaw configuration
ansible-playbook -i inventory/staging playbooks/deploy/openclaw.yml --tags config
```

---

## Operations

### List All Instances

```bash
# Using dynamic inventory
ansible-inventory -i inventory/staging/gcp_compute.yml --list | jq '._meta.hostvars | keys'

# Using gcloud
gcloud compute instances list --filter="labels.environment=staging"
```

### Ping All Instances

```bash
# Staging
ansible -i inventory/staging/gcp_compute.yml all -m ping

# Production
ansible -i inventory/production/gcp_compute.yml all -m ping
```

### Gather Facts

```bash
ansible -i inventory/staging/gcp_compute.yml all -m setup
```

### Run Ad-hoc Commands

```bash
# Check uptime
ansible -i inventory/staging/gcp_compute.yml all -a "uptime"

# Check disk space
ansible -i inventory/staging/gcp_compute.yml all -a "df -h"

# Check memory
ansible -i inventory/staging/gcp_compute.yml all -a "free -m"
```

### Update Packages

```bash
ansible -i inventory/staging/gcp_compute.yml all -b -m apt -a "update_cache=yes upgrade=dist"
```

### Restart Service

```bash
ansible -i inventory/staging/gcp_compute.yml all -b -m systemd -a "name=openclaw state=restarted"
```

---

## Troubleshooting

### Debug Mode

```bash
# Verbose output
ansible-playbook playbooks/site.yml -vvv

# Debug task
ansible-playbook playbooks/site.yml --start-at-task="Task Name"
```

### Check Syntax

```bash
ansible-playbook playbooks/site.yml --syntax-check
```

### List Tasks

```bash
ansible-playbook playbooks/site.yml --list-tasks
```

### List Tags

```bash
ansible-playbook playbooks/site.yml --list-tags
```

### Common Errors

#### GCP Authentication Error

```
Error: google.auth.exceptions.DefaultCredentialsError
```

**Solution:**
```bash
gcloud auth application-default login
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/key.json"
```

#### Vault Decryption Error

```
Error: Attempting to decrypt but no vault secrets found
```

**Solution:**
```bash
# Check vault password file exists
ls -la .vault_password_staging

# Check vault file is encrypted
head -1 inventory/staging/group_vars/vault.yml
# Should show: $ANSIBLE_VAULT;1.1;AES256
```

#### Dynamic Inventory Not Working

```
Error: No hosts matched
```

**Solution:**
```bash
# Check GCP credentials
gcloud auth list

# Check project ID
gcloud config get-value project

# Debug inventory
ansible-inventory -i inventory/staging/gcp_compute.yml --list -vvv
```

#### Instance Not Running

```
Error: Wait for instance to be running
```

**Solution:**
```bash
# Check instance status
gcloud compute instances describe INSTANCE_NAME --zone=asia-southeast2-a

# Check instance logs
gcloud compute instances get-serial-port-output INSTANCE_NAME --zone=asia-southeast2-a
```

#### allowFrom Empty in Config

```
Error: Telegram pairing required even though allowFrom is set in vault
```

**Cause:** Variable `telegram_allowed_users` not rendering correctly in Jinja2 template.

**Solution:**
```bash
# Manually update config on worker
ssh -i ~/.ssh/shannon-gcp addheputra@WORKER_IP
sudo -u openclaw sed -i 's/"allowFrom": \[\]/"allowFrom": [319535690]/' /home/openclaw/.openclaw/openclaw.json
sudo systemctl restart openclaw
```

**Permanent Fix:** Update `roles/openclaw-config/templates/openclaw.json.j2`:
```jinja2
"allowFrom": {{ vault_telegram_allowed_users | to_json }},
```

#### Config File Corrupted (0 bytes)

```
Error: Config invalid or empty
```

**Cause:** Config file may be overwritten with empty content during deployment.

**Solution:**
```bash
# Restore from backup
ssh -i ~/.ssh/shannon-gcp addheputra@WORKER_IP
sudo -u openclaw cp /home/openclaw/.openclaw/openclaw.json.bak /home/openclaw/.openclaw/openclaw.json
sudo systemctl restart openclaw
```

#### Wrong Persona Deployed

```
Error: Worker shows wrong role in IDENTITY.md
```

**Cause:** Deployed with wrong `gcp_worker_role` parameter.

**Solution:**
```bash
# Redeploy with correct role
ansible-playbook playbooks/deploy/openclaw.yml \
  -i inventory/staging/hosts.yml \
  -e "deploy_env=staging gcp_worker_role=backend gcp_worker_id=001" \
  --limit=ocl-worker-backend-001-stg \
  --tags=config
```

---

## Quick Reference

### Commands Summary

| Task | Command |
|------|---------|
| Deploy Worker from Snapshot | See [WORKER_DEPLOYMENT.md](WORKER_DEPLOYMENT.md) |
| Provision Staging | `ansible-playbook -i inventory/staging playbooks/provision/openclaw-vm.yml` |
| Provision Production | `ansible-playbook -i inventory/production playbooks/provision/openclaw-vm.yml` |
| Full Deploy Staging | `ansible-playbook -i inventory/staging playbooks/site.yml` |
| Full Deploy Production | `ansible-playbook -i inventory/production playbooks/site.yml` |
| Apply Base Only | `ansible-playbook -i inventory/staging playbooks/deploy/base.yml` |
| Deploy OpenClaw Only | `ansible-playbook -i inventory/staging playbooks/deploy/openclaw.yml` |
| List Instances | `gcloud compute instances list --filter="name:ocl-worker"` |
| SSH to Worker | `gcloud compute ssh ocl-worker-devops-001-stg --zone=asia-southeast2-a` |
| Edit Vault Staging | `ansible-vault edit inventory/staging/group_vars/vault.yml` |
| Edit Vault Production | `ansible-vault edit inventory/production/group_vars/vault.yml` |

### Worker Management

| Task | Command |
|------|---------|
| List Workers | `gcloud compute instances list --filter="name:ocl-worker"` |
| Start Worker | `gcloud compute instances start ocl-worker-devops-001-stg --zone=asia-southeast2-a` |
| Stop Worker | `gcloud compute instances stop ocl-worker-devops-001-stg --zone=asia-southeast2-a` |
| Delete Worker | `gcloud compute instances delete ocl-worker-devops-001-stg --zone=asia-southeast2-a --quiet` |
| Check OpenClaw Status | `gcloud compute ssh WORKER_NAME --zone=asia-southeast2-a --command="sudo systemctl status openclaw"` |
| View Worker Logs | `gcloud compute ssh WORKER_NAME --zone=asia-southeast2-a --command="sudo journalctl -u openclaw -n 50"` |
| Update Bot Token | `gcloud compute ssh WORKER_NAME --command="sudo sed -i 's/OLD_TOKEN/NEW_TOKEN/g' /home/openclaw/.openclaw/openclaw.json && sudo systemctl restart openclaw"` |

---

## Support

- **Documentation:** `docs/` directory
- **Worker Deployment:** [WORKER_DEPLOYMENT.md](WORKER_DEPLOYMENT.md)
- **MasterControl Deployment:** [MASTERCONTROL_DEPLOYMENT.md](MASTERCONTROL_DEPLOYMENT.md)
- **Issues:** [GitHub Issues](https://github.com/addhe/openclaw-config-backup/issues)
- **Logs:** Check `/var/log/ansible/` on target hosts