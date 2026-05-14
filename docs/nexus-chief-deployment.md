# NexusChiefCommander Deployment Guide

## Overview

NexusChiefCommander is an infrastructure control plane agent running on OpenClaw. It manages GCP resources in the `ai-core-system-bot-stg` project.

## Prerequisites

1. **GCP CLI** - `gcloud` configured with access to `ai-core-system-bot-stg`
2. **Ansible** - v2.14+
3. **GCP Ansible Collection** - `ansible-galaxy collection install google.cloud`
4. **SSH Access** - Deploy key `nexus-devops-deploy` with write access to `addhe/NexusDevops`

## Step-by-Step Deployment

### Step 1: Create Telegram Bot

1. Message [@BotFather](https://t.me/BotFather) on Telegram
2. Create a new bot: `/newbot`
3. Name: `NexusChiefCommander`
4. Username: choose a username (e.g., `NexusChiefCommander_bot`)
5. Copy the bot token

### Step 2: Create Google Secrets

```bash
gcloud config set project ai-core-system-bot-stg

# Telegram bot token
echo -n "YOUR_BOT_TOKEN" | gcloud secrets create ncc-telegram-bot-token --data-file=-

# Gateway auth token (generate random)
echo -n "$(openssl rand -hex 32)" | gcloud secrets create ncc-gateway-token --data-file=-

# Ollama API key
echo -n "YOUR_OLLAMA_KEY" | gcloud secrets create ncc-ollama-api-key --data-file=-

# Sensitive password
echo -n "$(openssl rand -hex 16)" | gcloud secrets create ncc-sensitive-password --data-file=-

# GCP service account
echo -n "ai-core-system-bot@ai-core-system-bot-stg.iam.gserviceaccount.com" | \
  gcloud secrets create ncc-gcp-service-account-email --data-file=-

# Grant compute service account access
for secret in ncc-telegram-bot-token ncc-gateway-token ncc-ollama-api-key ncc-sensitive-password ncc-gcp-service-account-email; do
  gcloud secrets add-iam-policy-binding $secret \
    --member="serviceAccount:ai-core-system-bot@ai-core-system-bot-stg.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
done
```

### Step 3: Provision VM

```bash
ansible-playbook playbooks/nexus-chief/provision.yml
```

This creates:
- VM: `nexus-chief-001-prd`
- Type: `e2-standard-2` (spot)
- Zone: `asia-southeast2-a`
- Network: `custom-vpc`
- Disk: 30GB SSD

### Step 4: Deploy OpenClaw

```bash
# Fetch secrets from Google Secret Manager
export VAULT_TELEGRAM_BOT_TOKEN=$(gcloud secrets versions access latest --secret=ncc-telegram-bot-token --project=ai-core-system-bot-stg)
export VAULT_GATEWAY_TOKEN=$(gcloud secrets versions access latest --secret=ncc-gateway-token --project=ai-core-system-bot-stg)
export VAULT_OLLAMA_API_KEY=$(gcloud secrets versions access latest --secret=ncc-ollama-api-key --project=ai-core-system-bot-stg)
export VAULT_SENSITIVE_PASSWORD=$(gcloud secrets versions access latest --secret=ncc-sensitive-password --project=ai-core-system-bot-stg)
export VAULT_GCP_SERVICE_ACCOUNT_EMAIL=$(gcloud secrets versions access latest --secret=ncc-gcp-service-account-email --project=ai-core-system-bot-stg)

# Run deployment
ansible-playbook playbooks/nexus-chief/deploy.yml \
  -i inventory/nexus-chief/ \
  -e "vault_telegram_bot_token=$VAULT_TELEGRAM_BOT_TOKEN" \
  -e "vault_gateway_token=$VAULT_GATEWAY_TOKEN" \
  -e "vault_ollama_api_key=$VAULT_OLLAMA_API_KEY" \
  -e "vault_sensitive_password=$VAULT_SENSITIVE_PASSWORD" \
  -e "vault_gcp_service_account_email=$VAULT_GCP_SERVICE_ACCOUNT_EMAIL"
```

### Step 5: Verify

```bash
# SSH to VM
gcloud compute ssh nexus-chief-001-prd --zone=asia-southeast2-a --project=ai-core-system-bot-stg

# Check status
sudo systemctl status openclaw
curl http://localhost:18789/status
```

### Step 6: Configure Telegram

```bash
# On the VM, set bot commands and privacy settings
openclaw channels login --channel telegram
```

## Troubleshooting

### VM not accessible
```bash
gcloud compute instances list --project=ai-core-system-bot-stg
gcloud compute ssh nexus-chief-001-prd --zone=asia-southeast2-a --project=ai-core-system-bot-stg
```

### OpenClaw not starting
```bash
sudo journalctl -u openclaw --since '5 min ago' --no-pager
```

### WhatsApp connection issues
```bash
sudo -u openclaw openclaw channels login --channel whatsapp
```

## Architecture

```
Internet → Telegram API → OpenClaw Gateway (18789) → Ollama Cloud (glm-5.1)
                    ↓
              WhatsApp Bridge
                    ↓
            GCP Compute (e2-standard-2 spot)
                    ↓
         ai-core-system-bot-stg project
```