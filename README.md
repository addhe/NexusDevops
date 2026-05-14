# NexusDevops - Infrastructure as Code

> Ansible playbooks and configurations for deploying OpenClaw-based AI agents on GCP.

## 🏗️ Architecture

| Agent | VM | Project | Zone | Role |
|-------|-----|---------|------|------|
| IrishEcho MasterControl | `mastercontrol-001-prd` | `awanmasterpiece` | `asia-southeast2-b` | Control Plane |
| RandomBot (RandomOps) | `randomops-bot-001-stg` | `awanmasterpiece` | `asia-southeast2-a` | DevOps Worker |
| NexusChiefCommander | `nexus-chief-001-prd` | `ai-core-system-bot-stg` | `asia-southeast2-a` | Control Plane |

## 📁 Directory Structure

```
ansible/
├── inventory/
│   ├── mastercontrol/     # IrishEcho MasterControl
│   ├── randomops/         # RandomBot Worker
│   ├── nexus-chief/       # NexusChiefCommander (NEW)
│   ├── production/         # Production environment
│   └── staging/            # Staging environment
├── playbooks/
│   ├── provision/          # VM provisioning
│   ├── deploy/             # Service deployment
│   ├── mastercontrol/      # MasterControl specific
│   ├── randomops/          # RandomOps specific
│   └── nexus-chief/        # NexusChiefCommander specific
├── roles/
│   ├── base/               # Base OS configuration
│   ├── gcp-compute/        # GCP VM provisioning
│   ├── openclaw-prereq/    # Node.js & dependencies
│   ├── openclaw-install/  # OpenClaw installation
│   ├── openclaw-config/    # OpenClaw configuration
│   └── ollama/             # Ollama setup
└── docs/                   # Documentation
```

## 🚀 Quick Start

### Prerequisites

```bash
# Install Ansible
pip install ansible

# Install GCP Ansible collections
ansible-galaxy collection install google.cloud

# Install dependencies
ansible-galaxy install -r requirements.yml
```

### NexusChiefCommander Deployment

#### 1. Provision VM

```bash
ansible-playbook playbooks/nexus-chief/provision.yml
```

#### 2. Deploy OpenClaw + Persona

```bash
# Using Google Secret Manager (recommended)
ansible-playbook playbooks/nexus-chief/deploy.yml \
  -i inventory/nexus-chief/ \
  -e "vault_telegram_bot_token=$(gcloud secrets versions access latest --secret=ncc-telegram-bot-token --project=ai-core-system-bot-stg)" \
  -e "vault_gateway_token=$(gcloud secrets versions access latest --secret=ncc-gateway-token --project=ai-core-system-bot-stg)" \
  -e "vault_ollama_api_key=$(gcloud secrets versions access latest --secret=ncc-ollama-api-key --project=ai-core-system-bot-stg)"

# Using Ansible Vault (alternative)
ansible-vault encrypt inventory/nexus-chief/group_vars/all/vault.yml
ansible-playbook playbooks/nexus-chief/deploy.yml \
  -i inventory/nexus-chief/ \
  --ask-vault-pass
```

#### 3. Verify

```bash
# SSH to VM and check status
gcloud compute ssh nexus-chief-001-prd --zone=asia-southeast2-a --project=ai-core-system-bot-stg
sudo systemctl status openclaw
```

### RandomOps Deployment

```bash
ansible-playbook playbooks/randomops/deploy.yml -i inventory/randomops/
```

### MasterControl Deployment

```bash
ansible-playbook playbooks/mastercontrol/deploy.yml -i inventory/mastercontrol/
```

## 🔐 Secret Management

### Google Secret Manager (Recommended for Production)

Secrets are stored in GCP Secret Manager per project. Create secrets before deploying:

```bash
# Set project
gcloud config set project ai-core-system-bot-stg

# Create secrets
echo -n "YOUR_TELEGRAM_BOT_TOKEN" | gcloud secrets create ncc-telegram-bot-token --data-file=-
echo -n "$(openssl rand -hex 32)" | gcloud secrets create ncc-gateway-token --data-file=-
echo -n "YOUR_OLLAMA_API_KEY" | gcloud secrets create ncc-ollama-api-key --data-file=-
echo -n "YOUR_STRONG_PASSWORD" | gcloud secrets create ncc-sensitive-password --data-file=-
echo -n "YOUR_GCP_SERVICE_ACCOUNT_EMAIL" | gcloud secrets create ncc-gcp-service-account-email --data-file=-
echo -n "YOUR_GCP_SERVICE_ACCOUNT_KEY_PATH" | gcloud secrets create ncc-gcp-service-account-key --data-file=-

# Grant access to compute service account
gcloud secrets add-iam-policy-binding ncc-telegram-bot-token \
  --member="serviceAccount:ai-core-system-bot@ai-core-system-bot-stg.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### Ansible Vault (Alternative for Local Development)

```bash
# Encrypt vault file
ansible-vault encrypt inventory/nexus-chief/group_vars/all/vault.yml

# Edit encrypted vault
ansible-vault edit inventory/nexus-chief/group_vars/all/vault.yml

# Run with vault password
ansible-playbook playbooks/nexus-chief/deploy.yml --ask-vault-pass
```

## 🔑 SSH Deploy Keys

Each server uses a dedicated SSH deploy key for repository access:

| Server | Deploy Key | Repository |
|--------|-----------|------------|
| mastercontrol-001-prd | `mastercontrol-gcp` | `addhe/openclaw-config-backup` |
| nexus-chief-001-prd | `nexus-devops-deploy` | `addhe/NexusDevops` |

## 📋 VM Specifications

### NexusChiefCommander

| Parameter | Value |
|-----------|-------|
| VM Name | `nexus-chief-001-prd` |
| Project | `ai-core-system-bot-stg` |
| Zone | `asia-southeast2-a` |
| Machine Type | `e2-standard-2` (2 vCPU, 8GB) |
| Disk | 30GB SSD |
| Network | `custom-vpc` / `custom-vpc-dev-subnet` |
| Provisioning | SPOT |
| Image | Ubuntu 22.04 LTS |

## 🛡️ Security

- All bots: **DM ONLY, OWNER ONLY** (Om Awan, Telegram ID: 319535690)
- No group chat access by default
- Secrets via Google Secret Manager or Ansible Vault
- SSH key-based authentication only
- Fail2ban enabled on all VMs

## 📝 License

MIT License - Copyright (c) 2026 AddheWarmanPutra