# NexusDevops - Infrastructure as Code

> Ansible playbooks and configurations for deploying OpenClaw-based AI agents on GCP.

## 🏗️ Architecture

| Agent | VM | Project | Zone | Env | Role |
|-------|-----|---------|------|-----|------|
| IrishEcho MasterControl | `mastercontrol-001-prd` | `awanmasterpiece` | `asia-southeast2-b` | prd | Control Plane |
| RandomBot (RandomOps) | `randomops-bot-001-stg` | `awanmasterpiece` | `asia-southeast2-a` | stg | DevOps Worker |
| NexusChiefCommander | `nexus-chief-001-stg` | `ai-core-system-bot-stg` | `asia-southeast2-a` | stg | Control Plane |
| NexusChiefCommander | `nexus-chief-001-prd` | `ai-core-system-bot-prd` | `asia-southeast2-b` | prd | Control Plane |

## 📁 Directory Structure

```
ansible/
├── inventory/
│   ├── mastercontrol/          # IrishEcho MasterControl
│   ├── randomops/              # RandomBot Worker
│   ├── stg/
│   │   └── nexus-chief/        # NexusChiefCommander (Staging)
│   │       ├── hosts.yml
│   │       ├── gcp_compute.yml
│   │       └── group_vars/all/
│   │           ├── main.yml
│   │           ├── openclaw.yml
│   │           ├── owner.yml
│   │           ├── gcp.yml
│   │           └── vault.yml
│   ├── prd/
│   │   └── nexus-chief/        # NexusChiefCommander (Production)
│   │       ├── hosts.yml
│   │       ├── gcp_compute.yml
│   │       └── group_vars/all/
│   │           ├── main.yml
│   │           ├── openclaw.yml
│   │           ├── owner.yml
│   │           ├── gcp.yml
│   │           └── vault.yml
│   ├── production/             # Legacy production
│   └── staging/                # Legacy staging
├── playbooks/
│   ├── provision/              # VM provisioning
│   ├── deploy/                 # Service deployment
│   ├── mastercontrol/          # MasterControl specific
│   ├── randomops/              # RandomOps specific
│   └── nexus-chief/            # NexusChiefCommander specific
│       ├── provision.yml
│       └── deploy.yml
├── roles/
│   ├── base/                   # Base OS configuration
│   ├── gcp-compute/            # GCP VM provisioning
│   ├── openclaw-prereq/        # Node.js & dependencies
│   ├── openclaw-install/       # OpenClaw installation
│   ├── openclaw-config/        # OpenClaw configuration
│   └── ollama/                 # Ollama setup
└── docs/                       # Documentation
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

#### Staging (STG)

```bash
# 1. Provision VM
ansible-playbook playbooks/nexus-chief/provision.yml -e "deploy_env=staging"

# 2. Deploy OpenClaw + Persona
ansible-playbook playbooks/nexus-chief/deploy.yml \
  -i inventory/stg/nexus-chief/ \
  -e "deploy_env=staging" \
  -e "vault_telegram_bot_token=$(gcloud secrets versions access latest --secret=ncc-stg-telegram-bot-token --project=ai-core-system-bot-stg)" \
  -e "vault_gateway_token=$(gcloud secrets versions access latest --secret=ncc-stg-gateway-token --project=ai-core-system-bot-stg)" \
  -e "vault_ollama_api_key=$(gcloud secrets versions access latest --secret=ncc-stg-ollama-api-key --project=ai-core-system-bot-stg)"
```

#### Production (PRD)

```bash
# 1. Provision VM
ansible-playbook playbooks/nexus-chief/provision.yml -e "deploy_env=production"

# 2. Deploy OpenClaw + Persona
ansible-playbook playbooks/nexus-chief/deploy.yml \
  -i inventory/prd/nexus-chief/ \
  -e "deploy_env=production" \
  -e "vault_telegram_bot_token=$(gcloud secrets versions access latest --secret=ncc-prd-telegram-bot-token --project=ai-core-system-bot-prd)" \
  -e "vault_gateway_token=$(gcloud secrets versions access latest --secret=ncc-prd-gateway-token --project=ai-core-system-bot-prd)" \
  -e "vault_ollama_api_key=$(gcloud secrets versions access latest --secret=ncc-prd-ollama-api-key --project=ai-core-system-bot-prd)"
```

#### Using Ansible Vault (Alternative)

```bash
# Encrypt vault file
ansible-vault encrypt inventory/stg/nexus-chief/group_vars/all/vault.yml

# Deploy with vault password
ansible-playbook playbooks/nexus-chief/deploy.yml \
  -i inventory/stg/nexus-chief/ \
  -e "deploy_env=staging" \
  --ask-vault-pass
```

## 🔐 Secret Management

### Google Secret Manager (Recommended for Production)

Secrets are stored in GCP Secret Manager per project and environment.

#### Staging (`ai-core-system-bot-stg`)

```bash
gcloud config set project ai-core-system-bot-stg

echo -n "YOUR_TELEGRAM_BOT_TOKEN" | gcloud secrets create ncc-stg-telegram-bot-token --data-file=-
echo -n "$(openssl rand -hex 32)" | gcloud secrets create ncc-stg-gateway-token --data-file=-
echo -n "YOUR_OLLAMA_API_KEY" | gcloud secrets create ncc-stg-ollama-api-key --data-file=-
echo -n "YOUR_STRONG_PASSWORD" | gcloud secrets create ncc-stg-sensitive-password --data-file=-

# Grant access
for secret in ncc-stg-telegram-bot-token ncc-stg-gateway-token ncc-stg-ollama-api-key ncc-stg-sensitive-password; do
  gcloud secrets add-iam-policy-binding $secret \
    --member="serviceAccount:ai-core-system-bot@ai-core-system-bot-stg.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
done
```

#### Production (`ai-core-system-bot-prd`)

```bash
gcloud config set project ai-core-system-bot-prd

echo -n "YOUR_TELEGRAM_BOT_TOKEN" | gcloud secrets create ncc-prd-telegram-bot-token --data-file=-
echo -n "$(openssl rand -hex 32)" | gcloud secrets create ncc-prd-gateway-token --data-file=-
echo -n "YOUR_OLLAMA_API_KEY" | gcloud secrets create ncc-prd-ollama-api-key --data-file=-
echo -n "YOUR_STRONG_PASSWORD" | gcloud secrets create ncc-prd-sensitive-password --data-file=-

# Grant access
for secret in ncc-prd-telegram-bot-token ncc-prd-gateway-token ncc-prd-ollama-api-key ncc-prd-sensitive-password; do
  gcloud secrets add-iam-policy-binding $secret \
    --member="serviceAccount:ai-core-system-bot@ai-core-system-bot-prd.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
done
```

### Ansible Vault (Alternative for Local Development)

```bash
# Encrypt vault file
ansible-vault encrypt inventory/stg/nexus-chief/group_vars/all/vault.yml

# Edit encrypted vault
ansible-vault edit inventory/stg/nexus-chief/group_vars/all/vault.yml

# Run with vault password
ansible-playbook playbooks/nexus-chief/deploy.yml --ask-vault-pass
```

## 📋 Environment Differences

| Setting | Staging (STG) | Production (PRD) |
|---------|---------------|-------------------|
| VM Name | `nexus-chief-001-stg` | `nexus-chief-001-prd` |
| GCP Project | `ai-core-system-bot-stg` | `ai-core-system-bot-prd` |
| Zone | `asia-southeast2-a` | `asia-southeast2-b` |
| Subnet | `custom-vpc-dev-subnet` | `custom-vpc-prod-subnet` |
| Model | `ollama/glm-5` | `ollama/glm-5.1` |
| Log Level | `debug` | `info` |
| Secret Prefix | `ncc-stg-*` | `ncc-prd-*` |

## 🔑 SSH Deploy Keys

| Server | Deploy Key | Repository |
|--------|-----------|------------|
| mastercontrol-001-prd | `mastercontrol-gcp` | `addhe/openclaw-config-backup` |
| nexus-chief-001-prd | `nexus-devops-deploy` | `addhe/NexusDevops` |

## 🛡️ Security

- All bots: **DM ONLY, OWNER ONLY** (Om Awan, Telegram ID: 319535690)
- No group chat access by default
- Secrets via Google Secret Manager (recommended) or Ansible Vault
- SSH key-based authentication only
- Fail2ban enabled on all VMs

## 📝 License

MIT License - Copyright (c) 2026 AddheWarmanPutra